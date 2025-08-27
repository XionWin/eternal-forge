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

SELECT * FROM func_request_reset_password('puppywin@163.com');

SELECT * FROM pending_reset_passwords WHERE account = 'puppywin@163.com';
SELECT * FROM func_reset_password('puppywin@163.com', '5NLGBD', 'wenxuan815');


SELECT * FROM func_login_user(
    'puppywin@163.com',
    'Wenxuan815'
);


SELECT * FROM func_regenerate_verification_code('puppywin@163.com');

SELECT * FROM users inner join user_profiles on users.id = user_profiles.id;

SELECT * FROM func_query_user_by_id(
	(SELECT id FROM users WHERE account = 'puppywin@163.com')
);

SELECT * FROM func_query_user_by_account('puppywin@163.com');

SELECT version();