CREATE EXTENSION IF NOT EXISTS pgcrypto;

DROP TABLE IF EXISTS user_staging;
DROP TABLE IF EXISTS user_profiles;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS genders;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS user_statuses;
DROP TABLE IF EXISTS locales;

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

CREATE TABLE user_staging (
	email_account VARCHAR(255) PRIMARY KEY,
	password VARCHAR(255) NOT NULL,
	verification_code VARCHAR(4) NOT NULL,
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

CREATE OR REPLACE FUNCTION func_generate_verification_code()
RETURNS VARCHAR
LANGUAGE plpgsql
AS $$
DECLARE
    result VARCHAR;
BEGIN
    result := LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
    RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION func_verify_email_account (
    p_email_account VARCHAR
)
RETURNS BOOLEAN
AS $$
DECLARE
    is_available BOOLEAN;
BEGIN
	is_available :=  NOT (
		EXISTS (SELECT 1 FROM user_staging WHERE email_account = p_email_account)
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
	IF NOT func_verify_email_account(p_email_account) THEN
        RAISE EXCEPTION 'Email account % is already in use.', p_email_account;
    END IF;

	v_code := func_generate_verification_code();

    INSERT INTO user_staging (
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
RETURNS VARCHAR
AS $$
DECLARE
    v_user_id UUID;
    v_staging user_staging%ROWTYPE;
BEGIN
	SELECT *
    INTO v_staging
    FROM user_staging
    WHERE email_account = p_email_account
      AND crypt(p_password, password) = password
      AND verification_code = p_verification_code;
	  
	IF NOT FOUND THEN
        RETURN NULL;
    END IF;

	INSERT INTO users (
        email_account, password,
        status, role,
        created_at, updated_at, last_login_at
    ) VALUES (
        v_staging.email_account,
        v_staging.password,
        1,
        2,
        v_staging.created_at, now(), now()
    )
    RETURNING id INTO v_user_id;
	
    INSERT INTO user_profiles (
        id, firstname, lastname,
        gender, locale,
        avatar, signature
    ) VALUES (
        v_user_id,
        v_staging.firstname,
        v_staging.lastname,
        v_staging.gender,
        v_staging.locale,
        v_staging.avatar,
        v_staging.signature
    );
	
    DELETE FROM user_staging
    WHERE email_account = v_staging.email_account;
	
    RETURN v_user_id::VARCHAR;
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

