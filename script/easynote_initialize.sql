SELECT * FROM func_verify_email_account('puppywin@163.com');

SELECT * FROM func_register_user(
    'puppywin@163.com',
    'Wenxuan815',
    'Puppy',
    'Win',
    1,
    1,
    'https://avatar.com/link',
    'Hello'
);

SELECT * FROM user_staging;

SELECT * FROM users inner join user_profiles on users.id = user_profiles.id;

SELECT * FROM func_query_user_by_id('98b7bd95-4a08-4347-a751-19a269327c45');

SELECT * FROM func_query_user_by_email_account('puppywin@163.com');