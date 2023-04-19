pub mod go;
pub mod lua;

use std::fs;
use std::io;
use std::io::{BufReader, Read};
use std::ops::Not;
use std::str::Utf8Error;
use std::time::Instant;

use indicatif::ProgressBar;
use log::debug;
use thiserror::Error as TError;
use tree_sitter::Parser as TSParser;
use tree_sitter::{Language, LanguageError, Query, QueryCursor, QueryMatch};

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

    #[error(transparent)]
    Language(#[from] LanguageError),
}

#[derive(Debug, PartialEq, Eq, Clone)]
pub struct Element {
    pub name: String,
    pub file: String,
    pub line: usize,
    index: u32,
}

fn collect_matches<'a>(
    matches: impl Iterator<Item = QueryMatch<'a, 'a>>,
    source: &'a str,
) -> Vec<(usize, u32, &'a str)> {
    matches
        .filter_map(|m| {
            m.captures.iter().find_map(|capture| {
                if let Ok(line) = capture.node.utf8_text(source.as_bytes()) {
                    Some((
                        capture.node.range().start_point.row + 1,
                        capture.index,
                        line,
                    ))
                } else {
                    None
                }
            })
        })
        .collect()
}

/// Parser provides the functionalities necessary for finding tree-sitter Nodes from a list of
/// given files.
pub trait Parser {
    /// Will return an error if the file is not compatible with the Parser.
    fn add_file(&mut self, f: discovery::File) -> Result<(), Error>;

    /// Returns a tree-sitter language.
    fn language(&self) -> Language;

    /// Returns a tree-sitter Query object for the Parser's language.
    fn query(&self) -> &Query;

    /// Returns a mutable reference to the given files. It returns and error if the file can't be
    /// read.
    fn files(&self) -> Result<&[File], Error>;

    /// Adds the filter for excluding functions.
    fn filter_name(&mut self, s: String);

    /// Applies the filter on function names.
    fn filter(&self, func_name: &str) -> bool;

    /// Returns a new vector with the representation names for functions.
    fn func_repr(&self, v: Vec<Element>) -> (Vec<Element>, usize) {
        (v, 0)
    }

    /// Returns all the functions in all files. It returns and error if the file can't be read, or
    /// the language parser can't parse the contents.
    fn find_functions(&mut self, pb: &ProgressBar) -> Result<Vec<Element>, Error> {
        let mut parser = TSParser::new();
        let language = self.language();
        parser.set_language(language)?;
        let query = self.query();
        let files = self.files()?;
        let mut ret: Vec<Element> = Vec::with_capacity(files.len());

        let start = Instant::now();
        for file in files {
            let file_handle = fs::File::open(&file.path)?;
            let mut reader = BufReader::new(file_handle);
            let mut source_code = String::new();
            reader.read_to_string(&mut source_code)?;
            let tree = parser
                .parse(&source_code, None)
                .ok_or(Error::ParseFile(file.path.clone()))?;

            let mut cursor = QueryCursor::new();

            let matches = cursor.matches(query, tree.root_node(), source_code.as_bytes());
            let res = collect_matches(matches, &source_code);
            ret.append(
                &mut res
                    .into_iter()
                    .map(|(line, index, name)| {
                        pb.inc_length(1);
                        Element {
                            name: name.to_owned(),
                            file: file.path.clone(),
                            line,
                            index,
                        }
                    })
                    .collect::<Vec<Element>>(),
            );
        }

        debug!("Finding function took {:?}", start.elapsed());

        let (res, mut redacted) = self.func_repr(ret);
        let len = res.len();
        let res = res
            .into_iter()
            .filter(|e| self.filter(&e.name).not())
            .collect::<Vec<Element>>();
        redacted += len - res.len();
        if let Some(len) = pb.length() {
            // To support tests.
            pb.set_length(len - redacted as u64);
        }
        Ok(res)
    }
}
