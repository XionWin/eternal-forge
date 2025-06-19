use ethereal_core::proto::User;
use uuid::Uuid;

use crate::{domain::error::ArcaneVaultError, infrastructure::repository::DbContext};

pub struct UserServiceApp {
    db_context: DbContext
}

impl UserServiceApp {
    pub async fn new() -> Box<dyn crate::domain::service::UserService> {
        Box::new(Self { db_context: DbContext::new().await.expect("Create db_context failed") })
    }
}

#[async_trait::async_trait]
impl crate::domain::service::UserService for UserServiceApp {
    async fn query_user_by_id(
        &self,
        uuid: &Uuid,
    ) -> Result<User, ArcaneVaultError> {
        let sql_statement = "SELECT id, created_at, updated_at, status, role, encryption_data FROM \"user\" where id = $1 LIMIT 1";
        self.db_context.get_repository().await.query_one(sql_statement, &[&uuid]).await
    }
}
