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

SELECT * FROM func_verify_user(
    'puppywin@163.com',
    'Wenxuan815',
    '9366'
);

SELECT * FROM users inner join user_profiles on users.id = user_profiles.id;

SELECT * FROM func_query_user_by_id('7b5e73b5-70c2-43dd-8224-dfa23d5573d4');

SELECT * FROM func_query_user_by_email_account('puppywin@163.com');