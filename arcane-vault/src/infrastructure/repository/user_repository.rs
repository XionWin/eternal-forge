use lazy_static::lazy_static;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;
use tokio_postgres::Client;
use tokio_postgres::GenericClient;

use domain::{UserCreatingProfile, UserProfile};

use crate::accessor::DbError;
use crate::{model::QueryUserProfileType, sql};

lazy_static! {
    pub static ref QUERY_USER_PROFILE_MAPPING: HashMap<QueryUserProfileType, &'static str> = {
        let mut map = HashMap::new();
        map.insert(QueryUserProfileType::Id, sql::QUERY_USER_PROFILE_BY_ID);
        map.insert(
            QueryUserProfileType::OpenId,
            sql::QUERY_USER_PROFILE_BY_OPEN_ID,
        );
        map.insert(
            QueryUserProfileType::UnionId,
            sql::QUERY_USER_PROFILE_BY_UNION_ID,
        );
        map
    };
}

#[derive(Debug)]
pub struct UserRepository {
    client: Arc<Mutex<tokio_postgres::Client>>,
}

impl UserRepository {
    pub fn new(client: Arc<Mutex<tokio_postgres::Client>>) -> Self {
        Self { client }
    }

    pub async fn create_user_profile(
        &self,
        user_creating_profile: UserCreatingProfile,
    ) -> Result<UserProfile, DbError> {
        create_user_profile(&self.client.lock().await.client(), user_creating_profile).await
    }

    pub async fn query_user_profile(
        &self,
        query_user_profile_type: QueryUserProfileType,
        value: &(dyn tokio_postgres::types::ToSql + Sync),
    ) -> Result<UserProfile, DbError> {
        query_user_profile(
            &self.client.lock().await.client(),
            query_user_profile_type,
            value,
        )
        .await
    }
}

async fn create_user_profile(
    client: &Client,
    user_creating_profile: UserCreatingProfile,
) -> Result<UserProfile, DbError> {
    let stmt = client.prepare(sql::INSERT_USER_PROFILE).await?;

    let row = client
        .query_one(
            &stmt,
            &[
                &user_creating_profile.open_id,
                &user_creating_profile.union_id,
                &user_creating_profile.nick_name,
                &user_creating_profile.gender,
                &user_creating_profile.language,
                &user_creating_profile.city,
                &user_creating_profile.province,
                &user_creating_profile.country,
                &user_creating_profile.avatar_url,
                &user_creating_profile.signature,
                &user_creating_profile.raw_data,
                &user_creating_profile.encryption_data,
                &user_creating_profile.iv,
            ],
        )
        .await?;

    Ok(get_user_profile_from_row(&row))
}

async fn query_user_profile(
    client: &Client,
    query_user_profile_type: QueryUserProfileType,
    value: &(dyn tokio_postgres::types::ToSql + Sync),
) -> Result<UserProfile, DbError> {
    let row = client
        .query_one(
            QUERY_USER_PROFILE_MAPPING[&query_user_profile_type],
            &[value],
        )
        .await?;

    Ok(get_user_profile_from_row(&row))
}

fn get_user_profile_from_row(row: &tokio_postgres::Row) -> UserProfile {
    UserProfile {
        id: crate::util::get_string_from_uuid(row.get("id")),
        open_id: row.get("open_id"),
        union_id: row.get("union_id"),
        nick_name: row.get("nick_name"),
        gender: row.get("gender"),
        language: row.get("language"),
        city: row.get("city"),
        province: row.get("province"),
        country: row.get("country"),
        avatar_url: row.get("avatar_url"),
        signature: row.get("signature"),
        raw_data: row.get("raw_data"),
        encryption_data: row.get("encryption_data"),
        iv: row.get("iv"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
        status: row.get("status"),
        role: row.get("role"),
    }
}