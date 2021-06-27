use crate::protos::DataModel::User;
use dashmap::DashMap;
use lazy_static::lazy_static;

lazy_static! {
    static ref USER_CONTROLLER: UserController = Default::default();
}

#[derive(Default)]
pub struct UserController {
    map: DashMap<String, User>,
}

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
