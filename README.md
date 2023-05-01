# Git Hotspots

[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/arsham/git-hotspots/integration.yml?logo=github)](https://github.com/arsham/git-hotspots/actions/workflows/integration.yml)
[![Crates.io](https://img.shields.io/crates/v/git-hotspots?color=green&logo=rust&logoColor=orange)](https://crates.io/crates/git-hotspots)
[![License](https://img.shields.io/github/license/arsham/git-hotspots)](https://github.com/arsham/git-hotspots/blob/master/LICENSE)

This tool helps with identifying functions that have had a lot of changes in
the `git` history. It does this by parsing the files that are supported by the
program and then using the git history to count how many times each function
has been changed.

Please note that this tool is still in its early stages, and there are a lot of
things to improve. If you have any suggestions, please open an issue.

1. [Why is this helpful](#why-is-this-helpful)
2. [Installation](#installation)
3. [Usage](#usage)
4. [Supported Languages](#supported-languages)
5. [License](#license)

## Why is this helpful

As you work on your project, the more you change a function, the more likely it
is that you will work on it again. If this particular function is changed too
often, it might be a sign that the function requires more attention and can
contribute to technical debt.

With this tool you can identify functions that are too big or complex and are
being refactored a lot, or are refactored a lot in relation to another part of
the program.

Additionally when you want to make a decision on how to refactor your code, you
can use this to find out which functions are the most changed and start with
those. This can help you to make a more informed decision on how to refactor
your code.

## Installation

To install:

```bash
cargo install git-hotspots
```

Assuming the binary path is in the your `PATH`, `git` automatically picks this
up as a subcommand.

## Usage

To view top 50 functions with the most changes in git history:

```bash
git hotspots
```

You can control how the tool operates by passing the following flags:

- `--total`, `-t`: Total number of results. Default: 50
- `--skip`, `-s`: Skip first n results. Default: 0
- `--log-level`, `-V`: Log level. Try -VV for more logs!
- `--prefix`, `-p`: Show results beginning with the given string.
- `--invert-match`, `-v`: Exclude partially matched path.
- `--exclude-func`, `-F`: Exclude function by partial match.
- `--root`, `-r`: Root of the project to inspect. Default: .

## Supported Languages

Currently the following languages are supported:

- Rust
- Go
- Lua

However, it is easy to add support for other languages. Just create an issue
for the language you want to be supported, and I'll add it to the list.

## License

Licensed under the MIT License. Check the [LICENSE](./LICENSE) file for details.

<!--
vim: foldlevel=1
-->
