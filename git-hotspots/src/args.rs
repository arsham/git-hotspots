use structopt::clap::AppSettings::{ColorAuto, ColoredHelp, DisableVersion};
use structopt::StructOpt;

/// Options for running git-release.
#[derive(StructOpt, Debug)]
#[structopt(name = "git-release", about = "Make a github release for tags")]
#[structopt(no_version, global_settings = &[DisableVersion])]
#[structopt(setting(ColorAuto), setting(ColoredHelp))]
pub struct Opt {
    /// Total number of results
    #[structopt(long, short, default_value = "50")]
    pub total: usize,

    /// Skip first n results
    #[structopt(long, short, default_value = "0", hide_default_value = true)]
    pub skip: usize,

    /// Log level. Try -VV for more logs!
    #[structopt(long, short = "V", parse(from_occurrences))]
    pub log_level: u8,

    /// Show results beginning with the given string
    #[structopt(long, short, default_value = "", hide_default_value = true)]
    pub prefix: String,

    /// Exclude partiallly matched path.
    #[structopt(long, short = "v")]
    pub invert_match: Option<String>,

    /// Root of the project to inspect.
    #[structopt(short, long, default_value = ".")]
    pub root: String,

    #[structopt(subcommand)]
    pub sub_commands: Option<Command>,
}

#[derive(StructOpt, Debug)]
pub enum Command {
    /// Print the application version.
    Version,
}

impl Opt {
    pub fn new() -> Opt {
        Opt::from_args()
    }
}
