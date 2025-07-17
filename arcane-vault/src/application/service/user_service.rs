use ethereal_core::proto::User;
use uuid::Uuid;

use crate::{domain::error::{ArcaneVaultError, ArcaneVaultErrorCode}, infrastructure::repository::DbContext};

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
                    &email, &password, &firstname, &lastname, &gender, &locale, &avatar, &signature,
                ],
                get_user_id_from_row,
            )
            .await?;

        Ok(user_id)
    }

    async fn query_user_by_id(&self, id: Uuid) -> Result<Option<User>, ArcaneVaultError> {
        let sql_statement = r#"
            SELECT * FROM func_query_user_by_id(
                $1
            )
        "#;
        let row = self
            .db_context
            .get_repository()
            .await
            .query_one_row(sql_statement, &[&id])
            .await;
        match row {
            Ok(row) => Ok(Some(get_user_from_row(&row))),
            Err(e) if e.code == Some(ArcaneVaultErrorCode::NoData) => Ok(None),
            Err(e) => Err(e.into()),
        }
    }

    async fn query_user_by_email_account(
        &self,
        email_account: &str,
    ) -> Result<Option<User>, ArcaneVaultError> {
        let sql_statement = r#"
            SELECT * FROM func_query_user_by_email_account(
                $1
            )
        "#;
        let row = self
            .db_context
            .get_repository()
            .await
            .query_one_row(sql_statement, &[&email_account])
            .await;
        match row {
            Ok(row) => Ok(Some(get_user_from_row(&row))),
            Err(e) if e.code == Some(ArcaneVaultErrorCode::NoData) => Ok(None),
            Err(e) => Err(e.into()),
        }
    }
}

fn get_user_id_from_row(row: &tokio_postgres::Row) -> Uuid {
    let user_id: Uuid = row.get("user_id");
    user_id
}

fn get_user_from_row(row: &tokio_postgres::Row) -> User {
    let created_at: std::time::SystemTime = row.get("created_at");
    let updated_at: std::time::SystemTime = row.get("updated_at");
    let last_login_at: Option<std::time::SystemTime> = row.get("last_login_at");
    User {
        id: crate::infrastructure::utility::get_string_from_uuid(row.get("id")),
        email_account: row.get("email_account"),
        created_at: Some(prost_types::Timestamp::from(created_at)),
        updated_at: Some(prost_types::Timestamp::from(updated_at)),
        last_login_at: match last_login_at {
            Some(last_login_at) => Some(prost_types::Timestamp::from(last_login_at)),
            None => None,
        },
        status: row.get("status"),
        role: row.get("role"),
        firstname: row.get("firstname"),
        lastname: row.get("lastname"),
        gender: row.get("gender"),
        locale: row.get("locale"),
        avatar: row.get("avatar"),
        signature: row.get("signature"),
    }
}
