use ethereal_core::proto::{GetUserByIdRequest, User};

pub struct UserService {
    valut_user_service: Box<dyn arcane_vault::domain::service::UserService>,
}

impl UserService {
    pub async fn new() -> Self {
        let valut_user_service = arcane_vault::UserServiceApp::new().await;
        Self { valut_user_service }
    }
}

/// Generated trait containing gRPC methods that should be implemented for use with UserServiceServer.
#[tonic::async_trait]
impl ethereal_core::proto::user_service_server::UserService for UserService {
    async fn get_user_by_id(
        &self,
        request: tonic::Request<GetUserByIdRequest>,
    ) -> std::result::Result<tonic::Response<User>, tonic::Status> {
        let request_id = request.into_inner().id;
        match request_id.parse::<uuid::Uuid>() {
            Ok(uuid) => {
                let result = self.valut_user_service.query_user_by_id(&uuid).await;
                match result {
                    Ok(user) => Ok(tonic::Response::new(user)),
                    Err(err) => Err(err.into()),
                }
            }
            Err(err) => Err(tonic::Status::new(
                tonic::Code::Internal,
                format!("id is not a validated uuid, error: {:?}", err),
            )),
        }
    }
}
