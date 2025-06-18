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
        self.db_context.get_user_repository().await.query_user_by_id(uuid).await
    }
}