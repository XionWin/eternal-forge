use ethereal_core::proto::{
    query_user_request::Identity, CreateUserRequest, CreateUserResponse, QueryUserRequest, QueryUserResponse, VerifyUserRequest, VerifyUserResponse
};
use uuid::Uuid;
pub struct UserService {
    valut_signup_service: Box<dyn arcane_vault::domain::service::UserService>,
}

impl UserService {
    pub async fn new() -> Self {
        Self {
            valut_signup_service: arcane_vault::UserService::new().await,
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
            Ok(verification_code) => Ok(tonic::Response::new(CreateUserResponse {
                verification_code,
            })),
            Err(err) => Err(err.into()),
        }
    }

    
    async fn verify_user(
        &self,
        request: tonic::Request<VerifyUserRequest>,
    ) -> std::result::Result<tonic::Response<VerifyUserResponse>, tonic::Status> {
        let request = request.into_inner();
        let email: String = request.email;
        let password: String = request.password;
        let verify_code: String = request.verify_code;

        let result = self
            .valut_signup_service
            .verify_user(
                &email, &password, &verify_code
            )
            .await;
        match result {
            Ok(user_id) => Ok(tonic::Response::new(VerifyUserResponse {
                user_id: user_id.to_string(),
            })),
            Err(err) => Err(err.into()),
        }
    }

    async fn query_user(
        &self,
        request: tonic::Request<QueryUserRequest>,
    ) -> std::result::Result<tonic::Response<QueryUserResponse>, tonic::Status> {
        let request = request.into_inner();
        match request.identity {
            Some(Identity::Id(id)) => match self
                .valut_signup_service
                .query_user_by_id(
                    Uuid::parse_str(&id).map_err(|err| tonic::Status::from_error(err.into()))?,
                )
                .await
            {
                Ok(user) => Ok(tonic::Response::new(QueryUserResponse { user })),
                Err(err) => Err(err.into()),
            },
            Some(Identity::Email(email)) => match self
                .valut_signup_service
                .query_user_by_email_account(&email)
                .await
            {
                Ok(user) => Ok(tonic::Response::new(QueryUserResponse { user })),
                Err(err) => Err(err.into()),
            },
            None => Ok(tonic::Response::new(QueryUserResponse { user: None })),
        }
    }
}
