use std::error;

use indicatif::ProgressBar as pb;
use itertools::assert_equal;
use speculoos::prelude::*;

use super::super::Container;
use super::*;
use crate::parser::{Element, Parser};
use discovery::File;
const FIXTURES: &str = "src/parser/fixtures/rust";

#[test]
fn no_file_added() -> Result<(), Box<dyn error::Error>> {
    let mut p = RustParser::new(Container::new(100))?;
    let res = p.find_functions(&pb::hidden());
    assert_that!(res).is_err();
    Ok(())
}

#[test]
fn no_rust_file() -> Result<(), Box<dyn error::Error>> {
    let some_types = vec![Lang::Undefined, Lang::Go, Lang::Lua];
    for t in some_types {
        let mut p = RustParser::new(Container::new(100))?;
        let f = File {
            path: format!("{FIXTURES}/no_function.rs"),
            lang: t,
        };
        let res = p.add_file(f);
        assert_that!(res).is_err();
    }
    Ok(())
}

#[test]
fn no_function_in_file() -> Result<(), Box<dyn error::Error>> {
    let mut p = RustParser::new(Container::new(100))?;
    let f = File {
        path: format!("{FIXTURES}/no_function.rs"),
        lang: Lang::Rust,
    };
    p.add_file(f)?;
    let res = p.find_functions(&pb::hidden());
    assert_that!(res).is_ok();
    assert_that!(res.unwrap()).is_empty();
    Ok(())
}

#[test]
fn returns_one_function_found() -> Result<(), Box<dyn error::Error>> {
    let mut p = RustParser::new(Container::new(100))?;
    let path = format!("{FIXTURES}/one_function.rs");
    let f = File {
        path: path.clone(),
        lang: Lang::Rust,
    };
    p.add_file(f)?;
    let res = p.find_functions(&pb::hidden());
    assert_that!(res).is_ok();

    let res = res.unwrap();
    assert_that!(res).has_length(1);
    let element = res.get(0).unwrap();
    let want = Element {
        name: "func_one".to_owned(),
        line: 1,
        file: path,
        index: 0,
    };
    assert_that!(element).is_equal_to(&want);
    Ok(())
}

#[test]
fn can_identify_methods() -> Result<(), Box<dyn error::Error>> {
    let mut p = RustParser::new(Container::new(100))?;
    let path = format!("{FIXTURES}/method.rs");
    let f = File {
        path: path.clone(),
        lang: Lang::Rust,
    };
    p.add_file(f)?;
    let res = p.find_functions(&pb::hidden());
    assert_that!(res).is_ok();

    let mut res = res.unwrap();
    let mut want = vec![
        Element {
            name: "func_one".to_owned(),
            line: 4,
            file: path.clone(),
            index: 0,
        },
        Element {
            name: "func_two".to_owned(),
            line: 5,
            file: path.clone(),
            index: 0,
        },
        Element {
            name: "nested".to_owned(),
            line: 6,
            file: path.clone(),
            index: 0,
        },
        Element {
            name: "func_three".to_owned(),
            line: 8,
            file: path,
            index: 0,
        },
    ];
    want.sort_by(|a, b| a.line.cmp(&b.line));
    res.sort_by(|a, b| a.line.cmp(&b.line));

    assert_equal(want, res);
    Ok(())
}

#[test]
fn returns_all_functions_in_files() -> Result<(), Box<dyn error::Error>> {
    let mut p = RustParser::new(Container::new(100))?;
    let path = format!("{FIXTURES}/multi_functions.rs");
    let f = File {
        path: path.clone(),
        lang: Lang::Rust,
    };
    p.add_file(f)?;
    let res = p.find_functions(&pb::hidden());
    assert_that!(res).is_ok();

    let mut res = res.unwrap();
    let mut want = vec![
        Element {
            name: "func_two".to_owned(),
            line: 1,
            file: path.clone(),
            index: 0,
        },
        Element {
            name: "func_three".to_owned(),
            line: 3,
            file: path.clone(),
            index: 0,
        },
        Element {
            name: "nested".to_owned(),
            line: 4,
            file: path,
            index: 0,
        },
    ];
    want.sort_by(|a, b| a.name.cmp(&b.name));
    res.sort_by(|a, b| a.name.cmp(&b.name));

    assert_equal(want, res);
    Ok(())
}

#[test]
fn handles_multiple_files() -> Result<(), Box<dyn error::Error>> {
    let mut p = RustParser::new(Container::new(100))?;
    let path1 = format!("{FIXTURES}/multi_functions.rs");
    let path2 = format!("{FIXTURES}/one_function.rs");
    let f1 = File {
        path: path1.clone(),
        lang: Lang::Rust,
    };
    let f2 = File {
        path: path2.clone(),
        lang: Lang::Rust,
    };
    p.add_file(f1)?;
    p.add_file(f2)?;
    let res = p.find_functions(&pb::hidden());
    assert_that!(res).is_ok();

    let mut res = res.unwrap();
    let mut want = vec![
        Element {
            name: "func_one".to_owned(),
            line: 1,
            file: path2,
            index: 0,
        },
        Element {
            name: "func_two".to_owned(),
            line: 1,
            file: path1.clone(),
            index: 0,
        },
        Element {
            name: "func_three".to_owned(),
            line: 3,
            file: path1.clone(),
            index: 0,
        },
        Element {
            name: "nested".to_owned(),
            line: 4,
            file: path1,
            index: 0,
        },
    ];
    want.sort_by(|a, b| a.name.cmp(&b.name));
    res.sort_by(|a, b| a.name.cmp(&b.name));

    assert_equal(want, res);
    Ok(())
}
