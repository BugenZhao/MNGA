use crate::{
    error::LogicResult,
    protos::{
        DataModel::User,
        Service::{RemoteUserRequest, RemoteUserResponse, RemoteUserResponse_oneof__user},
    },
    service::{
        fetch_package,
        utils::{extract_kv, extract_node},
    },
};
use dashmap::DashMap;
use lazy_static::lazy_static;
use sxd_xpath::nodeset::Node;

lazy_static! {
    static ref USER_CONTROLLER: UserController = Default::default();
}

#[derive(Default)]
pub struct UserController {
    map: DashMap<String, User>,
}

#[allow(dead_code)]
impl UserController {
    pub fn get<'a>() -> &'a Self {
        &USER_CONTROLLER
    }

    pub fn update_user(&self, user: User) {
        self.map.insert(user.id.to_owned(), user);
    }

    pub fn update_users(&self, users: Vec<User>) {
        users.into_iter().for_each(|u| self.update_user(u));
    }
}

impl std::ops::Deref for UserController {
    type Target = DashMap<String, User>;

    fn deref(&self) -> &Self::Target {
        &self.map
    }
}

pub fn extract_user_and_cache(node: Node) -> Option<User> {
    use super::macros::get;
    let map = extract_kv(node);

    let user = User {
        id: get!(map, "uid")?,
        name: get!(map, "username")?,
        avatar_url: get!(map, "avatar")?,
        reg_date: get!(map, "regdate", _)?,
        post_num: get!(map, "postnum", _).or(get!(map, "posts", _))?,
        ..Default::default()
    };

    UserController::get().update_user(user.clone());

    Some(user)
}

pub async fn get_remote_user(request: RemoteUserRequest) -> LogicResult<RemoteUserResponse> {
    let user_id = request.user_id;
    if let Some(user) = UserController::get().get(&user_id) {
        return Ok(RemoteUserResponse {
            _user: Some(RemoteUserResponse_oneof__user::user(user.to_owned())),
            ..Default::default()
        });
    }

    let package = fetch_package(
        "nuke.php",
        vec![("__lib", "ucp"), ("__act", "get"), ("uid", &user_id)],
        vec![],
    )
    .await?;

    let user = extract_node(&package, "/root/data/item", extract_user_and_cache)?.flatten();

    Ok(RemoteUserResponse {
        _user: user.map(|u| RemoteUserResponse_oneof__user::user(u)),
        ..Default::default()
    })
}

#[cfg(test)]
mod test {
    use super::*;

    #[tokio::test]
    async fn test_remote_user() -> LogicResult<()> {
        let response = get_remote_user(RemoteUserRequest {
            user_id: "41417929".to_owned(),
            ..Default::default()
        })
        .await?;

        println!("response: {:?}", response);

        assert!(response.has_user());

        Ok(())
    }
}
