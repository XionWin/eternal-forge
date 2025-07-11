use std::sync::Arc;
use tokio::sync::Mutex;

use crate::domain::error::ArcaneVaultError;

#[derive(Debug)]
pub struct Repository {
    client: Arc<Mutex<tokio_postgres::Client>>,
}

impl Repository {
    pub fn new(client: Arc<Mutex<tokio_postgres::Client>>) -> Self {
        Self { client }
    }

    pub async fn query_one<T>(
        &self,
        statement: &str,
        params: &[&(dyn tokio_postgres::types::ToSql + Sync)],
        get_instance_func: fn(&tokio_postgres::row::Row) -> T
    ) -> Result<T, ArcaneVaultError> {
        let row = self.client.lock().await
            .query_one(
                statement,
                params,
            )
            .await?;

        Ok(get_instance_func(&row))
    }
}