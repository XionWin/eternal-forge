use ethereal_core::proto::{CreateUserRequest, CreateUserResponse, QueryUserRequest, QueryUserResponse};

pub struct UserService {
    valut_signup_service: Box<dyn arcane_vault::domain::service::UserService>,
}

impl UserService {
    pub async fn new() -> Self {
        let valut_signup_service = arcane_vault::UserService::new().await;
        Self {
            valut_signup_service,
        }
    }
}

/// Generated trait containing gRPC methods that should be implemented for use with UserServiceServer.
#[tonic::async_trait]
impl ethereal_core::proto::user_service_server::UserService for UserService {
    async fn create_user(
        &self,
        request: tonic::Request<CreateUserRequest>,
    ) -> std::result::Result<tonic::Response<CreateUserResponse>, tonic::Status> {
        let request = request.into_inner();
        let email: String = request.email;
        let password: String = request.password;
        let firstname: String = request.firstname;
        let lastname: String = request.lastname;
        let gender: i32 = request.gender;
        let locale: i32 = request.locale;
        let avatar: String = request.avatar;
        let signature: String = request.signature;

        let result = self
            .valut_signup_service
            .create_user(
                &email, &password, &firstname, &lastname, gender, locale, &avatar, &signature,
            )
            .await;
        match result {
            Ok(user_id) => Ok(tonic::Response::new(CreateUserResponse {
                id: user_id.to_string(),
            })),
            Err(err) => Err(err.into()),
        }
    }
    
    async fn query_user(
        &self,
        _request: tonic::Request<QueryUserRequest>,
    ) -> std::result::Result<tonic::Response<QueryUserResponse>, tonic::Status> {
        todo!()
    }

}
