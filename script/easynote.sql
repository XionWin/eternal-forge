CREATE EXTENSION IF NOT EXISTS pgcrypto;

DROP TABLE IF EXISTS pending_users;
DROP TABLE IF EXISTS user_profiles;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS genders;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS user_statuses;
DROP TABLE IF EXISTS locales;
DROP TABLE IF EXISTS reset_password_staging;

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
    language_code CHAR(2) NOT NULL,
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
	email_account VARCHAR(255) PRIMARY KEY,
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
    email_account VARCHAR(255) NOT NULL UNIQUE,
	password VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
	last_login_at TIMESTAMPTZ DEFAULT NULL,
    status INTEGER NOT NULL,
    role INTEGER NOT NULL,
    CONSTRAINT fk_status FOREIGN KEY (status) REFERENCES user_statuses(id),
    CONSTRAINT fk_role FOREIGN KEY (role) REFERENCES roles(id)
);
CREATE INDEX idx_users_email_account ON users(email_account);

CREATE TABLE user_profiles (
    id UUID PRIMARY KEY,
    firstname VARCHAR(255) NOT NULL,
    lastname VARCHAR(255) NOT NULL,
    gender INTEGER NOT NULL,
    locale INTEGER NOT NULL,
    avatar VARCHAR(255),
    signature VARCHAR(255),
	CONSTRAINT fk_id FOREIGN KEY (id) REFERENCES users(id),
	CONSTRAINT fk_gender FOREIGN KEY (gender) REFERENCES genders(id),
	CONSTRAINT fk_locale FOREIGN KEY (locale) REFERENCES locales(id)
);

CREATE TABLE reset_password_staging (
	email_account VARCHAR(255) PRIMARY KEY,
	verification_code VARCHAR(6) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
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
	-- REMOVE 'I', 'O', '1', '0'
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

CREATE OR REPLACE FUNCTION util_verify_email_account (
    p_email_account VARCHAR
)
RETURNS BOOLEAN
AS $$
DECLARE
    is_available BOOLEAN;
BEGIN
	is_available :=  NOT (
		EXISTS (SELECT 1 FROM pending_users WHERE email_account = p_email_account)
       	OR EXISTS (SELECT 1 FROM users WHERE email_account = p_email_account)
   );
	RETURN is_available;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_register_user (
    p_email_account VARCHAR,
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
	IF NOT util_verify_email_account(p_email_account) THEN
	    PERFORM util_raise_error('P0003', format('Email account %s is already in use.', p_email_account));
    END IF;

	v_code := util_generate_verification_code();

    INSERT INTO pending_users (
        email_account,
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
        p_email_account,
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
    p_email_account VARCHAR,
	p_password VARCHAR,
    p_verification_code VARCHAR
)
RETURNS UUID
AS $$
DECLARE
    v_user_id UUID;
    v_pending_user pending_users%ROWTYPE;
BEGIN
	SELECT *
    INTO v_pending_user
    FROM pending_users
    WHERE email_account = p_email_account
		AND crypt(p_password, password) = password
    	AND verification_code = UPPER(p_verification_code);
	  
	IF NOT FOUND THEN
        RETURN NULL;
    END IF;

	INSERT INTO users (
        email_account, password,
        status, role,
        created_at, updated_at, last_login_at
    ) VALUES (
        v_pending_user.email_account,
        v_pending_user.password,
        1,
        2,
        v_pending_user.created_at, now(), now()
    )
    RETURNING id INTO v_user_id;
	
    INSERT INTO user_profiles (
        id, firstname, lastname,
        gender, locale,
        avatar, signature
    ) VALUES (
        v_user_id,
        v_pending_user.firstname,
        v_pending_user.lastname,
        v_pending_user.gender,
        v_pending_user.locale,
        v_pending_user.avatar,
        v_pending_user.signature
    );
	
    DELETE FROM pending_users
    WHERE email_account = v_pending_user.email_account;
	
    RETURN v_user_id::UUID;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION func_login_user (
    p_email_account VARCHAR,
	p_password VARCHAR
)
RETURNS TABLE (
	code INTEGER,
    user_id UUID
)
AS $$
DECLARE
    v_user_id UUID;
BEGIN
	RETURN QUERY
    SELECT 0 AS code, user_id::UUID
    FROM users
    WHERE email_account = p_email_account
      AND password = crypt(p_password, password)
    LIMIT 1;
    IF FOUND THEN
        RETURN;
    END IF;

    RETURN QUERY
    SELECT 1 AS code, NULL::UUID
    FROM pending_users
    WHERE email_account = p_email_account
    LIMIT 1;
    IF FOUND THEN
        RETURN;
    END IF;
	
    RETURN QUERY
    SELECT -1 AS code, NULL::UUID;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_regenerate_verification_code (
    p_email_account VARCHAR
)
RETURNS VARCHAR
AS $$
DECLARE
    v_code VARCHAR;
BEGIN
	IF NOT EXISTS (
	    SELECT 1
	    FROM pending_users
	    WHERE email_account = p_email_account
	) THEN
	    PERFORM util_raise_error('P0001', format('Email account %s does not exist.', p_email_account));
	END IF;
	
	IF EXISTS (
        SELECT 1
        FROM pending_users
        WHERE email_account = p_email_account
        	AND now() - updated_at < interval '5 minutes'
    ) THEN
        PERFORM util_raise_error('P0002', format('Verification code was recently generated. Please wait before requesting again.'));
    END IF;
	
	v_code := util_generate_verification_code();
	UPDATE pending_users
	SET verification_code = v_code, updated_at = now()
	WHERE email_account = p_email_account;
	
	RETURN v_code;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION func_query_user_by_id(
    p_id UUID
) RETURNS TABLE (
	id UUID,
    email_account VARCHAR,
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
        u.email_account,
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


CREATE OR REPLACE FUNCTION func_query_user_by_email_account(
    p_email_account VARCHAR
) RETURNS TABLE (
	id UUID,
    email_account VARCHAR,
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
        u.email_account,
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
    WHERE u.email_account = p_email_account;
END;
$$ LANGUAGE plpgsql;

