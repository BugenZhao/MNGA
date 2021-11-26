use std::{
    collections::HashMap,
    fs::{self, File},
    io::Write,
    path::Path,
};

use anyhow::Result;
use protos::{MockRequest, MockResponse};

#[derive(Default)]
pub struct Renderer {
    files: HashMap<String, Vec<u8>>,
}

impl Renderer {
    pub fn new() -> Self {
        Default::default()
    }

    pub fn render<Req, Res>(&mut self, request: &Req, response: &Res) -> Result<()>
    where
        Req: MockRequest,
        Res: MockResponse,
    {
        let name = request.to_encoded_mock_api();
        let content = response.write_to_bytes()?.to_vec();
        self.files.insert(name, content);
        Ok(())
    }

    pub fn write_to_dir(self, dir: impl AsRef<Path>) -> Result<()> {
        fs::create_dir_all(dir.as_ref())?;

        for (name, content) in self.files.into_iter() {
            let mut path = dir.as_ref().to_path_buf();
            path.push(name);
            let mut file = File::create(path)?;
            file.write_all(&content)?;
        }

        Ok(())
    }
}

pub trait Render {
    fn render(&self, renderer: &mut Renderer) -> Result<()>;
}
