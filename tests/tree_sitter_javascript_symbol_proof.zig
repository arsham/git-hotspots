//! Dedicated build target source for the internal JavaScript symbol extraction
//! proof. Importing the query proof runs its in-memory fixture tests under the
//! JavaScript symbol proof target without wiring a runtime provider.

const tree_sitter_javascript_query_proof = @import("tree_sitter_javascript_query_proof.zig");

test "JavaScript symbol proof executes the query-backed extraction fixture suite" {
    _ = tree_sitter_javascript_query_proof;
}
