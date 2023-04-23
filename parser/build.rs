use npm_rs::*;
use std::process::Command;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let current_sha = Command::new("git")
        .args(["rev-parse", "--short", "HEAD"])
        .output()?;
    let current_sha = String::from_utf8(current_sha.stdout)?;

    std::process::Command::new("git")
        .args(["submodule", "update", "--init", "--recursive"])
        .output()
        .expect("Failed to fetch git submodules!");

    let build_tag = Command::new("git")
        .args(["describe", "--abbrev", "--tags"])
        .output()?;
    let build_tag = String::from_utf8(build_tag.stdout)?;

    println!("cargo:rustc-env=CURRENT_SHA={current_sha}");
    println!("cargo:rustc-env=APP_VERSION={build_tag}");
    if std::process::Command::new("sccache")
        .arg("--version")
        .status()
        .is_ok()
    {
        std::env::set_var("CC", "sccache cc");
        std::env::set_var("CXX", "sccache c++");
    }

    let languages = vec![
        ("rust", vec!["parser.c", "scanner.c"]),
        ("go", vec!["parser.c"]),
        ("lua", vec!["parser.c", "scanner.c"]),
    ];

    for spec in languages {
        let language = spec.0;
        let package = format!("tree-sitter-{language}");
        let node_dir = format!("grammars/{package}");
        let git_head = format!("../.git/modules/parser/grammars/{package}/HEAD");
        println!("cargo:rerun-if-changed={git_head}");

        NpmEnv::default()
            .with_node_env(&NodeEnv::Production)
            .set_path(&node_dir)
            .init_env()
            .install(None)
            .run("build")
            .exec()?;

        let mut builder = cc::Build::new();
        builder
            .flag_if_supported("-Wno-unused-parameter")
            .flag_if_supported("-Wno-unused-but-set-variable")
            .flag_if_supported("-Wno-trigraphs");
        for file in spec.1 {
            let node_dir = &node_dir.clone();
            let source_directory = format!("{node_dir}/src");
            let source_file = format!("{source_directory}/{file}");
            builder.file(source_file).include(source_directory);
        }
        builder.compile(&package);
    }

    Ok(())
}
