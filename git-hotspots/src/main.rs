/*!
Git subcommand for finding hotspots in a git repository.

This tool helps with identifying functions that have had a lot of changes in the git history.
It does this by parsing the files that are supported by the program and then using the git
history to count how many times each function has been changed.

# Why is this helpful?

As you work on your project, the more you change a function, the more likely it is that you
will work on it again. If this particular function is changed too often, it might be a sign
that the function requires more attention and can contribute to technical debt.

With this tool you can identify functions that are too big or complex and are being refactored
a lot, or are refactored a lot in relation to another part of the program.

Additionally when you want to make a decision on how to refactor your code, you can use this to
find out which functions are the most changed and start with those. This can help you to make a
more informed decision on how to refactor your code.

# Usage

Put the binary in your path. Note that git uses any binary that starts with `git-` as a git sub
command.

```bash
git hotspots
```
This will print out 50 found functions in the order of how often they have been changed.

## Options

* `--total`, `-t`: Total number of results. Default: 50
* `--skip`, `-s`: Skip first n results. Default: 0
* `--log-level`, `-V`: Log level. Try -VV for more logs!
* `--prefix`, `-p`: Show results beginning with the given string.
* `--invert-match`, `-v`: Exclude partially matched path.
* `--exclude-func`, `-F`: Exclude function by partial match.
* `--root`, `-r`: Root of the project to inspect. Default: .
*/
#![warn(missing_docs)]
use std::time::Instant;

use anyhow::Result;
use indicatif::ProgressBar;
use log::{debug, info, warn, LevelFilter};
use prettytable::format;
use prettytable::Table;
use rayon::prelude::*;

use hotspots_discovery::Discovery;
use hotspots_discovery::Lang;
use hotspots_insight::Inspector;
use hotspots_parser as parser;
use hotspots_parser::go::GoParser;
use hotspots_parser::lua::LuaParser;
use hotspots_parser::rust::RustParser;
use hotspots_parser::{Container, Parser};

#[macro_use]
extern crate prettytable;

mod args;

fn main() -> Result<()> {
    let opt = args::Opt::new();

    env_logger::builder()
        .filter_level(match opt.log_level {
            0 => LevelFilter::Off,
            1 => LevelFilter::Error,
            2 => LevelFilter::Warn,
            3 => LevelFilter::Info,
            _ => LevelFilter::Debug,
        })
        .init();

    if let Some(args::Command::Version) = opt.sub_commands {
        println!(
            "git-release version: {}, git commit: {}",
            env!("APP_VERSION"),
            env!("CURRENT_SHA")
        );
        return Ok(());
    }

    let insighter = Inspector::new(&opt.root)?;

    let mut go_parser = GoParser::new(Container::new(100))?;
    let mut rust_parser = RustParser::new(Container::new(100))?;
    let mut lua_parser = LuaParser::new(Container::new(100))?;
    let mut discoverer = Discovery::default();
    if let Some(prefixes) = opt.prefix {
        for prefix in prefixes {
            discoverer.with_prefix(format!("./{prefix}"));
        }
    }

    if let Some(terms) = opt.invert_match {
        for term in terms {
            discoverer.not_contains(term.clone());
        }
    }

    if let Some(terms) = opt.exclude_func {
        for term in terms {
            go_parser.filter_name(term.clone());
            rust_parser.filter_name(term.clone());
            lua_parser.filter_name(term);
        }
    }

    let mut table = Table::new();
    table.set_titles(row![bFg->"FILE", bFg->"LINE", bFg->"FUNCTION", bFg->"FREQUENCY"]);
    table.set_format(*format::consts::FORMAT_NO_LINESEP_WITH_TITLE);

    if let Some(locator) = discoverer.discover(&opt.root) {
        locator.into_iter().for_each(|file| {
            let path = file.path.clone();
            let err = match file.lang {
                Lang::Go => go_parser.add_file(file),
                Lang::Rust => rust_parser.add_file(file),
                Lang::Lua => lua_parser.add_file(file),
                _ => {
                    if opt.log_level > 0 {
                        warn!("Unsupported file: {path}");
                    }
                    return;
                },
            };
            if let Err(err) = err {
                warn!("Failed to load file {path}: {err}");
            } else if opt.log_level > 1 {
                info!("Added {path}");
            };
        });
        let pb = ProgressBar::new(0);

        let parsers: Vec<(&str, Box<dyn Parser>)> = vec![
            ("Go", Box::new(go_parser)),
            ("Rust", Box::new(rust_parser)),
            ("Lua", Box::new(lua_parser)),
        ];

        let mut report: Vec<(String, usize, String, usize)> = Vec::new();

        for (name, mut parser) in parsers {
            let res = parser.find_functions(&pb);
            let res = match res {
                Ok(r) => r,
                Err(parser::Error::NoFilesAdded) => {
                    debug!("Parser {name} didn't find any files");
                    continue;
                },
                Err(parser::Error::ParseFile(msg)) => {
                    warn!("Parser {name} encounter an error: {msg}");
                    continue;
                },
                Err(err) => {
                    debug!("Parser {name} encounter an error: {err}");
                    return Err(err)?;
                },
            };

            let start = Instant::now();
            report.extend(
                res.into_iter()
                    .par_bridge()
                    .map(|f| {
                        pb.inc(1);
                        (
                            f.file.clone(),
                            f.line,
                            f.name.clone(),
                            insighter.function_history(&f.file, &f.name).unwrap().len(),
                        )
                    })
                    .collect::<Vec<(String, usize, String, usize)>>(),
            );
            debug!("Function hitory examination took {:?}", start.elapsed());
        }

        report.sort_by(|a, b| b.3.cmp(&a.3));
        report
            .into_iter()
            .skip(opt.skip)
            .take(opt.total)
            .for_each(|(file, line, func, freq)| {
                table.add_row(row![file, line, func, Fr->freq.to_string()]);
            });
        table.printstd();

        pb.finish_with_message("done");
        Ok(())
    } else {
        Err(anyhow::format_err!(
            "No files found in the current directory"
        ))
    }
}
