use uuid::Uuid;

use crate::domain::error::ArcaneVaultError;

#[async_trait::async_trait]
pub trait UserService: Sync + Send {
    async fn create_user(
        &self,
        email: &str,
        password: &str,
        firstname: &str,
        lastname: &str,
        gender: i32,
        locale: i32,
        avatar: &str,
        signature: &str,
    ) -> Result<Uuid, ArcaneVaultError>;
}