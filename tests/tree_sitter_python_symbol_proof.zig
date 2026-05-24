//! Dedicated build target source for the internal Python symbol extraction
//! proof. Importing the query-contract proof runs its fixture tests under the
//! Python symbol proof target without adding runtime provider wiring or
//! user-facing Python symbol output.

const python_query_proof = @import("tree_sitter_python_query_proof.zig");

test "Python symbol proof executes the query-backed extraction fixture suite" {
    _ = python_query_proof;
}
