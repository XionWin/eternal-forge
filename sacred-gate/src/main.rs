use tonic::transport::Server;

mod service;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("[sacred-gate] is starting...");
    let config = ethereal_core::configuration::TomlConfiguration::get_config("setting/Config.toml");

    let addr = format!(
        "{}:{}",
        config.get::<String>("sacred-gate[0].ip_address").unwrap(),
        config.get::<String>("sacred-gate[0].port").unwrap(),
    )
    .parse()?;

    let encoded_file_descriptor_set =
        include_bytes!("../../ethereal-core/proto/service_descriptor.bin");
    let reflection_service = tonic_reflection::server::Builder::configure()
        .register_encoded_file_descriptor_set(encoded_file_descriptor_set)
        .build_v1()?;

    let user_service = crate::service::UserService::new().await;

    Server::builder()
        .add_service(reflection_service)
        .add_service(
            ethereal_core::proto::user_service_server::UserServiceServer::new(user_service),
        )
        .serve(addr)
        .await?;

    Ok(())
}
