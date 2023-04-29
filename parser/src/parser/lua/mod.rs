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
mod tests;
