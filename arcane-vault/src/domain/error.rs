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

impl From<tokio_postgres::Error> for ArcaneVaultError {
    fn from(err: tokio_postgres::Error) -> Self {
        ArcaneVaultError {
            message: format!("{}", err),
            code: match err.code() {
                Some(code) => Some(format!("{:?}", code)),
                None => None,
            }
        }
    }
}
