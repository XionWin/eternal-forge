CREATE EXTENSION IF NOT EXISTS pgcrypto;

DROP TYPE IF EXISTS login_status CASCADE;
CREATE TYPE login_status AS ENUM (
    'SUCCESS',
    'PENDING',
    'NOT_FOUND'
);

DROP TABLE IF EXISTS pending_reset_passwords CASCADE;
DROP TABLE IF EXISTS pending_users CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS genders CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TABLE IF EXISTS user_statuses CASCADE;
DROP TABLE IF EXISTS locales CASCADE;

CREATE TABLE genders (
    id INTEGER PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT
);
INSERT INTO genders (id, name, description) VALUES
(0, 'Unknown', 'Gender not specified or unknown'),
(1, 'Male', 'Male gender'),
(2, 'Female', 'Female gender'),
(3, 'Other', 'Other or non-binary gender');

CREATE TABLE roles (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);
INSERT INTO roles (id, name, description) VALUES
(1, 'Admin', 'Administrator with full permissions'),
(2, 'User', 'Regular user with limited permissions'),
(3, 'Guest', 'Guest user with minimal permissions');

CREATE TABLE user_statuses (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);
INSERT INTO user_statuses (id, name, description) VALUES
(0, 'Inactive', 'User account is inactive'),
(1, 'Active', 'User account is active'),
(2, 'Suspended', 'User account is suspended'),
(3, 'Deleted', 'User account is deleted');

CREATE TABLE locales (
    id INTEGER PRIMARY KEY,
    language_code VARCHAR(10) NOT NULL,
    locale_code VARCHAR(10) NOT NULL UNIQUE,
    name_en VARCHAR(100) NOT NULL,
    native_name VARCHAR(100) NOT NULL,
    is_rtl BOOLEAN NOT NULL DEFAULT FALSE,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT NOW()
);
INSERT INTO locales (
    id, language_code, locale_code, name_en, native_name, is_rtl, enabled, created_at
) VALUES (
    1,
    'en',
    'en-US',
    'English (United States)',
    'English',
    FALSE,
    TRUE,
    NOW()
),
(
    2,
    'zh',
    'zh-CN',
    'Chinese (Simplified)',
    '简体中文',
    FALSE,
    TRUE,
    NOW()
);

CREATE TABLE pending_users (
	account VARCHAR(255) PRIMARY KEY,
	password VARCHAR(255) NOT NULL,
	verification_code VARCHAR(6) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
	last_login_at TIMESTAMPTZ DEFAULT NULL,
    firstname VARCHAR(255) NOT NULL,
    lastname VARCHAR(255) NOT NULL,
    gender INTEGER NOT NULL,
    locale INTEGER NOT NULL,
    avatar VARCHAR(255),
    signature VARCHAR(255),
	CONSTRAINT fk_gender FOREIGN KEY (gender) REFERENCES genders(id),
	CONSTRAINT fk_locale FOREIGN KEY (locale) REFERENCES locales(id)
);

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account VARCHAR(255) NOT NULL UNIQUE,
	password VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
	last_login_at TIMESTAMPTZ DEFAULT NULL,
    status INTEGER NOT NULL,
    role INTEGER NOT NULL,
    CONSTRAINT fk_users_status FOREIGN KEY (status) REFERENCES user_statuses(id),
    CONSTRAINT fk_users_role FOREIGN KEY (role) REFERENCES roles(id)
);

CREATE TABLE user_profiles (
    id UUID PRIMARY KEY,
    firstname VARCHAR(255) NOT NULL,
    lastname VARCHAR(255) NOT NULL,
    gender INTEGER NOT NULL,
    locale INTEGER NOT NULL,
    avatar VARCHAR(255),
    signature VARCHAR(255),
	CONSTRAINT fk_user_profiles_id FOREIGN KEY (id) REFERENCES users(id) ON DELETE CASCADE,
	CONSTRAINT fk_user_profiles_gender FOREIGN KEY (gender) REFERENCES genders(id),
	CONSTRAINT fk_user_profiles_locale FOREIGN KEY (locale) REFERENCES locales(id)
);

CREATE TABLE pending_reset_passwords (
	account VARCHAR(255) PRIMARY KEY,
	verification_code VARCHAR(6) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
	CONSTRAINT fk_pending_reset_passwords_account FOREIGN KEY (account) REFERENCES users(account)
);

CREATE OR REPLACE FUNCTION util_raise_error(
    p_errcode TEXT,
    p_message TEXT
) RETURNS void AS $$
BEGIN
    RAISE EXCEPTION USING 
        MESSAGE = p_message,
        ERRCODE = p_errcode;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION util_generate_verification_code()
RETURNS VARCHAR
AS $$
DECLARE
	-- remove 'I', 'O', '1', '0' to minimize ambiguity and improve readability
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    i INT;
    result VARCHAR:= '';
BEGIN
    FOR i IN 1..6 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
	RETURN result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION util_verify_account (
    p_account VARCHAR
)
RETURNS BOOLEAN
AS $$
DECLARE
    is_available BOOLEAN;
BEGIN
	is_available :=  NOT (
		EXISTS (SELECT 1 FROM pending_users WHERE account = p_account)
       	OR EXISTS (SELECT 1 FROM users WHERE account = p_account)
   );
	RETURN is_available;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_register_user (
    p_account VARCHAR,
	p_password VARCHAR,
    p_firstname VARCHAR,
    p_lastname VARCHAR,
    p_gender INTEGER,
    p_locale INTEGER,
    p_avatar VARCHAR DEFAULT NULL,
    p_signature VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
AS $$
DECLARE
    v_code VARCHAR;
BEGIN
	IF NOT util_verify_account(p_account) THEN
	    PERFORM util_raise_error('P0003', format('Account %s is already in use.', p_account));
    END IF;

	v_code := util_generate_verification_code();

    INSERT INTO pending_users (
        account,
        password,
		verification_code,
        created_at,
        updated_at,
        firstname,
        lastname,
        gender,
        locale,
        avatar,
        signature
    ) VALUES (
        p_account,
        crypt(p_password, gen_salt('bf')),
		v_code,
        now(),
        now(),
        p_firstname,
        p_lastname,
        p_gender,
        p_locale,
        p_avatar,
        p_signature
    );
	RETURN v_code;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION func_verify_user (
    p_account VARCHAR,
	p_password VARCHAR,
    p_verification_code VARCHAR
)
RETURNS UUID
AS $$
DECLARE
    v_id UUID;
    v_pending_user pending_users%ROWTYPE;
BEGIN
	SELECT *
    INTO v_pending_user
    FROM pending_users
    WHERE account = p_account
		AND crypt(p_password, password) = password
    	AND verification_code = UPPER(p_verification_code);
	  
	IF NOT FOUND THEN
        RETURN NULL;
    END IF;

	INSERT INTO users (
        account, password,
        status, role,
        created_at, updated_at, last_login_at
    ) VALUES (
        v_pending_user.account,
        v_pending_user.password,
        1,
        2,
        v_pending_user.created_at, now(), now()
    )
    RETURNING id INTO v_id;
	
    INSERT INTO user_profiles (
        id, firstname, lastname,
        gender, locale,
        avatar, signature
    ) VALUES (
        v_id,
        v_pending_user.firstname,
        v_pending_user.lastname,
        v_pending_user.gender,
        v_pending_user.locale,
        v_pending_user.avatar,
        v_pending_user.signature
    );
	
    DELETE FROM pending_users
    WHERE account = v_pending_user.account;
	
    RETURN v_id::UUID;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_regenerate_verification_code (
    p_account VARCHAR
)
RETURNS VARCHAR
AS $$
DECLARE
    v_code VARCHAR;
BEGIN
	IF NOT EXISTS (
	    SELECT 1
	    FROM pending_users
	    WHERE account = p_account
	) THEN
		PERFORM util_raise_error('P0001', format('Account %s does not exist.', p_account));
	END IF;
	
	IF EXISTS (
        SELECT 1
        FROM pending_users
        WHERE account = p_account
        	AND now() - updated_at < interval '5 minutes'
    ) THEN
        PERFORM util_raise_error('P0002', format('Verification code was recently generated. Please wait before requesting again.'));
    END IF;
	
	v_code := util_generate_verification_code();
	UPDATE pending_users
	SET verification_code = v_code, updated_at = now()
	WHERE account = p_account;
	
	RETURN v_code;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_login_user (
    p_account VARCHAR,
	p_password VARCHAR
)
RETURNS TABLE (
	code login_status,
    id UUID
)
AS $$
DECLARE
    v_id UUID;
BEGIN
	RETURN QUERY
    SELECT 'SUCCESS'::login_status AS code, users.id::UUID
    FROM users
    WHERE account = p_account
      AND password = crypt(p_password, password)
    LIMIT 1;
    IF FOUND THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT 'PENDING'::login_status AS code, NULL::UUID
    FROM pending_users
    WHERE account = p_account
    LIMIT 1;
    IF FOUND THEN
        RETURN;
    END IF;
	
    RETURN QUERY
    SELECT 'NOT_FOUND'::login_status AS code, NULL::UUID;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION func_reset_password (
    p_account VARCHAR
)
RETURNS VARCHAR
AS $$
DECLARE
    v_code VARCHAR;
BEGIN
	 IF NOT EXISTS (
        SELECT 1 FROM users WHERE account = p_account
    ) THEN
        PERFORM util_raise_error('P0001', format('Account %s does not exist.', p_account));
    END IF;

	IF EXISTS (
        SELECT 1 
        FROM pending_reset_passwords 
        WHERE account = p_account
    ) THEN
        IF EXISTS (
            SELECT 1
            FROM pending_reset_passwords
            WHERE account = p_account
              AND now() - updated_at < interval '5 minutes'
        ) THEN
            PERFORM util_raise_error('P0002', format('Reset code was recently generated for %s. Please wait before requesting again.', p_account));
        END IF;

        v_code := util_generate_verification_code();
        UPDATE pending_reset_passwords
        SET verification_code = v_code,
            updated_at = now()
        WHERE account = p_account;

    ELSE
        v_code := util_generate_verification_code();
        INSERT INTO pending_reset_passwords (
            account,
            verification_code,
            created_at,
            updated_at
        ) VALUES (
            p_account,
            v_code,
            now(),
            now()
        );
    END IF;

    RETURN v_code;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cron_func_cleanup_pending_records(
) RETURNS void
AS $$
BEGIN
	DELETE FROM pending_users
    WHERE updated_at < NOW() - INTERVAL '24 hours';

    DELETE FROM pending_reset_passwords
    WHERE updated_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_query_user_by_id(
    p_id UUID
) RETURNS TABLE (
	id UUID,
    account VARCHAR,
	created_at TIMESTAMPTZ,
	updated_at TIMESTAMPTZ,
	last_login_at TIMESTAMPTZ,
	status INTEGER,
	role INTEGER,
    firstname VARCHAR,
    lastname VARCHAR,
    gender INTEGER,
    locale INTEGER,
    avatar VARCHAR,
    signature VARCHAR
)
AS $$
BEGIN
    RETURN QUERY
    SELECT
		u.id,
        u.account,
        u.created_at,
        u.updated_at,
		u.last_login_at,
        u.status,
        u.role,
        up.firstname,
        up.lastname,
        up.gender,
        up.locale,
        up.avatar,
        up.signature
    FROM users u
    JOIN user_profiles up ON u.id = up.id
    WHERE u.id = p_id;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION func_query_user_by_account(
    p_account VARCHAR
) RETURNS TABLE (
	id UUID,
    account VARCHAR,
	created_at TIMESTAMPTZ,
	updated_at TIMESTAMPTZ,
	last_login_at TIMESTAMPTZ,
	status INTEGER,
	role INTEGER,
    firstname VARCHAR,
    lastname VARCHAR,
    gender INTEGER,
    locale INTEGER,
    avatar VARCHAR,
    signature VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
		u.id,
        u.account,
        u.created_at,
        u.updated_at,
		u.last_login_at,
        u.status,
        u.role,
        up.firstname,
        up.lastname,
        up.gender,
        up.locale,
        up.avatar,
        up.signature
    FROM users u
    JOIN user_profiles up ON u.id = up.id
    WHERE u.account = p_account;
END;
$$ LANGUAGE plpgsql;

