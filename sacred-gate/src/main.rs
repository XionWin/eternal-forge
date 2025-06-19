use tonic::transport::Server;

mod domain;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>>  {
    // let r = ethereal_core::proto::GetUserByIdRequest {
    //     id: String::from("1"),
    // };
    // println!("Hello, {r:#?}!");
    // let r = ethereal_core::proto::GetUserProfileByIdRequest {
    //     id: String::from("1"),
    // };
    // println!("Hello, {r:#?}!");

    // let uuid = "550e8400-e29b-41d4-a716-446655440000".parse::<uuid::Uuid>().ok().unwrap();
    // let user_service = arcane_vault::UserServiceApp::new().await;
    // let user = user_service
    //     .query_user_by_id(&uuid)
    //     .await
    //     .expect("get user faild");
    // println!("Hello, {user:#?}!");

    println!("gRPC server is starting...");
    let config = ethereal_core::configuration::TomlConfiguration::get_config("setting/Config.toml");

    let addr = format!(
        "{}:{}",
        config.get::<String>("sacred-gate[0].ip_address").unwrap(),
        config.get::<String>("sacred-gate[0].port").unwrap()
    )
    .parse()?;

    let encoded_file_descriptor_set = include_bytes!("../../ethereal-core/proto/my_service_descriptor.bin");
    let reflection_service = tonic_reflection::server::Builder::configure()
        .register_encoded_file_descriptor_set(encoded_file_descriptor_set)
        .build_v1()?;

    let user_service = crate::domain::service::UserService::new().await;

    Server::builder()
        .add_service(reflection_service)
        .add_service(ethereal_core::proto::user_service_server::UserServiceServer::new(user_service))
        .serve(addr)
        .await?;

    Ok(())
}
