use deadpool_postgres::CreatePoolError;
use tokio_postgres::error::SqlState;

#[derive(Debug, PartialEq)]
pub enum ArcaneVaultErrorCode {
    NoData,
    InnerError(String),
}

#[derive(Debug)]
pub struct ArcaneVaultError {
    pub message: String,
    pub code: Option<ArcaneVaultErrorCode>,
}

impl std::fmt::Display for ArcaneVaultError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "arcane-vault error: {} {:?}", self.message, self.code)
    }
}

impl std::error::Error for ArcaneVaultError {}

impl From<tokio_postgres::error::Error> for ArcaneVaultError {
    fn from(err: tokio_postgres::Error) -> Self {
        ArcaneVaultError {
            message: format!("{}", err),
            code: match err.code() {
                Some(code) if code == &SqlState::NO_DATA => Some(ArcaneVaultErrorCode::NoData),
                Some(code) => Some(ArcaneVaultErrorCode::InnerError(format!("{:?}", code))),
                None => Some(ArcaneVaultErrorCode::InnerError("tokio postgres error".into())),
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
            code: Some(ArcaneVaultErrorCode::InnerError("create pool error".into())),
        }
    }
}

impl From<deadpool_postgres::PoolError> for ArcaneVaultError {
    fn from(error: deadpool_postgres::PoolError) -> Self {
        Self {
            message: error.to_string(),
            code: Some(ArcaneVaultErrorCode::InnerError("deadpool postgres error".into())),
        }
    }
}
