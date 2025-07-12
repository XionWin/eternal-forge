use ethereal_core::proto::User;
use uuid::Uuid;

use crate::{domain::error::ArcaneVaultError, infrastructure::repository::DbContext};

pub struct UserService {
    db_context: DbContext,
}

impl UserService {
    pub async fn new() -> Box<dyn crate::domain::service::UserService> {
        Box::new(Self {
            db_context: DbContext::new().await.expect("Create db_context failed"),
        })
    }
}

#[async_trait::async_trait]
impl crate::domain::service::UserService for UserService {
    async fn query_user_by_id(&self, uuid: &Uuid) -> Result<User, ArcaneVaultError> {
        let sql_statement = "SELECT id, created_at, updated_at, status, role, encryption_data FROM \"user\" where id = $1 LIMIT 1";
        self.db_context
            .get_repository()
            .await
            .query_one(sql_statement, &[&uuid], get_user_from_row)
            .await
    }
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
