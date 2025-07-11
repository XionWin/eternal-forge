use crate::domain::error::ArcaneVaultError;


#[async_trait::async_trait]
pub trait SginupService: Sync + Send {
    async fn create_user(
        &self,
        email: &str,
        password: &str,
        first_name: &str,
        last_name: &str,
        gender: i32,
        locale_code: &str,
        avatar_url: &str,
        signature: &str,
    ) -> Result<String, ArcaneVaultError>;
}