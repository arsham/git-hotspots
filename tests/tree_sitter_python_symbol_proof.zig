//! Dedicated build target source for the internal Python symbol extraction
//! proof. Importing the runtime provider runs its in-memory fixture tests under
//! the Python symbol proof target without relying on the CLI runtime.

const tree_sitter_python = @import("tree_sitter_python");

test "Python symbol proof executes the runtime extraction fixture suite" {
    _ = tree_sitter_python;
}
