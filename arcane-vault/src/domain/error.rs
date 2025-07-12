use deadpool_postgres::CreatePoolError;

#[derive(Debug)]
pub struct ArcaneVaultError {
    pub message: String,
    pub code: Option<String>,
}

impl std::fmt::Display for ArcaneVaultError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let code_message = match &self.code {
            Some(code) => format!("[error code: {}]", code),
            None => String::new(),
        };
        write!(f, "arcane-vault error: {} {}", self.message, code_message)
    }
}

impl std::error::Error for ArcaneVaultError {}

impl From<tokio_postgres::error::Error> for ArcaneVaultError {
    fn from(err: tokio_postgres::Error) -> Self {
        ArcaneVaultError {
            message: format!("{}", err),
            code: match err.code() {
                Some(code) => Some(format!("{:?}", code)),
                None => Some("tokio postgres error".into()),
            },
        }
    }
}

impl Into<tonic::Status> for ArcaneVaultError {
    fn into(self) -> tonic::Status {
        tonic::Status::new(tonic::Code::Internal, format!("{:?}", self))
    }
}

impl From<CreatePoolError> for ArcaneVaultError {
    fn from(error: CreatePoolError) -> Self {
        Self {
            message: error.to_string(),
            code: Some("create pool error".into()),
        }
    }
}

impl From<deadpool_postgres::PoolError> for ArcaneVaultError {
    fn from(error: deadpool_postgres::PoolError) -> Self {
        Self {
            message: error.to_string(),
            code: Some("deadpool postgres error".into()),
        }
    }
}
