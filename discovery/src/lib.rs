use std::{path::Path, result};
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

pub fn discover<P: AsRef<Path>>(path: P) -> Option<Vec<File>> {
    let res: Vec<File> = WalkDir::new(path)
        .into_iter()
        .filter_map(result::Result::ok)
        .filter(is_project_file)
        .filter_map(|p| {
            let lang = match detect_lang::from_path(p.path()) {
                Some(lang) => lang.id().into(),
                None => Lang::Undefined,
            };
            let path = p.path().file_name().and_then(|p| p.to_str());

            let path = match path {
                Some(p) => p.to_owned(),
                None => return None,
            };

            Some(File { path, lang })
        })
        .collect();

    if res.is_empty() {
        None
    } else {
        Some(res)
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
            let path = value
                .0
                .path()
                .join(value.1)
                .file_name()
                .and_then(|p| p.to_str())
                .unwrap()
                .to_owned();
            File {
                path,
                lang: value.2,
            }
        }
    }

    #[test]
    fn empty_path() -> Result<(), Box<dyn error::Error>> {
        let td = TempDir::new()?;
        assert_that(&discover(td.path())).is_none();
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

        let res = discover(td.path());
        assert_that(&res).is_some();

        let mut res = res.unwrap();
        res.sort_by(|a, b| a.path.cmp(&b.path));
        assert_that(&res).is_equal_to(&want);
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

        let mut res = discover(td.path()).unwrap();
        res.sort_by(|a, b| a.path.cmp(&b.path));
        assert_that(&res).is_equal_to(&want);
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

        let mut res = discover(td.path()).unwrap();
        res.sort_by(|a, b| a.path.cmp(&b.path));
        assert_that(&res).is_equal_to(&want);
        Ok(())
    }
}
