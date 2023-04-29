use discovery::Lang;
use include_dir::{include_dir, Dir};
use tree_sitter::{Language, Query};

use super::{Element, Error};

static PROJECT_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR");

extern "C" {
    fn tree_sitter_go() -> Language;
}

/// This parser can parse any Go files.
pub struct GoParser {
    container: super::Container,
    query: Query,
}

impl GoParser {
    pub fn new(c: super::Container) -> Result<Self, Error> {
        let queries = PROJECT_DIR
            .get_file("src/parser/queries/go.scm")
            .ok_or(Error::FileNotFound("go.scm not found".to_owned()))?;
        let query = queries
            .contents_utf8()
            .ok_or(Error::ParseFile("Can't parse queries".to_owned()))?;
        let language = unsafe { tree_sitter_go() };
        let query = Query::new(language, query)?;

        Ok(GoParser {
            container: c,
            query,
        })
    }
}

impl super::Parser for GoParser {
    fn container(&mut self) -> &mut super::Container {
        &mut self.container
    }

    fn ro_container(&self) -> &super::Container {
        &self.container
    }

    fn supported(&self, f: &discovery::File) -> bool {
        f.lang == Lang::Go
    }

    fn language(&self) -> Language {
        unsafe { tree_sitter_go() }
    }

    fn query(&self) -> &Query {
        &self.query
    }

    fn func_repr(&self, v: Vec<Element>) -> (Vec<Element>, usize) {
        // When the index is zero, it is the method receiver. We should keep the value until the
        // next element to concatinate.
        let mut prev: Option<String> = None;
        let mut redacted = 0usize;
        let res: Vec<Element> = v
            .into_iter()
            .filter_map(|mut e| {
                if e.index == 0 {
                    prev = Some(e.name);
                    redacted += 1;
                    return None;
                } else if let Some(p) = prev.as_ref() {
                    // Removing anything up to the first space, and prepend '(' to make the method
                    // look right.
                    let name = p.split(' ').nth(1).unwrap_or(&p[1..]);
                    let name = format!("({} {}", name, e.name);
                    prev = None;
                    e.name = name;
                }
                Some(e)
            })
            .collect();
        (res, redacted)
    }
}

#[cfg(test)]
mod find_functions {
    use std::error;

    use indicatif::ProgressBar as pb;
    use itertools::assert_equal;
    use speculoos::prelude::*;

    use super::super::Container;
    use super::*;
    use crate::parser::{Element, Parser};
    use discovery::File;
    const FIXTURES: &str = "src/parser/fixtures/go";

    #[test]
    fn no_file_added() -> Result<(), Box<dyn error::Error>> {
        let mut p = GoParser::new(Container::new(100))?;
        let res = p.find_functions(&pb::hidden());
        assert_that!(res).is_err();
        Ok(())
    }

    #[test]
    fn no_go_file() -> Result<(), Box<dyn error::Error>> {
        let some_types = vec![Lang::Undefined, Lang::Rust, Lang::Lua];
        for t in some_types {
            let mut p = GoParser::new(Container::new(100))?;
            let f = File {
                path: format!("{FIXTURES}/no_function.1.go"),
                lang: t,
            };
            let res = p.add_file(f);
            assert_that!(res).is_err();
        }
        Ok(())
    }

    #[test]
    fn no_function_in_file() -> Result<(), Box<dyn error::Error>> {
        let mut p = GoParser::new(Container::new(100))?;
        let f = File {
            path: format!("{FIXTURES}/no_function.1.go"),
            lang: Lang::Go,
        };
        p.add_file(f)?;
        let res = p.find_functions(&pb::hidden());
        assert_that!(res).is_ok();
        assert_that!(res.unwrap()).is_empty();
        Ok(())
    }

    #[test]
    fn returns_one_function_found() -> Result<(), Box<dyn error::Error>> {
        let mut p = GoParser::new(Container::new(100))?;
        let path = format!("{FIXTURES}/one_function.1.go");
        let f = File {
            path: path.clone(),
            lang: Lang::Go,
        };
        p.add_file(f)?;
        let res = p.find_functions(&pb::hidden());
        assert_that!(res).is_ok();

        let res = res.unwrap();
        assert_that!(res).has_length(1);
        let element = res.get(0).unwrap();
        let want = Element {
            name: "FuncOne".to_owned(),
            line: 3,
            file: path,
            index: 1,
        };
        assert_that!(element).is_equal_to(&want);
        Ok(())
    }

    #[test]
    fn can_identify_methods() -> Result<(), Box<dyn error::Error>> {
        let mut p = GoParser::new(Container::new(100))?;
        let path = format!("{FIXTURES}/method.1.go");
        let f = File {
            path: path.clone(),
            lang: Lang::Go,
        };
        p.add_file(f)?;
        let res = p.find_functions(&pb::hidden());
        assert_that!(res).is_ok();

        let mut res = res.unwrap();
        let mut want = vec![
            Element {
                name: "(x) FuncOne".to_owned(),
                line: 5,
                file: path.clone(),
                index: 1,
            },
            Element {
                name: "(*x) FuncTwo".to_owned(),
                line: 6,
                file: path.clone(),
                index: 1,
            },
            Element {
                name: "nested".to_owned(),
                line: 7,
                file: path.clone(),
                index: 1,
            },
            Element {
                name: "(*x) FuncThree".to_owned(),
                line: 10,
                file: path,
                index: 1,
            },
        ];
        want.sort_by(|a, b| a.line.cmp(&b.line));
        res.sort_by(|a, b| a.line.cmp(&b.line));

        assert_equal(want, res);
        Ok(())
    }

    #[test]
    fn returns_all_functions_in_files() -> Result<(), Box<dyn error::Error>> {
        let mut p = GoParser::new(Container::new(100))?;
        let path = format!("{FIXTURES}/multi_functions.1.go");
        let f = File {
            path: path.clone(),
            lang: Lang::Go,
        };
        p.add_file(f)?;
        let res = p.find_functions(&pb::hidden());
        assert_that!(res).is_ok();

        let mut res = res.unwrap();
        let mut want = vec![
            Element {
                name: "FuncTwo".to_owned(),
                line: 3,
                file: path.clone(),
                index: 1,
            },
            Element {
                name: "FuncThree".to_owned(),
                line: 5,
                file: path.clone(),
                index: 1,
            },
            Element {
                name: "nested".to_owned(),
                line: 6,
                file: path,
                index: 1,
            },
        ];
        want.sort_by(|a, b| a.name.cmp(&b.name));
        res.sort_by(|a, b| a.name.cmp(&b.name));

        assert_equal(want, res);
        Ok(())
    }

    #[test]
    fn handles_multiple_files() -> Result<(), Box<dyn error::Error>> {
        let mut p = GoParser::new(Container::new(100))?;
        let path1 = format!("{FIXTURES}/multi_functions.1.go");
        let path2 = format!("{FIXTURES}/one_function.1.go");
        let f1 = File {
            path: path1.clone(),
            lang: Lang::Go,
        };
        let f2 = File {
            path: path2.clone(),
            lang: Lang::Go,
        };
        p.add_file(f1)?;
        p.add_file(f2)?;
        let res = p.find_functions(&pb::hidden());
        assert_that!(res).is_ok();

        let mut res = res.unwrap();
        let mut want = vec![
            Element {
                name: "FuncOne".to_owned(),
                line: 3,
                file: path2,
                index: 1,
            },
            Element {
                name: "FuncTwo".to_owned(),
                line: 3,
                file: path1.clone(),
                index: 1,
            },
            Element {
                name: "FuncThree".to_owned(),
                line: 5,
                file: path1.clone(),
                index: 1,
            },
            Element {
                name: "nested".to_owned(),
                line: 6,
                file: path1,
                index: 1,
            },
        ];
        want.sort_by(|a, b| a.name.cmp(&b.name));
        res.sort_by(|a, b| a.name.cmp(&b.name));

        assert_equal(want, res);
        Ok(())
    }
}
