use std::sync::Arc;
use tokio::sync::Mutex;

use ethereal_core::proto::User;

use crate::domain::error::ArcaneVaultError;

#[derive(Debug)]
pub struct Repository {
    client: Arc<Mutex<tokio_postgres::Client>>,
}

impl Repository {
    pub fn new(client: Arc<Mutex<tokio_postgres::Client>>) -> Self {
        Self { client }
    }

    pub async fn query_one(
        &self,
        statement: &str,
        params: &[&(dyn tokio_postgres::types::ToSql + Sync)],
    ) -> Result<User, ArcaneVaultError> {
        let row = self.client.lock().await
            .query_one(
                statement,
                params,
            )
            .await?;

        Ok(Self::get_user_from_row(&row))
    }

    fn get_user_from_row(row: &tokio_postgres::Row) -> User {
        let created_at: std::time::SystemTime = row.get("created_at");
        let updated_at: std::time::SystemTime = row.get("updated_at");
        User {
            id: crate::infrastructure::utility::get_string_from_uuid(row.get("id")),
            created_at: Some(prost_types::Timestamp::from(created_at)),
            updated_at: Some(prost_types::Timestamp::from(updated_at)),
            status: row.get("status"),
            role: row.get("role"),
            encryption_data: row.get("encryption_data"),
        }
    }
}