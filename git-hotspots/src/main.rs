use anyhow::Result;
use discovery::Discovery;
use discovery::Lang;
use log::{debug, info, warn, LevelFilter};
use prettytable::format;
use prettytable::Table;

use parser::parser::go::GoParser;
use parser::parser::lua::LuaParser;
use parser::parser::Parser;

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

    let insighter = insight::Inspector::new(&opt.root)?;

    let mut go_parser = GoParser::new()?;
    let mut lua_parser = LuaParser::new()?;
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

    let mut table = Table::new();
    table.set_titles(row![bFg->"FILE", bFg->"FUNCTION", bFg->"FREQUENCY"]);
    table.set_format(*format::consts::FORMAT_NO_LINESEP_WITH_TITLE);

    if let Some(locator) = discoverer.discover(&opt.root) {
        locator.into_iter().for_each(|file| {
            let path = file.path.clone();
            match file.lang {
                Lang::Go => {
                    if let Err(err) = go_parser.add_file(file) {
                        warn!("Failed to load file {path}: {err}");
                    } else if opt.log_level > 1 {
                        info!("Added {path}");
                    }
                },
                Lang::Lua => {
                    if let Err(err) = lua_parser.add_file(file) {
                        warn!("Failed to load file {path}: {err}");
                    } else if opt.log_level > 1 {
                        info!("Added {path}");
                    }
                },
                _ => {
                    if opt.log_level > 0 {
                        debug!("Unsupported file: {path}");
                    }
                },
            };
        });

        let parsers: Vec<(&str, Box<dyn Parser>)> =
            vec![("Go", Box::new(go_parser)), ("Lua", Box::new(lua_parser))];

        for (name, mut parser) in parsers {
            let res = parser.find_functions();
            if let Err(parser::parser::Error::NoFilesAdded) = res {
                info!("Parser {} didn't fund any files", name);
                continue;
            } else if let Err(err) = res {
                return Err(err)?;
            }

            let res = res.unwrap();
            let mut res = res
                .iter()
                .map(|f| {
                    (
                        f.file.as_str(),
                        f.name.as_str(),
                        insighter.function_history(&f.file, &f.name).unwrap().len(),
                    )
                })
                .collect::<Vec<(&str, &str, usize)>>();
            res.sort_by(|a, b| b.2.cmp(&a.2));
            res.into_iter()
                .skip(opt.skip)
                .take(opt.total)
                .for_each(|(file, func, freq)| {
                    table.add_row(row![file, func, Fr->freq.to_string()]);
                });
        }
        table.printstd();

        Ok(())
    } else {
        Err(anyhow::format_err!(
            "No files found in the current directory"
        ))
    }
}
