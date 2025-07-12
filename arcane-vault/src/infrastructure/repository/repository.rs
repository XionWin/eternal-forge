use std::time::Duration;
use deadpool_postgres::Pool;
use tokio::time::sleep;
use crate::domain::error::ArcaneVaultError;

const MAX_RETRIES: u32 = 3;
const BASE_DELAY_MS: u64 = 100;
const MAX_DELAY_MS: u64 = 1000;

#[derive(Debug)]
pub struct Repository {
    pool: Pool,
}

impl Repository {
    pub fn new(pool: Pool) -> Self {
        Self { pool }
    }

    pub async fn query_one<T>(
        &self,
        statement: &str,
        params: &[&(dyn tokio_postgres::types::ToSql + Sync)],
        get_instance_func: fn(&tokio_postgres::row::Row) -> T
    ) -> Result<T, ArcaneVaultError> {
        self.with_retry(|client| async move {
            let row = client
                .query_one(statement, params)
                .await
                .map_err(ArcaneVaultError::from)?;
            Ok(get_instance_func(&row))
        })
        .await
    }

    async fn with_retry<F, Fut, T>(&self, f: F) -> Result<T, ArcaneVaultError>
    where
        F: Fn(deadpool_postgres::Client) -> Fut,
        Fut: std::future::Future<Output = Result<T, ArcaneVaultError>>,
    {
        let mut attempts = 0;
        let mut last_error = None;

        while attempts < MAX_RETRIES {
            attempts += 1;
            
            match self.pool.get().await {
                Ok(client) => {
                    match f(client).await {
                        Ok(result) => return Ok(result),
                        Err(e) => {
                            last_error = Some(e);
                            if attempts < MAX_RETRIES {
                                let delay = (BASE_DELAY_MS * (1 << (attempts - 1))).min(MAX_DELAY_MS);
                                sleep(Duration::from_millis(delay)).await;
                                continue;
                            }
                        }
                    }
                }
                Err(e) => {
                    last_error = Some(e.into());
                    if attempts < MAX_RETRIES {
                        let delay = (BASE_DELAY_MS * (1 << (attempts - 1))).min(MAX_DELAY_MS);
                        sleep(Duration::from_millis(delay)).await;
                        continue;
                    }
                }
            }
        }

        Err(last_error.unwrap_or_else(|| ArcaneVaultError {
            message: format!("Failed after {} attempts", MAX_RETRIES),
            code: None
        }
        ))
    }
}