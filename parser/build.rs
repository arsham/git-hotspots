//! This crate contains the build script for parsers.
fn main() -> Result<(), Box<dyn std::error::Error>> {
    if std::process::Command::new("sccache")
        .arg("--version")
        .status()
        .is_ok()
    {
        std::env::set_var("CC", "sccache cc");
        std::env::set_var("CXX", "sccache c++");
    }

    Ok(())
}
