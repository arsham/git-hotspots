use discovery::{File, Lang};
use include_dir::{include_dir, Dir};
use tree_sitter::Language as TSLanguage;
use tree_sitter::Parser as TSParser;
use tree_sitter::Query;

use super::Error;
use super::Predicate;

static PROJECT_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR");

extern "C" {
    fn tree_sitter_go() -> TSLanguage;
}

/// This parser can parse any Go files.
pub struct GoParser {
    files: Vec<File>,
    query: Query,
    filters: Vec<Predicate>,
}

impl Default for GoParser {
    fn default() -> Self {
        Self::new().unwrap()
    }
}

impl GoParser {
    pub fn new() -> Result<Self, Error> {
        let queries = PROJECT_DIR
            .get_file("src/parser/queries/go.scm")
            .ok_or(Error::FileNotFound("go.scm not found".to_owned()))?;
        let query = queries
            .contents_utf8()
            .ok_or(Error::ParseFile("Can't parse queries".to_owned()))?;
        let language = unsafe { tree_sitter_go() };
        let query = Query::new(language, query)?;

        Ok(GoParser {
            files: vec![],
            query,
            filters: Vec::new(),
        })
    }
}

impl super::Parser for GoParser {
    fn add_file(&mut self, f: File) -> Result<(), Error> {
        if f.lang != Lang::Go {
            return Err(Error::NotCompatible);
        }
        self.files.push(f);
        Ok(())
    }

    fn parser(&self) -> Result<TSParser, Error> {
        let language = unsafe { tree_sitter_go() };
        let mut parser = TSParser::new();
        parser.set_language(language)?;
        Ok(parser)
    }

    fn query(&self) -> &Query {
        &self.query
    }

    fn files(&self) -> Result<&[File], Error> {
        if self.files.is_empty() {
            Err(Error::NoFilesAdded)
        } else {
            Ok(&self.files)
        }
    }

    fn filter_path(&mut self, filter: Predicate) {
        self.filters.push(filter);
    }

    fn filter(&self, p: &str) -> bool {
        self.filters.iter().any(|f| (f.0)(p))
    }
}

#[cfg(test)]
mod find_functions {
    use std::error;

    use itertools::assert_equal;
    use speculoos::prelude::*;

    use super::*;
    use crate::parser::{Element, Parser};
    const FIXTURES: &str = "src/parser/fixtures/go";

    #[test]
    fn no_file_added() -> Result<(), Box<dyn error::Error>> {
        let mut p = GoParser::new()?;
        let res = p.find_functions();
        assert_that!(res).is_err();
        Ok(())
    }

    #[test]
    fn no_go_file() -> Result<(), Box<dyn error::Error>> {
        let some_types = vec![Lang::Undefined, Lang::Rust, Lang::Lua];
        for t in some_types {
            let mut p = GoParser::new()?;
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
        let mut p = GoParser::new()?;
        let f = File {
            path: format!("{FIXTURES}/no_function.1.go"),
            lang: Lang::Go,
        };
        p.add_file(f)?;
        let res = p.find_functions();
        assert_that!(res).is_ok();
        assert_that!(res.unwrap()).is_empty();
        Ok(())
    }

    #[test]
    fn returns_one_function_found() -> Result<(), Box<dyn error::Error>> {
        let mut p = GoParser::new()?;
        let path = format!("{FIXTURES}/one_function.1.go");
        let f = File {
            path: path.clone(),
            lang: Lang::Go,
        };
        p.add_file(f)?;
        let res = p.find_functions();
        assert_that!(res).is_ok();

        let res = res.unwrap();
        assert_that!(res).has_length(1);
        let element = res.get(0).unwrap();
        let want = Element {
            name: "FuncOne".to_owned(),
            line: 3,
            file: path,
        };
        assert_that!(element).is_equal_to(&want);
        Ok(())
    }

    #[test]
    fn can_identify_methods() -> Result<(), Box<dyn error::Error>> {
        let mut p = GoParser::new()?;
        let path = format!("{FIXTURES}/method.1.go");
        let f = File {
            path: path.clone(),
            lang: Lang::Go,
        };
        p.add_file(f)?;
        let res = p.find_functions();
        assert_that!(res).is_ok();

        let mut res = res.unwrap();
        let mut want = vec![
            Element {
                name: "FuncOne".to_owned(),
                line: 5,
                file: path.clone(),
            },
            Element {
                name: "FuncTwo".to_owned(),
                line: 6,
                file: path.clone(),
            },
            Element {
                name: "nested".to_owned(),
                line: 7,
                file: path,
            },
        ];
        want.sort_by(|a, b| a.name.cmp(&b.name));
        res.sort_by(|a, b| a.name.cmp(&b.name));

        assert_equal(want, res);
        Ok(())
    }

    #[test]
    fn returns_all_functions_in_files() -> Result<(), Box<dyn error::Error>> {
        let mut p = GoParser::new()?;
        let path = format!("{FIXTURES}/multi_functions.1.go");
        let f = File {
            path: path.clone(),
            lang: Lang::Go,
        };
        p.add_file(f)?;
        let res = p.find_functions();
        assert_that!(res).is_ok();

        let mut res = res.unwrap();
        let mut want = vec![
            Element {
                name: "FuncTwo".to_owned(),
                line: 3,
                file: path.clone(),
            },
            Element {
                name: "FuncThree".to_owned(),
                line: 5,
                file: path.clone(),
            },
            Element {
                name: "nested".to_owned(),
                line: 6,
                file: path,
            },
        ];
        want.sort_by(|a, b| a.name.cmp(&b.name));
        res.sort_by(|a, b| a.name.cmp(&b.name));

        assert_equal(want, res);
        Ok(())
    }

    #[test]
    fn handles_multiple_files() -> Result<(), Box<dyn error::Error>> {
        let mut p = GoParser::new()?;
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
        let res = p.find_functions();
        assert_that!(res).is_ok();

        let mut res = res.unwrap();
        let mut want = vec![
            Element {
                name: "FuncOne".to_owned(),
                line: 3,
                file: path2,
            },
            Element {
                name: "FuncTwo".to_owned(),
                line: 3,
                file: path1.clone(),
            },
            Element {
                name: "FuncThree".to_owned(),
                line: 5,
                file: path1.clone(),
            },
            Element {
                name: "nested".to_owned(),
                line: 6,
                file: path1,
            },
        ];
        want.sort_by(|a, b| a.name.cmp(&b.name));
        res.sort_by(|a, b| a.name.cmp(&b.name));

        assert_equal(want, res);
        Ok(())
    }
}
