use std::{fs::File, io, path::Path};
use tempfile::TempDir;

pub fn create_files(path: &TempDir, files: Vec<&str>) -> io::Result<()> {
    let path = Path::new(path.as_ref());
    for f in files {
        let filename = path.join(f);
        let prefix = filename.parent().unwrap();
        std::fs::create_dir_all(prefix)?;
        File::create(filename)?;
    }
    Ok(())
}
