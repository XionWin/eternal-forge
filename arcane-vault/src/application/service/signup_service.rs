use uuid::Uuid;

use crate::{domain::error::ArcaneVaultError, infrastructure::repository::DbContext};

pub struct SignupService {
    db_context: DbContext,
}

impl SignupService {
    pub async fn new() -> Box<dyn crate::domain::service::SginupService> {
        Box::new(Self {
            db_context: DbContext::new().await.expect("Create db_context failed"),
        })
    }
}

#[async_trait::async_trait]
impl crate::domain::service::SginupService for SignupService {
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
    ) -> Result<Uuid, ArcaneVaultError> {
        let sql_statement = r#"
            SELECT func_create_user(
                $1, $2, $3, $4, $5, $6, $7, $8
            ) AS user_id
        "#;
        let user_id = self
            .db_context
            .get_repository()
            .await
            .query_one(
                sql_statement,
                &[
                    &email,
                    &password,
                    &firstname,
                    &lastname,
                    &gender,
                    &locale,
                    &avatar,
                    &signature,
                ],
                get_user_id_from_row,
            )
            .await?;

        Ok(user_id)
    }
}

fn get_user_id_from_row(row: &tokio_postgres::Row) -> Uuid {
    let user_id: Uuid = row.get("user_id");
    user_id
}
