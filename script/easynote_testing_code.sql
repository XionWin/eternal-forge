SELECT * FROM util_verify_account('puppywin@163.com');

SELECT * FROM util_generate_verification_code();

SELECT * FROM func_register_user(
    'puppywin@163.com',
    'Wenxuan815',
    'Puppy',
    'Win',
    1,
    1,
    'https://avatar.com/link',
    'My signature'
);

SELECT * FROM pending_users;

SELECT * FROM func_verify_user(
    'puppywin@163.com',
    'Wenxuan815',
    (SELECT verification_code FROM pending_users WHERE account = 'puppywin@163.com')
);

SELECT * FROM func_login_user(
    'puppywin@163.com',
    'Wenxuan815'
);


DO $$
DECLARE
    v_user_id UUID;
BEGIN
    SELECT id
    INTO v_user_id
    FROM users
    WHERE account = 'puppywin@163.com';

    PERFORM func_set_password(v_user_id, 'wenxuan815');
    PERFORM func_set_name(v_user_id, 'Jack', 'Wo');
    PERFORM func_set_avatar(v_user_id, 'https://new_avatar.com/link');
    PERFORM func_set_signature(v_user_id, 'My new signature');
    PERFORM func_set_gender(v_user_id, 2);
    PERFORM func_set_locale(v_user_id, 2);
END;
$$ LANGUAGE plpgsql;

SELECT * FROM func_login_user(
    'puppywin@163.com',
    'wenxuan815'
);


SELECT * FROM func_request_reset_password('puppywin@163.com');

SELECT * FROM pending_reset_passwords WHERE id = (SELECT id FROM users WHERE account = 'puppywin@163.com');
SELECT * FROM func_reset_password('puppywin@163.com', '9F7D5L', 'wenxuan815');

SELECT * FROM func_login_user(
    'puppywin@163.com',
    'wenxuan815'
);


SELECT * FROM func_regenerate_verification_code('puppywin@163.com');

SHOW TIMEZONE;
SET TIME ZONE 'Asia/Shanghai';
SELECT * FROM users inner join user_profiles on users.id = user_profiles.id;

SELECT * FROM func_query_user_by_id(
	(SELECT id FROM users WHERE account = 'puppywin@163.com')
);

SELECT * FROM func_query_user_by_account('puppywin@163.com');

SELECT version();

-- Collections
SELECT * FROM func_add_note(
	'First note',
	func_get_default_collection((SELECT id FROM users WHERE account = 'puppywin@163.com')),
	1
);

SELECT func_update_note_meta(
    (SELECT id FROM notes LIMIT 1),
    '{}'::jsonb
);

SELECT * FROM note_source_types;
SELECT * FROM collections;
SELECT * FROM notes;
