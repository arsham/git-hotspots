use discovery::Lang;
use include_dir::{include_dir, Dir};
use tree_sitter::{Language, Query};

use super::Error;

static PROJECT_DIR: Dir = include_dir!("$CARGO_MANIFEST_DIR");

extern "C" {
    fn tree_sitter_rust() -> Language;
}

/// This parser can parse any Rust files.
pub struct RustParser {
    container: super::Container,
    query: Query,
}

impl RustParser {
    pub fn new(c: super::Container) -> Result<Self, Error> {
        let queries = PROJECT_DIR
            .get_file("src/parser/queries/rust.scm")
            .ok_or(Error::FileNotFound("rust.scm not found".to_owned()))?;
        let query = queries
            .contents_utf8()
            .ok_or(Error::ParseFile("Can't parse queries".to_owned()))?;
        let language = unsafe { tree_sitter_rust() };
        let query = Query::new(language, query)?;

        Ok(RustParser {
            query,
            container: c,
        })
    }
}

impl super::Parser for RustParser {
    fn container(&mut self) -> &mut super::Container {
        &mut self.container
    }

    fn ro_container(&self) -> &super::Container {
        &self.container
    }

    fn supported(&self, f: &discovery::File) -> bool {
        f.lang == Lang::Rust
    }

    fn language(&self) -> Language {
        unsafe { tree_sitter_rust() }
    }

    fn query(&self) -> &Query {
        &self.query
    }
}

#[cfg(test)]
mod tests;
