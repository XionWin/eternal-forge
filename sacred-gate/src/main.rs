#[tokio::main]
async fn main() {
    let r = ethereal_core::proto::GetUserByIdRequest {
        id: String::from("1"),
    };
    println!("Hello, {r:#?}!");
    let r = ethereal_core::proto::GetUserProfileByIdRequest {
        id: String::from("1"),
    };
    println!("Hello, {r:#?}!");

    let uuid = "550e8400-e29b-41d4-a716-446655440000".parse::<uuid::Uuid>().ok().unwrap();
    let user_service = arcane_vault::UserService::new().await;
    let user = user_service
        .query_user_by_id(&uuid)
        .await
        .expect("get user faild");
    println!("Hello, {user:#?}!");

    println!("Hello, world!");
}
