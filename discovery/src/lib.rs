use log::debug;
use rayon::prelude::*;
use std::{ops::Not, path::Path, result, time::Instant};
use walkdir::{DirEntry, WalkDir};

#[derive(Debug, Eq, PartialEq)]
pub enum Lang {
    Rust,
    Go,
    Lua,
    Undefined,
}

impl From<&str> for Lang {
    fn from(value: &str) -> Self {
        match value {
            "go" => Lang::Go,
            "rust" => Lang::Rust,
            "lua" => Lang::Lua,
            _ => Lang::Undefined,
        }
    }
}

#[derive(Debug, Eq, PartialEq)]
pub struct File {
    pub path: String,
    pub lang: Lang,
}

#[derive(Default)]
pub struct Discovery {
    prefixes: Vec<String>,
    not_contains: Vec<String>,
}

impl Discovery {
    pub fn with_prefix(&mut self, p: String) {
        self.prefixes.push(p);
    }
    pub fn not_contains(&mut self, p: String) {
        self.not_contains.push(p);
    }

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
