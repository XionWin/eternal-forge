pub trait UserService {
    async fn query_user_by_id(
        &self,
        uuid: &Uuid,
    ) -> Result<User, DbError>;
}