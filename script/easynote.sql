CREATE EXTENSION IF NOT EXISTS pgcrypto;

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
(1, 'Unverified', 'User account is unverified'),
(2, 'Active', 'User account is active'),
(3, 'Suspended', 'User account is suspended'),
(4, 'Deleted', 'User account is deleted');

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

CREATE OR REPLACE FUNCTION func_create_user(
    p_email_account VARCHAR,
	p_password VARCHAR,
    p_firstname VARCHAR,
    p_lastname VARCHAR,
    p_gender INTEGER,
    p_locale INTEGER,
    p_avatar VARCHAR,
    p_signature VARCHAR
) RETURNS UUID AS $$
DECLARE
    new_user_id UUID;
BEGIN
    INSERT INTO users (id, email_account, password, status, role)
    VALUES (
        gen_random_uuid(),
        p_email_account,
		crypt(p_password, gen_salt('bf')),
        1,
        2
    )
    RETURNING id INTO new_user_id;

    INSERT INTO user_profiles (
        id,
        firstname,
        lastname,
        gender,
        locale,
        avatar,
        signature
    )
    VALUES (
        new_user_id,
        p_firstname,
        p_lastname,
        p_gender,
        p_locale,
        p_avatar,
        p_signature
    );
    RETURN new_user_id;
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

