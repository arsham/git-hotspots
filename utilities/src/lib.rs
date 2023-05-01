//! This is a utility crate for the git-hotspots project. This is intended to be used in tests.
use std::fs::File;
use std::io;
use std::path::Path;

use git2::{Repository, RepositoryInitOptions};
use tempfile::TempDir;

/// Creates a temporary directory with the given files.
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

/// Creates and sets up a repository. This helper are borrowed from the git2 code.
pub fn repo_init() -> (TempDir, Repository) {
    let td = TempDir::new().unwrap();
    let mut opts = RepositoryInitOptions::new();
    opts.initial_head("master");
    let repo = Repository::init_opts(td.path(), &opts).unwrap();
    {
        let mut config = repo.config().unwrap();
        config.set_str("user.name", "name").unwrap();
        config.set_str("user.email", "email").unwrap();
        let mut index = repo.index().unwrap();
        let id = index.write_tree().unwrap();

        let tree = repo.find_tree(id).unwrap();
        let sig = repo.signature().unwrap();
        repo.commit(Some("HEAD"), &sig, &sig, "initial\n\nbody", &tree, &[])
            .unwrap();
    }
    (td, repo)
}
