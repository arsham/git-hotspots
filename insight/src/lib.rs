//! This crate is used to get the history of functions and methods in a git repository.

use std::process::Command;
use std::{io, str};

use grep_matcher::{Captures, Matcher};
use grep_regex::RegexMatcher;
use grep_searcher::sinks::UTF8;
use grep_searcher::Searcher;
use thiserror::Error as TError;

/// Inspector interrogates the git repository for history of functions and methods.
pub struct Inspector {
    matcher: RegexMatcher,
    path: String,
}

/// Error enumerates all errors for this application.
#[derive(TError, Debug)]
pub enum Error {
    /// Any IO errors.
    #[error(transparent)]
    IO(#[from] io::Error),

    /// Error from the grep crate.
    #[error(transparent)]
    Grep(#[from] grep_regex::Error),

    /// Error related to the UTF8 encoding.
    #[error(transparent)]
    UTF8(#[from] str::Utf8Error),

    /// When the path is not a git repository.
    #[error("Not a git directory")]
    NotGitRepo,
}

impl Inspector {
    /// Returns an error if the path is not a valid repository.
    pub fn new(path: &str) -> Result<Self, Error> {
        let output = Command::new("git")
            .args(["rev-parse", "--is-inside-work-tree"])
            .current_dir(path)
            .output()?;
        if output.status.success() {
            Ok(Inspector {
                matcher: RegexMatcher::new(r"^commit (.{40})")?,
                path: String::from(path),
            })
        } else {
            Err(Error::NotGitRepo)
        }
    }

    /// Returns the commits that the function by func_name appears for the filename from beginning
    /// of the repository.
    pub fn function_history(&self, filename: &str, func_name: &str) -> Result<Vec<String>, Error> {
        let input = format!(":{func_name}:{filename}");
        let output = Command::new("git")
            .args(["log", "-L", &input])
            .current_dir(&self.path)
            .output()?;
        self.commits(str::from_utf8(&output.stdout)?)
    }

    fn commits(&self, input: &str) -> Result<Vec<String>, Error> {
        let mut matches: Vec<String> = vec![];
        Searcher::new().search_slice(
            &self.matcher,
            input.as_bytes(),
            UTF8(|_, line| {
                let mut caps = self.matcher.new_captures()?;
                match self.matcher.captures(line.as_bytes(), &mut caps) {
                    Ok(true) => {
                        matches.push(line[caps.get(1).unwrap()].to_owned());
                        Ok(true)
                    },
                    _ => Ok(false),
                }
            }),
        )?;
        Ok(matches)
    }
}

#[cfg(test)]
mod commits {
    use itertools::assert_equal;
    use speculoos::prelude::*;

    use super::*;

    fn new_inspector() -> Inspector {
        let (dir, _) = hotspots_utilities::repo_init();
        let path = dir.path().as_os_str().to_string_lossy().to_string();
        let inspector = Inspector::new(path.as_str()).unwrap();
        inspector
    }

    #[test]
    fn empty_input() -> Result<(), Box<dyn std::error::Error>> {
        let inspector = new_inspector();
        let res = inspector.commits("")?;
        assert_that!(res).is_empty();
        Ok(())
    }

    #[test]
    fn no_commit_in_input() -> Result<(), Box<dyn std::error::Error>> {
        let inspector = new_inspector();
        let input = "something\nsomething\ncommit 1234\nnooo";
        let res = inspector.commits(input)?;
        assert_that!(res).is_empty();
        Ok(())
    }

    #[test]
    fn commit_in_input() -> Result<(), Box<dyn std::error::Error>> {
        let inspector = new_inspector();
        let hash = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        let input = format!("commit {hash}");
        let res = inspector.commits(&input)?;
        assert_that!(res).has_length(1);
        assert_that!(res.get(0).unwrap()).is_equal_to(&hash.to_owned());
        Ok(())
    }
    #[test]
    fn finds_commits() -> Result<(), Box<dyn std::error::Error>> {
        let inspector = new_inspector();
        let hash1 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
        let hash2 = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
        let hash3 = "cccccccccccccccccccccccccccccccccccccccc";
        let input = format!("commit {hash1}\nnocommit {hash2}\ncommit {hash3}\n");
        let res = inspector.commits(&input)?;
        assert_equal(res, vec![hash1, hash3]);
        Ok(())
    }
}
