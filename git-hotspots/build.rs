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

    Ok(())
}
