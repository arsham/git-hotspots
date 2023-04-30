use std::error;

use speculoos::prelude::*;
use tempfile::TempDir;

use super::*;
use hotspots_utilities::create_files;

impl From<(&TempDir, &str, Lang)> for File {
    fn from(value: (&TempDir, &str, Lang)) -> Self {
        let path = value.0.path().join(value.1).to_str().unwrap().to_owned();
        File {
            path,
            lang: value.2,
        }
    }
}

type DynError = Box<dyn error::Error>;

#[test]
fn empty_path() -> Result<(), DynError> {
    let td = TempDir::new()?;
    let d = Discovery::default();
    assert_that!(d.discover(td.path())).is_none();
    Ok(())
}

#[test]
fn ignores_hidden_files() -> Result<(), DynError> {
    let td = TempDir::new()?;
    let files = vec!["a.txt", "b.txt", ".nope.txt"];
    create_files(&td, files)?;
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
fn discovers_recursively() -> Result<(), DynError> {
    let td = TempDir::new()?;
    let b = Path::new("b").join("c.txt");
    let files = vec!["a.txt", b.to_str().unwrap()];
    create_files(&td, files)?;
    let f1 = (&td, "a.txt", Lang::Undefined).into();
    let f2 = (&td, b.to_str().unwrap(), Lang::Undefined).into();
    let want = vec![f1, f2];

    let d = Discovery::default();
    let mut res = d.discover(td.path()).unwrap();
    res.sort_by(|a, b| a.path.cmp(&b.path));
    assert_that!(res).is_equal_to(&want);
    Ok(())
}

#[test]
fn discovers_language() -> Result<(), DynError> {
    let td = TempDir::new()?;
    let files = vec!["file1.go", "file2.rs", "file3.lua"];
    create_files(&td, files)?;
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
