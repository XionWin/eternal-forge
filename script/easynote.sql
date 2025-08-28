CREATE EXTENSION IF NOT EXISTS pgcrypto;


DROP TABLE IF EXISTS pending_reset_passwords CASCADE;
DROP TABLE IF EXISTS pending_users CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS genders CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TABLE IF EXISTS user_statuses CASCADE;
DROP TABLE IF EXISTS locales CASCADE;
DROP TABLE IF EXISTS error_codes CASCADE;


DROP FUNCTION IF EXISTS func_login_user (
    p_account VARCHAR,
	p_password VARCHAR
);
DROP TYPE IF EXISTS login_status CASCADE;
CREATE TYPE login_status AS ENUM (
	'SUCCESS',
	'PENDING',
	'PASSWORD_WRONG',
	'NOT_FOUND'
);
		
CREATE TABLE error_codes (
    errcode TEXT PRIMARY KEY,
    param_count INT NOT NULL,
    message_template TEXT NOT NULL
);
INSERT INTO error_codes (errcode, param_count, message_template) VALUES
('P0001', 1, 'Account %s is not available.'),
('P0002', 1, 'Account %s was not registered.'),
('P0003', 1, 'Verification code was recently generated for account %s. Please wait before requesting again.'),
('P0004', 1, 'Account %s is not found.'),
('P0005', 1, 'Reset code was recently generated for account %s. Please wait before requesting again.'),
('P0006', 1, 'No reset request found for account %s.'),
('P0007', 0, 'Invalid verification code.'),
('P0008', 0, 'Verification code expired.'),
('P0009', 1, 'User profile with account %s not found.');

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
    VARIADIC p_args TEXT[]
) RETURNS void AS $$
DECLARE
    v_template TEXT;
    v_param_count INT;
BEGIN
    SELECT message_template, param_count
    INTO v_template, v_param_count
    FROM error_codes
    WHERE errcode = p_errcode;

    IF v_template IS NULL THEN
        RAISE EXCEPTION 'Unknown error code: %', p_errcode;
    END IF;

    IF array_length(p_args, 1) <> v_param_count THEN
        RAISE EXCEPTION 'Incorrect number of arguments for error code %: expected %, got %',
            p_errcode, v_param_count, array_length(p_args, 1);
    END IF;

    RAISE EXCEPTION '%', format(v_template, VARIADIC p_args)
        USING HINT = p_errcode;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION util_raise_error(
    p_errcode TEXT
) RETURNS void AS $$
BEGIN
    PERFORM util_raise_error(p_errcode, VARIADIC ARRAY[]::TEXT[]);
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
	    PERFORM util_raise_error('P0001', p_account);
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
		PERFORM util_raise_error('P0002', p_account);
	END IF;
	
	IF EXISTS (
        SELECT 1
        FROM pending_users
        WHERE account = p_account
        	AND now() - updated_at < interval '5 minutes'
    ) THEN
        PERFORM util_raise_error('P0003', p_account);
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
    SELECT 'PASSWORD_WRONG'::login_status AS code, NULL::UUID
    FROM users
    WHERE account = p_account
    LIMIT 1;
    IF FOUND THEN
        RETURN;
    END IF;
	
    RETURN QUERY
    SELECT 'NOT_FOUND'::login_status AS code, NULL::UUID;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_request_reset_password (
    p_account VARCHAR
)
RETURNS TEXT
AS $$
DECLARE
    v_code TEXT;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM users WHERE account = p_account
    ) THEN
        PERFORM util_raise_error('P0004', p_account);
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
            PERFORM util_raise_error('P0005', p_account);
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

CREATE OR REPLACE FUNCTION func_reset_password (
    p_account VARCHAR,
    p_verification_code VARCHAR,
	p_new_password VARCHAR
)
RETURNS void
AS $$
DECLARE
    v_row pending_reset_passwords%ROWTYPE;
BEGIN
    SELECT *
    INTO v_row
    FROM pending_reset_passwords
    WHERE account = p_account;

    IF NOT FOUND THEN
        PERFORM util_raise_error('P0006', p_account);
    END IF;

    IF v_row.verification_code <> p_verification_code THEN
        PERFORM util_raise_error('P0007');
    END IF;

    IF now() - v_row.updated_at > interval '15 minutes' THEN
        PERFORM util_raise_error('P0008');
    END IF;

    UPDATE users
	SET password = crypt(p_new_password, gen_salt('bf')),
	    updated_at = now()
	WHERE account = p_account;

    DELETE FROM pending_reset_passwords WHERE account = p_account;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_set_password(
	p_id UUID,
	p_password VARCHAR
) RETURNS void
AS $$
DECLARE
    v_account VARCHAR;
BEGIN
    SELECT account
    INTO v_account
    FROM users
    WHERE id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('P0001', p_id);
    END IF;
	
    UPDATE users
	SET password = crypt(p_password, gen_salt('bf')),
	    updated_at = now()
    WHERE id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('P0009', v_account);
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_set_name(
	p_id UUID,
	p_first_name VARCHAR,
	p_last_name VARCHAR
) RETURNS void
AS $$
DECLARE
    v_account VARCHAR;
BEGIN
    SELECT account
    INTO v_account
    FROM users
    WHERE id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('P0001', p_id);
    END IF;
	
    UPDATE user_profiles up
    SET firstname = p_first_name,
        lastname  = p_last_name
	From users u
	WHERE up.id = u.id
		AND up.id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('P0009', v_account);
    END IF;

    UPDATE users
    SET updated_at = now()
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_set_gender(
    p_id UUID,
    p_gender INTEGER
) RETURNS void
AS $$
DECLARE
    v_account VARCHAR;
BEGIN
    SELECT account
    INTO v_account
    FROM users
    WHERE id = p_id;

    IF NOT FOUND THEN
        PERFORM util_raise_error('P0001', p_id);
    END IF;
	
    UPDATE user_profiles up
    SET gender = p_gender
	From users u
	WHERE up.id = u.id
		AND up.id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('P0009', v_account);
    END IF;

    UPDATE users
    SET updated_at = now()
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_set_locale(
    p_id UUID,
    p_locale INTEGER
) RETURNS void
AS $$
DECLARE
    v_account VARCHAR;
BEGIN
    SELECT account
    INTO v_account
    FROM users
    WHERE id = p_id;

    IF NOT FOUND THEN
        PERFORM util_raise_error('P0001', p_id);
    END IF;
	
    UPDATE user_profiles up
    SET locale = p_locale
	From users u
	WHERE up.id = u.id
		AND up.id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('P0009', v_account);
    END IF;

    UPDATE users
    SET updated_at = now()
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_set_avatar(
    p_id UUID,
    p_avatar VARCHAR
) RETURNS void
AS $$
DECLARE
    v_account VARCHAR;
BEGIN
    SELECT account
    INTO v_account
    FROM users
    WHERE id = p_id;

    IF NOT FOUND THEN
        PERFORM util_raise_error('P0001', p_id);
    END IF;
	
    UPDATE user_profiles up
    SET avatar = p_avatar
	From users u
	WHERE up.id = u.id
		AND up.id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('P0009', v_account);
    END IF;

    UPDATE users
    SET updated_at = now()
    WHERE id = p_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_set_signature(
    p_id UUID,
    p_signature VARCHAR
) RETURNS void
AS $$
DECLARE
    v_account VARCHAR;
BEGIN
    SELECT account
    INTO v_account
    FROM users
    WHERE id = p_id;

    IF NOT FOUND THEN
        PERFORM util_raise_error('P0001', p_id);
    END IF;
	
    UPDATE user_profiles up
    SET signature = p_signature
	From users u
	WHERE up.id = u.id
		AND up.id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('P0009', v_account);
    END IF;

    UPDATE users
    SET updated_at = now()
    WHERE id = p_id;
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

