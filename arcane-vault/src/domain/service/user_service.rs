use ethereal_core::proto::User;
use uuid::Uuid;

use crate::domain::error::ArcaneVaultError;


#[async_trait::async_trait]
pub trait UserService {
    async fn query_user_by_id(
        &self,
        uuid: &Uuid,
    ) -> Result<User, ArcaneVaultError>;
}