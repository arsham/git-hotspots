use log::debug;
use rayon::prelude::*;
use std::{ops::Not, path::Path, result, time::Instant};
use walkdir::{DirEntry, WalkDir};

#[derive(Debug, Eq, PartialEq)]
pub enum Lang {
    Rust,
    Go,
    Lua,
    Undefined,
}

impl From<&str> for Lang {
    fn from(value: &str) -> Self {
        match value {
            "go" => Lang::Go,
            "rust" => Lang::Rust,
            "lua" => Lang::Lua,
            _ => Lang::Undefined,
        }
    }
}

#[derive(Debug, Eq, PartialEq)]
pub struct File {
    pub path: String,
    pub lang: Lang,
}

#[derive(Default)]
pub struct Discovery {
    prefixes: Vec<String>,
    not_contains: Vec<String>,
}

impl Discovery {
    pub fn with_prefix(&mut self, p: String) {
        self.prefixes.push(p);
    }
    pub fn not_contains(&mut self, p: String) {
        self.not_contains.push(p);
    }
    pub fn discover<P: AsRef<Path>>(&self, path: P) -> Option<Vec<File>> {
        let start = Instant::now();
        let res: Vec<File> = WalkDir::new(&path)
            .into_iter()
            .par_bridge()
            .filter_map(result::Result::ok)
            .filter(|p| {
                if self.prefixes.is_empty() {
                    true
                } else {
                    self.prefixes
                        .iter()
                        .any(|prefix| p.path().starts_with(prefix))
                }
            })
            .filter(|p| {
                if self.not_contains.is_empty() {
                    true
                } else {
                    self.not_contains
                        .iter()
                        .any(|prefix| p.path().to_str().unwrap_or("").contains(prefix))
                        .not()
                }
            })
            .filter(is_project_file)
            .filter_map(|p| {
                let lang = match detect_lang::from_path(p.path()) {
                    Some(lang) => lang.id().into(),
                    None => Lang::Undefined,
                };
                let p = p.path().to_str();

                p.map(|path| File {
                    path: path.to_owned(),
                    lang,
                })
            })
            .collect();

        debug!("Discovery took {:?}", start.elapsed());

        if res.is_empty() {
            None
        } else {
            Some(res)
        }
    }
}

fn is_project_file(entry: &DirEntry) -> bool {
    if entry.file_type().is_dir() {
        return false;
    }
    entry
        .file_name()
        .to_str()
        .map(|s| !s.starts_with('.'))
        .unwrap_or(false)
}

#[cfg(test)]
mod discover_test {
    use std::error;

    use speculoos::prelude::*;
    use tempfile::TempDir;

    use super::*;

    impl From<(&TempDir, &str, Lang)> for File {
        fn from(value: (&TempDir, &str, Lang)) -> Self {
            let path = value.0.path().join(value.1).to_str().unwrap().to_owned();
            File {
                path,
                lang: value.2,
            }
        }
    }

    #[test]
    fn empty_path() -> Result<(), Box<dyn error::Error>> {
        let td = TempDir::new()?;
        let d = Discovery::default();
        assert_that!(d.discover(td.path())).is_none();
        Ok(())
    }

    #[test]
    fn ignores_hidden_files() -> Result<(), Box<dyn error::Error>> {
        let td = TempDir::new()?;
        let files = vec!["a.txt", "b.txt", ".nope.txt"];
        utilities::create_files(&td, files)?;
        let f1 = (&td, "a.txt", Lang::Undefined).into();
        let f2 = (&td, "b.txt", Lang::Undefined).into();
        let want = vec![f1, f2];

        let d = Discovery::default();
        let res = d.discover(td.path());
        assert_that!(res).is_some();

        let mut res = res.unwrap();
        res.sort_by(|a, b| a.path.cmp(&b.path));
        assert_that!(res).is_equal_to(&want);
        Ok(())
    }

    #[test]
    fn discovers_recursively() -> Result<(), Box<dyn error::Error>> {
        let td = TempDir::new()?;
        let files = vec!["a.txt", "b/c.txt"];
        utilities::create_files(&td, files)?;
        let f1 = (&td, "a.txt", Lang::Undefined).into();
        let f2 = (&td, "b/c.txt", Lang::Undefined).into();
        let want = vec![f1, f2];

        let d = Discovery::default();
        let mut res = d.discover(td.path()).unwrap();
        res.sort_by(|a, b| a.path.cmp(&b.path));
        assert_that!(res).is_equal_to(&want);
        Ok(())
    }

    #[test]
    fn discovers_language() -> Result<(), Box<dyn error::Error>> {
        let td = TempDir::new()?;
        let files = vec!["file1.go", "file2.rs", "file3.lua"];
        utilities::create_files(&td, files)?;
        let f1 = (&td, "file1.go", Lang::Go).into();
        let f2 = (&td, "file2.rs", Lang::Rust).into();
        let f3 = (&td, "file3.lua", Lang::Lua).into();

        let want = vec![f1, f2, f3];

        let d = Discovery::default();
        let mut res = d.discover(td.path()).unwrap();
        res.sort_by(|a, b| a.path.cmp(&b.path));
        assert_that!(res).is_equal_to(&want);
        Ok(())
    }
}
