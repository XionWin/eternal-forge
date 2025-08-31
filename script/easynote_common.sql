CREATE EXTENSION IF NOT EXISTS pgcrypto;


DROP TABLE IF EXISTS pending_reset_passwords CASCADE;
DROP TABLE IF EXISTS pending_users CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS genders CASCADE;
DROP TABLE IF EXISTS roles CASCADE;
DROP TABLE IF EXISTS user_statuses CASCADE;
DROP TABLE IF EXISTS locales CASCADE;
DROP TABLE IF EXISTS timezones CASCADE;
DROP TABLE IF EXISTS error_codes CASCADE;
		
CREATE TABLE error_codes (
    errcode TEXT PRIMARY KEY,
    param_count INT NOT NULL,
    message_template TEXT NOT NULL
);
INSERT INTO error_codes (errcode, param_count, message_template) VALUES
-- ACCOUNT
('PA001', 1, 'Account %s is unavailable.'),
('PA002', 1, 'Account %s is not registered.'),
('PA003', 1, 'Account %s was not found.'),
('PA004', 1, 'Account %s is pending activation.'),
('PA005', 1, 'Invalid password for account %s.'),
('PA006', 1, 'User profile for account %s was not found.'),
('PA007', 1, 'User ID %s not found.'),

('PA008', 1, 'Verification code for account %s was recently generated. Please wait before requesting again.'),
('PA009', 0, 'Invalid verification code.'),
('PA010', 0, 'Verification code expired.'),
('PA011', 1, 'No password reset request found for account %s.'),


('PN001', 2, 'Category % does not belong to user %.');

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
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
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
    now()
),
(
    2,
    'zh',
    'zh-CN',
    'Chinese (Simplified)',
    '简体中文',
    FALSE,
    TRUE,
    now()
);

CREATE TABLE timezones (
    name TEXT PRIMARY KEY
);
INSERT INTO timezones (name)
SELECT name FROM pg_timezone_names;

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
CREATE OR REPLACE FUNCTION trgfn_pending_users_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
	IF (NEW.last_login_at IS DISTINCT FROM OLD.last_login_at)
	   AND (NEW.account        IS NOT DISTINCT FROM OLD.account)
       AND (NEW.password       IS NOT DISTINCT FROM OLD.password)
       AND (NEW.verification_code IS NOT DISTINCT FROM OLD.verification_code)
       AND (NEW.firstname      IS NOT DISTINCT FROM OLD.firstname)
       AND (NEW.lastname       IS NOT DISTINCT FROM OLD.lastname)
       AND (NEW.gender         IS NOT DISTINCT FROM OLD.gender)
       AND (NEW.locale         IS NOT DISTINCT FROM OLD.locale)
       AND (NEW.avatar         IS NOT DISTINCT FROM OLD.avatar)
       AND (NEW.signature      IS NOT DISTINCT FROM OLD.signature) THEN
	 		RETURN NEW;
	END IF;
	
	NEW.updated_at := now();
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_pending_users_set_updated_at_on_update ON pending_users;
CREATE TRIGGER trg_pending_users_set_updated_at_on_update
BEFORE UPDATE ON pending_users
FOR EACH ROW
EXECUTE FUNCTION trgfn_pending_users_set_updated_at();

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
CREATE OR REPLACE FUNCTION trgfn_users_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
	IF (NEW.last_login_at 	IS DISTINCT FROM OLD.last_login_at)
	   AND (NEW.id       	IS NOT DISTINCT FROM OLD.id)
       AND (NEW.account		IS NOT DISTINCT FROM OLD.account)
       AND (NEW.password	IS NOT DISTINCT FROM OLD.password)
       AND (NEW.status      IS NOT DISTINCT FROM OLD.status)
       AND (NEW.role      	IS NOT DISTINCT FROM OLD.role) THEN
	 		RETURN NEW;
	   RETURN NEW;
	END IF;
	
	NEW.updated_at := now();
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_users_set_updated_at_on_update ON users;
CREATE TRIGGER trg_users_set_updated_at_on_update
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION trgfn_users_set_updated_at();

CREATE TABLE user_profiles (
    id UUID PRIMARY KEY,
    firstname VARCHAR(255) NOT NULL,
    lastname VARCHAR(255) NOT NULL,
    gender INTEGER NOT NULL,
    locale INTEGER NOT NULL,
    timezone TEXT NOT NULL DEFAULT 'UTC',
    avatar VARCHAR(255),
    signature VARCHAR(255),
    CONSTRAINT fk_user_profiles_id FOREIGN KEY (id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_profiles_gender FOREIGN KEY (gender) REFERENCES genders(id),
    CONSTRAINT fk_user_profiles_locale FOREIGN KEY (locale) REFERENCES locales(id),
    CONSTRAINT fk_user_profiles_timezone FOREIGN KEY (timezone) REFERENCES timezones(name)
);

CREATE TABLE pending_reset_passwords (
	id UUID PRIMARY KEY,
	verification_code VARCHAR(6) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
	CONSTRAINT fk_pending_reset_passwords_account FOREIGN KEY (id) REFERENCES users(id)
);
CREATE OR REPLACE FUNCTION trgfn_pending_reset_passwords_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS trg_pending_reset_passwords_set_updated_at_on_update ON pending_reset_passwords;
CREATE TRIGGER trg_pending_reset_passwords_set_updated_at_on_update
BEFORE UPDATE ON pending_reset_passwords
FOR EACH ROW
EXECUTE FUNCTION trgfn_pending_reset_passwords_set_updated_at();

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
        RAISE EXCEPTION 'Error in function %s: Unknown error code: %', util_get_current_function_name(), p_errcode;
    END IF;

    IF array_length(p_args, 1) <> v_param_count THEN
        RAISE EXCEPTION 'Error in function %s: Incorrect number of arguments for error code %: expected %, got %',
            util_get_current_function_name(), p_errcode, v_param_count, array_length(p_args, 1);
    END IF;

    RAISE EXCEPTION '%', format('Error in function %s: %s', util_get_current_function_name(), format(v_template, VARIADIC p_args))
        USING HINT = p_errcode;
END;
$$ LANGUAGE plpgsql;

-- Get function name from stack, so it only can be called from the function which call util_raise_error function directly.
CREATE OR REPLACE FUNCTION util_get_current_function_name()
RETURNS text AS  $$
DECLARE
  stack text; fcesig text;
BEGIN
  GET DIAGNOSTICS stack = PG_CONTEXT;
  fcesig := substring(substring(substring(stack from 'unction (.*)') from 'unction (.*)') from 'function (.*?) line');
  RETURN fcesig::regprocedure::text;
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
	    PERFORM util_raise_error('PA001', p_account);
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
    BEGIN
        SELECT *
        INTO v_pending_user
        FROM pending_users
        WHERE account = p_account
            AND crypt(p_password, password) = password
            AND verification_code = UPPER(p_verification_code);
        
        IF NOT FOUND THEN
        	PERFORM util_raise_error('PA002', p_account);
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
    END;
	
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
		PERFORM util_raise_error('PA002', p_account);
	END IF;
	
	IF EXISTS (
        SELECT 1
        FROM pending_users
        WHERE account = p_account
        	AND now() - updated_at < interval '5 minutes'
    ) THEN
        PERFORM util_raise_error('PA008', p_account);
    END IF;
	
	v_code := util_generate_verification_code();
	UPDATE pending_users
	SET verification_code = v_code
	WHERE account = p_account;
	
	RETURN v_code;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_login_user (
    p_account VARCHAR,
	p_password VARCHAR
)
RETURNS UUID
AS $$
DECLARE
    v_id UUID;
BEGIN
	SELECT users.id INTO v_id
	FROM users
	WHERE account = p_account
	  AND password = crypt(p_password, password)
	LIMIT 1;
	
    IF FOUND THEN
		UPDATE users
		SET last_login_at = now()
		WHERE users.id  = v_id;
		
        RETURN v_id;
    END IF;

    IF EXISTS (SELECT 1 FROM pending_users WHERE account = p_account LIMIT 1) THEN
        PERFORM util_raise_error('PA004', p_account);
    END IF;

    IF EXISTS (SELECT 1 FROM users WHERE account = p_account LIMIT 1) THEN
        PERFORM util_raise_error('PA005', p_account);
    END IF;
	
	PERFORM util_raise_error('PA003', p_account);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_request_reset_password (
    p_account VARCHAR
)
RETURNS TEXT
AS $$
DECLARE
    v_user_id UUID;
    v_code TEXT;
BEGIN
    SELECT id INTO v_user_id
    FROM users
    WHERE account = p_account;
    IF NOT FOUND THEN
        PERFORM util_raise_error('PA003', p_account);
    END IF;

    IF EXISTS (
        SELECT 1 
        FROM pending_reset_passwords 
        WHERE id = v_user_id
    ) THEN
       IF EXISTS (
            SELECT 1
            FROM pending_reset_passwords
            WHERE id = v_user_id
              AND now() - updated_at < interval '5 minutes'
        ) THEN
            PERFORM util_raise_error('PA008', p_account);
        END IF;

        v_code := util_generate_verification_code();
        UPDATE pending_reset_passwords
        SET verification_code = v_code
        WHERE id = v_user_id;

    ELSE
        v_code := util_generate_verification_code();
        INSERT INTO pending_reset_passwords (
            id,
            verification_code,
            created_at,
            updated_at
        ) VALUES (
            v_user_id,
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
    v_user_id UUID;
    v_row pending_reset_passwords%ROWTYPE;
BEGIN
    SELECT id INTO v_user_id
    FROM users
    WHERE account = p_account;
    IF NOT FOUND THEN
        PERFORM util_raise_error('PA003', p_account);
    END IF;

    SELECT *
    INTO v_row
    FROM pending_reset_passwords
    WHERE id = v_user_id;

    IF NOT FOUND THEN
        PERFORM util_raise_error('PA011', p_account);
    END IF;

    IF v_row.verification_code <> p_verification_code THEN
        PERFORM util_raise_error('PA009');
    END IF;

    IF now() - v_row.updated_at > interval '15 minutes' THEN
        PERFORM util_raise_error('PA010');
    END IF;

    UPDATE users
	SET password = crypt(p_new_password, gen_salt('bf'))
    WHERE id = v_user_id;

    DELETE FROM pending_reset_passwords WHERE id = v_user_id;
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
	    PERFORM util_raise_error('PA007', p_id);
    END IF;
	
    UPDATE users
	SET password = crypt(p_password, gen_salt('bf'))
    WHERE id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('PA006', v_account);
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION func_set_name(
	p_id UUID,
	p_firstname VARCHAR,
	p_lastname VARCHAR
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
	    PERFORM util_raise_error('PA007', p_id);
    END IF;
	
    UPDATE user_profiles up
    SET firstname = p_firstname,
        lastname  = p_lastname
	From users u
	WHERE up.id = u.id
		AND up.id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('PA006', v_account);
    END IF;
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
        PERFORM util_raise_error('PA007', p_id);
    END IF;
	
    UPDATE user_profiles up
    SET gender = p_gender
	From users u
	WHERE up.id = u.id
		AND up.id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('PA006', v_account);
    END IF;
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
        PERFORM util_raise_error('PA007', p_id);
    END IF;
	
    UPDATE user_profiles up
    SET locale = p_locale
	From users u
	WHERE up.id = u.id
		AND up.id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('PA006', v_account);
    END IF;
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
        PERFORM util_raise_error('PA007', p_id);
    END IF;
	
    UPDATE user_profiles up
    SET avatar = p_avatar
	From users u
	WHERE up.id = u.id
		AND up.id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('PA006', v_account);
    END IF;
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
        PERFORM util_raise_error('PA007', p_id);
    END IF;
	
    UPDATE user_profiles up
    SET signature = p_signature
	From users u
	WHERE up.id = u.id
		AND up.id = p_id;

    IF NOT FOUND THEN
	    PERFORM util_raise_error('PA006', v_account);
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION cron_func_cleanup_pending_records(
) RETURNS void
AS $$
BEGIN
	DELETE FROM pending_users
    WHERE updated_at < now() - INTERVAL '24 hours';

    DELETE FROM pending_reset_passwords
    WHERE updated_at < now() - INTERVAL '24 hours';
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

