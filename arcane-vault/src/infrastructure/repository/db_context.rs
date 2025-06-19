use std::sync::Arc;
use tokio::sync::Mutex;

use tokio_postgres::{Error, NoTls};

use super::Repository;

#[derive(Debug)]
pub struct DbError {
    details: String,
}

impl DbError {
    fn new(msg: &str) -> DbError {
        DbError {
            details: msg.to_string(),
        }
    }
}

impl std::fmt::Display for DbError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "CustomError: {}", self.details)
    }
}

impl From<tokio_postgres::Error> for DbError {
    fn from(value: tokio_postgres::Error) -> Self {
        Self::new(&format!("Tokio Postgres Error: {}", value))
    }
}

#[derive(Debug)]
pub struct DbContext {
    client: Arc<Mutex<tokio_postgres::Client>>,
}

impl DbContext {
    pub async fn new() -> Result<Self, Error> {
        Ok(Self {
            client: Arc::new(Mutex::new(create_db_client().await?)),
        })
    }

    pub async fn get_repository(&self) -> Repository {
        Repository::new(self.get_client().await)
    }

    async fn get_client(&self) -> Arc<Mutex<tokio_postgres::Client>> {
        self.client.clone()
    }
}

async fn create_db_client() -> Result<tokio_postgres::Client, Error> {
    let config = ethereal_core::configuration::TomlConfiguration::get_config("setting/Config.toml");

    let ip_address = config.get::<String>("arcane-vault[0].ip_address").unwrap();
    let username = config.get::<String>("arcane-vault[0].username").unwrap();
    let password = config.get::<String>("arcane-vault[0].password").unwrap();
    let database_name = config.get::<String>("arcane-vault[0].database_name").unwrap();

    let (client, connection) = tokio_postgres::connect(
        &format!(
            "host={} user={} password={} dbname={}",
            &ip_address, &username, &password, &database_name
        ),
        NoTls,
    )
    .await?;

    tokio::spawn(async move { connection.await });

    Ok(client)
}
