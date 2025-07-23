use ethereal_core::proto::User;
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
    ) -> Result<String, ArcaneVaultError>;
    async fn verify_user(
        &self,
        email: &str,
        password: &str,
        verification_code: &str,
    ) -> Result<Uuid, ArcaneVaultError>;

    async fn query_user_by_id(
        &self,
        id: Uuid,
    ) -> Result<Option<User>, ArcaneVaultError>;

    async fn query_user_by_email_account(
        &self,
        email_account: &str,
    ) -> Result<Option<User>, ArcaneVaultError>;

}