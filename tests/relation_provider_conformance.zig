//! Test runner for the shared internal relation-provider conformance harness.

const relation_provider_conformance = @import("relation_provider_conformance");

test "relation provider conformance harness is linked" {
    _ = relation_provider_conformance;
}
