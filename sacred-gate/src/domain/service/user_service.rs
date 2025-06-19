use ethereal_core::proto::{GetUserByIdRequest, User};

pub struct UserService {
    valut_user_service: Box<dyn arcane_vault::domain::service::UserService>,
}

/// Generated trait containing gRPC methods that should be implemented for use with UserServiceServer.
#[tonic::async_trait]
impl ethereal_core::proto::user_service_server::UserService for UserService {
    async fn get_user_by_id(
        &self,
        request: tonic::Request<GetUserByIdRequest>,
    ) -> std::result::Result<tonic::Response<User>, tonic::Status> {
        let uuid = "550e8400-e29b-41d4-a716-446655440000"
            .parse::<uuid::Uuid>()
            .ok()
            .unwrap();
        let result = self.valut_user_service.query_user_by_id(&uuid).await;
        match result {
            Ok(user) => Ok(tonic::Response::new(user)),
            Err(err) => Err(tonic::Status::new(
                tonic::Code::Internal,
                format!("get user failed, error: {:?}", err),
            )),
        }
    }
}
