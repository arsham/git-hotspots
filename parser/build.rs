use npm_rs::*;
use std::process::Command;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let current_sha = Command::new("git")
        .args(["rev-parse", "--short", "HEAD"])
        .output()?;
    let current_sha = String::from_utf8(current_sha.stdout)?;

    let build_tag = Command::new("git")
        .args(["describe", "--abbrev", "--tags"])
        .output()?;
    let build_tag = String::from_utf8(build_tag.stdout)?;

    println!("cargo:rustc-env=CURRENT_SHA={current_sha}");
    println!("cargo:rustc-env=APP_VERSION={build_tag}");

    let language = "go";
    let package = format!("tree-sitter-{}", language);
    let node_dir = format!("grammars/{}", package);
    let source_directory = format!("{}/src", node_dir);
    let source_file = format!("{}/parser.c", source_directory);

    println!("cargo:rerun-if-changed={}", source_file);


    NpmEnv::default()
        .with_node_env(&NodeEnv::Production)
        .set_path(node_dir)
        .init_env()
        .install(None)
        .run("build")
        .exec()?;

    cc::Build::new()
        .file(source_file)
        .include(source_directory)
        .compile(&package);

    Ok(())
}
