pub mod go;

use std::fs;
use std::io;
use std::io::{BufReader, Read};
use std::str::Utf8Error;

use thiserror::Error as TError;
use tree_sitter::Parser as TSParser;
use tree_sitter::{Query, QueryCursor, QueryMatch};

use discovery::File;

/// Error enumerates all errors for this application.
#[derive(TError, Debug)]
pub enum Error {
    /// Returned when we can't get the repository information.
    #[error("File is not compatible with this parser")]
    NotCompatible,

    #[error("No files have added")]
    NoFilesAdded,

    #[error(transparent)]
    TSQuery(#[from] tree_sitter::QueryError),

    #[error("Can't parse file")]
    ParseFile(String),

    #[error("File not found")]
    FileNotFound(String),

    #[error(transparent)]
    OpenFile(#[from] io::Error),

    #[error(transparent)]
    Utf8Str(#[from] Utf8Error),
}

#[derive(Debug, PartialEq, Eq)]
pub struct Element {
    pub name: String,
    pub file: String,
    pub line: usize,
}

fn collect_matches<'a>(
    matches: impl Iterator<Item = QueryMatch<'a, 'a>>,
    source: &'a str,
) -> Vec<(usize, &'a str)> {
    matches
        .filter_map(|m| {
            m.captures.iter().find_map(|capture| {
                if let Ok(line) = capture.node.utf8_text(source.as_bytes()) {
                    Some((capture.node.range().start_point.row + 1, line))
                } else {
                    None
                }
            })
        })
        .collect()
}

/// When the function returns true, the file is excluded from the oprtation.
pub struct Predicate(pub Box<dyn Fn(&str) -> bool>);

/// Parser provides the functionalities necessary for finding tree-sitter Nodes from a list of
/// given files.
pub trait Parser {
    /// Will return an error if the file is not compatible with the Parser.
    fn add_file(&mut self, f: discovery::File) -> Result<(), Error>;

    /// Returns a tree-sitter parser for the Parser's language.
    fn parser(&self) -> TSParser;

    /// Returns a tree-sitter Query object for the Parser's language.
    fn query(&self) -> Result<Query, Error>;

    /// Returns a mutable reference to the given files. It returns and error if the file can't be
    /// read.
    fn files(&self) -> Result<&[File], Error>;

    /// Adds the filter to the list of filters.
    fn filter_path(&mut self, filter: Predicate);

    /// Applies the filter on the file path.
    fn filter(&self, p: &str) -> bool;

    /// Returns all the functions in all files. It returns and error if the file can't be read, or
    /// the language parser can't parse the contents.
    fn find_functions(&mut self) -> Result<Vec<Element>, Error> {
        let mut parser = self.parser();
        let query = self.query()?;
        let files = self.files()?;
        let mut ret: Vec<Element> = Vec::with_capacity(files.len());

        for file in files {
            if self.filter(&file.path) {
                continue;
            }
            let file_handle = fs::File::open(&file.path)?;
            let mut reader = BufReader::new(file_handle);
            let mut source_code = String::new();
            reader.read_to_string(&mut source_code)?;
            let tree = parser
                .parse(&source_code, None)
                .ok_or(Error::ParseFile(file.path.clone()))?;

            let mut cursor = QueryCursor::new();
            let matches = cursor.matches(&query, tree.root_node(), source_code.as_bytes());
            let res = collect_matches(matches, &source_code);
            ret.append(
                &mut res
                    .into_iter()
                    .map(|(line, name)| Element {
                        name: name.to_owned(),
                        file: file.path.clone(),
                        line,
                    })
                    .collect::<Vec<Element>>(),
            );
        }
        Ok(ret)
    }
}
