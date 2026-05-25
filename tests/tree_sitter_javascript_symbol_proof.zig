//! Dedicated build target source for the runtime JavaScript current-symbol
//! provider. Importing the provider runs its in-memory fixture tests under the
//! JavaScript symbol proof target.

const tree_sitter_javascript = @import("tree_sitter_javascript");

test "JavaScript symbol proof executes the runtime provider fixture suite" {
    _ = tree_sitter_javascript;
}
