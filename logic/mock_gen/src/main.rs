mod model;
mod render;
mod utils;

use std::{env, fs::read_to_string, process::exit};

use anyhow::Result;

use crate::{
    model::*,
    render::{Render, Renderer},
};

fn main() -> Result<()> {
    let args = env::args().collect::<Vec<_>>();
    if args.len() < 3 {
        println!(
            "usage: {} <forum-yaml> <api-dir>",
            args.first().cloned().unwrap_or_default()
        );
        exit(1);
    }

    let source = read_to_string(&args[1])?;
    let forum: MockForum = serde_yaml::from_str(&source)?;

    let mut renderer = Renderer::new();
    forum.render(&mut renderer)?;
    renderer.write_to_dir(&args[2])?;

    Ok(())
}

#[cfg(test)]
mod test {
    use crate::utils::get_unique_id;

    use super::*;

    #[test]
    fn test_serde() {
        let source = include_str!("../examples/mock.yaml");
        let actual: MockForum = serde_yaml::from_str(source).unwrap();
        let actual_yaml = serde_yaml::to_string(&actual).unwrap();

        let expected = MockForum {
            id: get_unique_id(),
            name: "MNGA".to_owned(),
            topics: vec![MockTopic {
                id: get_unique_id(),
                subject: "[FAQ] MNGA 常见问题".to_owned(),
                posts: vec![MockPost {
                    id: get_unique_id(),
                    content: "First line here.\nSecond line here\n".to_owned(),
                    author: "Bugen from MNGA".to_owned(),
                }],
            }],
        };
        let expected_yaml = serde_yaml::to_string(&expected).unwrap();

        println!("expected:\n{}", expected_yaml);

        assert_eq!(actual_yaml, expected_yaml);
    }
}
