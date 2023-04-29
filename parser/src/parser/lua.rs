use include_dir::{include_dir, Dir};
use tree_sitter::{Language, Query};

use super::Error;
use discovery::Lang;

static PROJECT_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR");

extern "C" {
    fn tree_sitter_lua() -> Language;
}

/// This parser can parse any Lua files.
pub struct LuaParser {
    container: super::Container,
    query: Query,
}

impl LuaParser {
    pub fn new(c: super::Container) -> Result<Self, Error> {
        let queries = PROJECT_DIR
            .get_file("src/parser/queries/lua.scm")
            .ok_or(Error::FileNotFound("lua.scm not found".to_owned()))?;
        let query = queries
            .contents_utf8()
            .ok_or(Error::ParseFile("Can't parse queries".to_owned()))?;
        let language = unsafe { tree_sitter_lua() };
        let query = Query::new(language, query)?;

        Ok(LuaParser {
            query,
            container: c,
        })
    }
}

impl super::Parser for LuaParser {
    fn container(&mut self) -> &mut super::Container {
        &mut self.container
    }

    fn ro_container(&self) -> &super::Container {
        &self.container
    }

    fn supported(&self, f: &discovery::File) -> bool {
        f.lang == Lang::Lua
    }

    fn language(&self) -> Language {
        unsafe { tree_sitter_lua() }
    }

    fn query(&self) -> &Query {
        &self.query
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
    const FIXTURES: &str = "src/parser/fixtures/lua";

    #[test]
    fn no_file_added() -> Result<(), Box<dyn error::Error>> {
        let mut p = LuaParser::new(Container::new(100))?;
        let res = p.find_functions(&pb::hidden());
        assert_that!(res).is_err();
        Ok(())
    }

    #[test]
    fn no_lua_file() -> Result<(), Box<dyn error::Error>> {
        let some_types = vec![Lang::Undefined, Lang::Rust, Lang::Go];
        for t in some_types {
            let mut p = LuaParser::new(Container::new(100))?;
            let f = File {
                path: format!("{FIXTURES}/no_file.1.lua"),
                lang: t,
            };
            let res = p.add_file(f);
            assert_that!(res).is_err();
        }
        Ok(())
    }

    #[test]
    fn no_function_in_file() -> Result<(), Box<dyn error::Error>> {
        let mut p = LuaParser::new(Container::new(100))?;
        let f = File {
            path: format!("{FIXTURES}/no_function.1.lua"),
            lang: Lang::Lua,
        };
        p.add_file(f)?;
        let res = p.find_functions(&pb::hidden());
        assert_that!(res).is_ok();
        assert_that!(res.unwrap()).is_empty();
        Ok(())
    }

    #[test]
    fn returns_one_function_found() -> Result<(), Box<dyn error::Error>> {
        let mut p = LuaParser::new(Container::new(100))?;
        let path = format!("{FIXTURES}/one_function.1.lua");
        let f = File {
            path: path.clone(),
            lang: Lang::Lua,
        };
        p.add_file(f)?;
        let res = p.find_functions(&pb::hidden());
        assert_that!(res).is_ok();

        let res = res.unwrap();
        assert_that!(res).has_length(1);
        let element = res.get(0).unwrap();
        let want = Element {
            name: "func_one".to_owned(),
            line: 3,
            file: path,
            index: 0,
        };
        assert_that!(element).is_equal_to(&want);
        Ok(())
    }

    #[test]
    fn can_identify_methods() -> Result<(), Box<dyn error::Error>> {
        let mut p = LuaParser::new(Container::new(100))?;
        let path = format!("{FIXTURES}/method.1.lua");
        let f = File {
            path: path.clone(),
            lang: Lang::Lua,
        };
        p.add_file(f)?;
        let res = p.find_functions(&pb::hidden());
        assert_that!(res).is_ok();

        let mut res = res.unwrap();
        let mut want = vec![
            Element {
                name: "method_one".to_owned(),
                line: 3,
                file: path.clone(),
                index: 0,
            },
            Element {
                name: "method_two".to_owned(),
                line: 5,
                file: path.clone(),
                index: 0,
            },
            Element {
                name: "method_three".to_owned(),
                line: 7,
                file: path.clone(),
                index: 0,
            },
            Element {
                name: "nested".to_owned(),
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
        let mut p = LuaParser::new(Container::new(100))?;
        let path = format!("{FIXTURES}/multi_functions.1.lua");
        let f = File {
            path: path.clone(),
            lang: Lang::Lua,
        };
        p.add_file(f)?;
        let res = p.find_functions(&pb::hidden());
        assert_that!(res).is_ok();

        let mut res = res.unwrap();
        let mut want = vec![
            Element {
                name: "func_five".to_owned(),
                line: 1,
                file: path.clone(),
                index: 0,
            },
            Element {
                name: "func_six".to_owned(),
                line: 2,
                file: path.clone(),
                index: 0,
            },
            Element {
                name: "method_one".to_owned(),
                line: 5,
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
        let mut p = LuaParser::new(Container::new(100))?;
        let path1 = format!("{FIXTURES}/multi_functions.1.lua");
        let path2 = format!("{FIXTURES}/one_function.1.lua");
        let f1 = File {
            path: path1.clone(),
            lang: Lang::Lua,
        };
        let f2 = File {
            path: path2.clone(),
            lang: Lang::Lua,
        };
        p.add_file(f1)?;
        p.add_file(f2)?;
        let res = p.find_functions(&pb::hidden());
        assert_that!(res).is_ok();

        let mut res = res.unwrap();
        let mut want = vec![
            Element {
                name: "func_five".to_owned(),
                line: 1,
                file: path1.clone(),
                index: 0,
            },
            Element {
                name: "func_one".to_owned(),
                line: 3,
                file: path2,
                index: 0,
            },
            Element {
                name: "func_six".to_owned(),
                line: 2,
                file: path1.clone(),
                index: 0,
            },
            Element {
                name: "method_one".to_owned(),
                line: 5,
                file: path1,
                index: 0,
            },
        ];
        want.sort_by(|a, b| a.name.cmp(&b.name));
        res.sort_by(|a, b| a.name.cmp(&b.name));

        assert_equal(want, res);
        Ok(())
    }
}
