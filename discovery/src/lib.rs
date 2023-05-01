//! This crate is used to discover files in a project for being used in the git-hotspots crate.
#![warn(missing_docs)]
use log::debug;
use rayon::prelude::*;
use std::{ops::Not, path::Path, result, time::Instant};
use walkdir::{DirEntry, WalkDir};

/// Contains the supported languages. The Undefined variant is used when the language is not
/// supported.
#[derive(Debug, Eq, PartialEq)]
pub enum Lang {
    /// Variant for the Rust language.
    Rust,
    /// Variant for the Go language.
    Go,
    /// Variant for the Lua language.
    Lua,
    /// Variant for unsupported languages.
    Undefined,
}

impl From<&str> for Lang {
    /// Converts id of the language detected by the detect_lang crate to the Lang enum.
    fn from(value: &str) -> Self {
        match value {
            "go" => Lang::Go,
            "rust" => Lang::Rust,
            "lua" => Lang::Lua,
            _ => Lang::Undefined,
        }
    }
}

/// Contains the path and the language of a file.
#[derive(Debug, Eq, PartialEq)]
pub struct File {
    /// Path of the file.
    pub path: String,
    /// Language of the file.
    pub lang: Lang,
}

/// Discovery finds files in a directory recursively. It can filter out the files based on their
/// prefix and if they not contain a certain string.
#[derive(Default)]
pub struct Discovery {
    prefixes: Vec<String>,
    not_contains: Vec<String>,
}

impl Discovery {
    /// Conditions the discovery to only find files that start with the given prefix.
    pub fn with_prefix(&mut self, p: String) {
        self.prefixes.push(p);
    }
    /// Conditions the discovery to only find files that do not contain the given string.
    pub fn not_contains(&mut self, p: String) {
        self.not_contains.push(p);
    }

    /// Discovers files in the given path. It filters out files that match the conditions set by
    /// the `with_prefix` and `not_contains` methods.
    pub fn discover<P: AsRef<Path>>(&self, path: P) -> Option<Vec<File>> {
        let start = Instant::now();
        let res: Vec<File> = WalkDir::new(&path)
            .into_iter()
            .par_bridge()
            .filter_map(result::Result::ok)
            .filter(|p| {
                if self.prefixes.is_empty() {
                    true
                } else {
                    self.prefixes
                        .iter()
                        .any(|prefix| p.path().starts_with(prefix))
                }
            })
            .filter(|p| {
                if self.not_contains.is_empty() {
                    true
                } else {
                    self.not_contains
                        .iter()
                        .any(|prefix| p.path().to_str().unwrap_or("").contains(prefix))
                        .not()
                }
            })
            .filter(is_project_file)
            .filter_map(|p| {
                let lang = match detect_lang::from_path(p.path()) {
                    Some(lang) => lang.id().into(),
                    None => Lang::Undefined,
                };
                let p = p.path().to_str();

                p.map(|path| File {
                    path: path.to_owned(),
                    lang,
                })
            })
            .collect();

        debug!("Discovery took {:?}", start.elapsed());

        if res.is_empty() {
            None
        } else {
            Some(res)
        }
    }
}

/// Checks if the given entry is a non-hidden file and not a directory.
fn is_project_file(entry: &DirEntry) -> bool {
    if entry.file_type().is_dir() {
        return false;
    }
    entry
        .file_name()
        .to_str()
        .map(|s| !s.starts_with('.'))
        .unwrap_or(false)
}

#[cfg(test)]
mod tests;
