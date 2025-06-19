use tokio_postgres::error::DbError;
#[derive(Debug)]
pub struct ArcaneVaultError {
    pub message: String,
    pub code: Option<String>,
}

impl std::fmt::Display for ArcaneVaultError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let code_message = match &self.code {
            Some(code) => format!("[error code: {}]", code),
            None => String::new()
        };
        write!(f, "arcane-vault error: {} {}", self.message, code_message)
    }
}

impl std::error::Error for ArcaneVaultError {}

impl From<DbError> for ArcaneVaultError {
    fn from(err: DbError) -> Self {
        ArcaneVaultError {
            message: err.message().to_string(),
            code: Some(err.code().code().to_string()),
        }
    }
}