use ethereal_core::proto::User;
use uuid::Uuid;

use crate::infrastructure::repository::{DbContext, DbError};

pub struct UserService {
    db_context: DbContext
}

impl UserService {
    pub async fn new() -> Self {
        Self { db_context: DbContext::new().await.expect("Create db_context failed") }
    }
    pub async fn query_user_by_id(
        &self,
        uuid: &Uuid,
    ) -> Result<User, DbError> {
        let sql_statement = "SELECT id, created_at, updated_at, status, role, encryption_data FROM \"user\" where id = $1 LIMIT 1";
        self.db_context.get_repository().await.query_one(sql_statement, &[&uuid]).await
    }
}