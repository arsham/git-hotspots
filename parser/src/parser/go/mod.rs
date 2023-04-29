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
mod tests;
