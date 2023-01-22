use anyhow::Result;
use discovery::{discover, Lang};
use log::{debug, info, warn, LevelFilter};
use parser::parser::{go::GoParser, Parser, Predicate};
use prettytable::format;
use prettytable::Table;

#[macro_use]
extern crate prettytable;

mod args;

fn main() -> Result<()> {
    let opt = args::Opt::new();

    let log_level = match opt.log_level {
        0 => LevelFilter::Off,
        1 => LevelFilter::Error,
        2 => LevelFilter::Warn,
        3 => LevelFilter::Info,
        _ => LevelFilter::Debug,
    };
    env_logger::builder().filter_level(log_level).init();

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
    if !opt.prefix.is_empty() {
        let prefix = format!("./{}", opt.prefix);
        go_parser.filter_path(Predicate(Box::new(move |p: &str| !p.starts_with(&prefix))));
    }
    if opt.invert_match.is_some() {
        let prefix = opt.invert_match.unwrap();
        go_parser.filter_path(Predicate(Box::new(move |p: &str| p.contains(&prefix))));
    }
    go_parser.filter_path(Predicate(Box::new(|p: &str| p.contains("grammar"))));

    let mut table = Table::new();
    table.set_titles(row![bFg->"FILE", bFg->"FUNCTION", bFg->"FREQUENCY"]);
    table.set_format(*format::consts::FORMAT_NO_LINESEP_WITH_TITLE);

    if let Some(locator) = discover(&opt.root) {
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
                _ => {
                    if opt.log_level > 0 {
                        debug!("Unsupported file: {path}");
                    }
                },
            }
        });
        let res = go_parser.find_functions()?;
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
        table.printstd();

        Ok(())
    } else {
        Err(anyhow::format_err!(
            "No files found in the current directory"
        ))
    }
}
