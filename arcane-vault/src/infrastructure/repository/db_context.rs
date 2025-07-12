use deadpool_postgres::{Pool, Runtime};
use tokio_postgres::NoTls;

use crate::domain::error::ArcaneVaultError;
use crate::infrastructure::repository::Repository;

#[derive(Debug, Clone)]
pub struct DbContext {
    pool: Pool,
}

impl DbContext {
    pub async fn new() -> Result<Self, ArcaneVaultError> {
        let pool = create_db_pool().await?;
        Ok(Self { pool })
    }

    pub async fn get_repository(&self) -> Repository {
        Repository::new(self.pool.clone())
    }
}

async fn create_db_pool() -> Result<Pool, ArcaneVaultError> {
    let config = ethereal_core::configuration::TomlConfiguration::get_config("setting/Config.toml");

    let ip_address = config.get::<String>("arcane-vault[0].ip_address").unwrap();
    let username = config.get::<String>("arcane-vault[0].username").unwrap();
    let password = config.get::<String>("arcane-vault[0].password").unwrap();
    let database_name = config.get::<String>("arcane-vault[0].database_name").unwrap();

    let mut cfg = deadpool_postgres::Config::new();
    cfg.host = Some(ip_address);
    cfg.user = Some(username);
    cfg.password = Some(password);
    cfg.dbname = Some(database_name);

    cfg.create_pool(Some(Runtime::Tokio1), NoTls)
        .map_err(ArcaneVaultError::from)
}
