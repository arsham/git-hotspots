//! Shared internal conformance harness for provider-neutral relationship evidence.
//! These tests are admission checks for relation providers only; they do not
//! change public CLI support claims, scoring, ranking, or report semantics.

const std = @import("std");

const tree_sitter_go = @import("tree_sitter_go.zig");
const tree_sitter_javascript = @import("tree_sitter_javascript.zig");
const tree_sitter_python = @import("tree_sitter_python.zig");
const tree_sitter_rust = @import("tree_sitter_rust.zig");
const tree_sitter_typescript = @import("tree_sitter_typescript.zig");

const SupportedCase = struct {
    path: []const u8,
    source: []const u8,
    expected_provider_name: []const u8,
    expected_kinds: []const []const u8,
    expected_targets: []const []const u8,
};

const DegradedCase = struct {
    unsupported_path: []const u8,
    valid_source: []const u8,
    invalid_path: []const u8,
    invalid_source: []const u8,
};

const GoLane = struct {
    fn extract(allocator: std.mem.Allocator, path: []const u8, source: []const u8, options: tree_sitter_go.RelationOptions) !tree_sitter_go.RelationExtraction {
        return tree_sitter_go.extractRelationsSource(allocator, path, source, options);
    }
};

const PythonLane = struct {
    fn extract(allocator: std.mem.Allocator, path: []const u8, source: []const u8, options: tree_sitter_python.RelationOptions) !tree_sitter_python.RelationExtraction {
        return tree_sitter_python.extractRelationsSource(allocator, path, source, options);
    }
};

const JavaScriptLane = struct {
    fn extract(allocator: std.mem.Allocator, path: []const u8, source: []const u8, options: tree_sitter_javascript.RelationOptions) !tree_sitter_javascript.RelationExtraction {
        return tree_sitter_javascript.extractRelationsSource(allocator, path, source, options);
    }
};

const RustLane = struct {
    fn extract(allocator: std.mem.Allocator, path: []const u8, source: []const u8, options: tree_sitter_rust.RelationOptions) !tree_sitter_rust.RelationExtraction {
        return tree_sitter_rust.extractRelationsSource(allocator, path, source, options);
    }
};

const TypeScriptLane = struct {
    fn extract(allocator: std.mem.Allocator, path: []const u8, source: []const u8, options: tree_sitter_typescript.RelationOptions) !tree_sitter_typescript.RelationExtraction {
        return tree_sitter_typescript.extractRelationsSource(allocator, path, source, options);
    }
};

fn runSupportedConformance(comptime Lane: type, case: SupportedCase) !void {
    const allocator = std.testing.allocator;

    var first = try Lane.extract(allocator, case.path, case.source, .{});
    defer first.deinit(allocator);
    var second = try Lane.extract(allocator, case.path, case.source, .{});
    defer second.deinit(allocator);

    try std.testing.expectEqualStrings(case.expected_provider_name, first.provider.name);
    try expectTag(first.provider.kind, "relation");
    try expectTag(first.provider.failure, "ok");
    try expectTag(first.provider.freshness, "fresh");
    try std.testing.expect(!first.cap_reached);
    try std.testing.expect(first.candidates.len > 0);
    try expectPrivateSafeProvider(first.provider);
    try expectDeterministicOrder(first.candidates);
    try expectSameCandidateOrder(first.candidates, second.candidates);
    try expectDuplicateMultiPassCaveatMerge(first.candidates);

    for (case.expected_kinds) |kind| try expectRelationKind(first.candidates, kind);
    for (case.expected_targets) |target| try expectRelationTarget(first.candidates, target);

    for (first.candidates) |candidate| {
        try expectTag(candidate.provider.kind, "relation");
        try expectTag(candidate.failure, "ok");
        try expectPrivateSafeProvider(candidate.provider);
        try expectPrivateSafeCandidate(candidate);
        try expectCaveat(candidate.caveats, "symbol relationships are optional caveated provider evidence and are not used for scoring, ranking, cache truth, ownership, developer metrics, or bug prediction");
    }
}

fn runDegradedConformance(comptime Lane: type, case: DegradedCase) !void {
    const allocator = std.testing.allocator;

    var unsupported = try Lane.extract(allocator, case.unsupported_path, case.valid_source, .{});
    defer unsupported.deinit(allocator);
    try expectTag(unsupported.provider.kind, "relation");
    try expectTag(unsupported.provider.failure, "unsupported");
    try std.testing.expectEqual(@as(usize, 0), unsupported.candidates.len);
    try expectPrivateSafeProvider(unsupported.provider);

    var failed = try Lane.extract(allocator, case.invalid_path, case.invalid_source, .{});
    defer failed.deinit(allocator);
    try expectTag(failed.provider.kind, "relation");
    try expectTag(failed.provider.failure, "failed");
    try std.testing.expectEqual(@as(usize, 0), failed.candidates.len);
    try expectPrivateSafeProvider(failed.provider);

    var unavailable = try Lane.extract(allocator, case.invalid_path, case.valid_source, .{ .force_provider_unavailable = true });
    defer unavailable.deinit(allocator);
    try expectTag(unavailable.provider.kind, "relation");
    try expectTag(unavailable.provider.failure, "unavailable");
    try std.testing.expectEqual(@as(usize, 0), unavailable.candidates.len);
    try expectPrivateSafeProvider(unavailable.provider);

    var oversized = try Lane.extract(allocator, case.invalid_path, case.valid_source, .{ .max_source_bytes = 4 });
    defer oversized.deinit(allocator);
    try expectTag(oversized.provider.kind, "relation");
    try expectTag(oversized.provider.failure, "skipped");
    try std.testing.expectEqual(@as(usize, 0), oversized.candidates.len);
    try expectPrivateSafeProvider(oversized.provider);

    var capped = try Lane.extract(allocator, case.invalid_path, case.valid_source, .{ .max_candidates = 2 });
    defer capped.deinit(allocator);
    try std.testing.expect(capped.cap_reached);
    try std.testing.expect(capped.omitted_count > 0);
    try expectTag(capped.provider.freshness, "partial");
    try expectCaveat(capped.provider.caveats, "relation candidate cap reached; emitted evidence is partial and deterministically truncated");
    try expectPrivateSafeProvider(capped.provider);
    try expectDeterministicOrder(capped.candidates);
}

fn expectTag(value: anytype, expected: []const u8) !void {
    try std.testing.expectEqualStrings(expected, @tagName(value));
}

fn expectRelationKind(candidates: anytype, expected: []const u8) !void {
    for (candidates) |candidate| if (std.mem.eql(u8, @tagName(candidate.kind), expected)) return;
    return error.ExpectedRelationKindMissing;
}

fn expectRelationTarget(candidates: anytype, expected: []const u8) !void {
    for (candidates) |candidate| if (relationTargetEquals(candidate, expected)) return;
    return error.ExpectedRelationTargetMissing;
}

fn relationTargetEquals(candidate: anytype, expected: []const u8) bool {
    return endpointEquals(candidate.target, expected);
}

fn endpointEquals(endpoint: anytype, expected: []const u8) bool {
    return switch (endpoint) {
        .file => |file| std.mem.eql(u8, file.path, expected),
        .current_symbol => |symbol| std.mem.eql(u8, symbol.name, expected),
        .report_symbol => |symbol| std.mem.eql(u8, symbol.name, expected),
        .unresolved, .external_string => |named| std.mem.eql(u8, named.value, expected),
    };
}

fn expectDeterministicOrder(candidates: anytype) !void {
    if (candidates.len < 2) return;
    var previous = candidates[0];
    for (candidates[1..]) |candidate| {
        try std.testing.expect(compareOrderKey(previous, candidate) != .gt);
        previous = candidate;
    }
}

fn expectSameCandidateOrder(lhs: anytype, rhs: anytype) !void {
    try std.testing.expectEqual(lhs.len, rhs.len);
    for (lhs, rhs) |left, right| {
        try std.testing.expectEqualStrings(@tagName(left.kind), @tagName(right.kind));
        try std.testing.expectEqualStrings(@tagName(left.direction), @tagName(right.direction));
        try std.testing.expectEqualStrings(left.order_key.path, right.order_key.path);
        try std.testing.expectEqual(left.order_key.start_byte, right.order_key.start_byte);
        try std.testing.expectEqual(left.order_key.end_byte, right.order_key.end_byte);
        try std.testing.expectEqualStrings(left.order_key.relation, right.order_key.relation);
        try std.testing.expectEqualStrings(left.order_key.target, right.order_key.target);
    }
}

fn expectDuplicateMultiPassCaveatMerge(candidates: anytype) !void {
    try std.testing.expect(candidates.len > 0);

    var merged: std.ArrayList([]const u8) = .empty;
    defer merged.deinit(std.testing.allocator);

    // Admission coverage for duplicate relation evidence from separate passes:
    // a future provider may emit the same relation identity more than once, but
    // caveats must merge once, in first-seen order, without depending on a
    // particular language lane to manufacture duplicate syntax naturally.
    try mergeCaveatPass(&merged, candidates[0].caveats);
    const base_len = merged.items.len;
    try mergeCaveatPass(&merged, &.{ "conformance first pass caveat", "conformance shared caveat" });
    try mergeCaveatPass(&merged, candidates[0].caveats);
    try mergeCaveatPass(&merged, &.{ "conformance shared caveat", "conformance second pass caveat" });

    try std.testing.expectEqual(base_len + 3, merged.items.len);
    try std.testing.expectEqualStrings("conformance first pass caveat", merged.items[base_len]);
    try std.testing.expectEqualStrings("conformance shared caveat", merged.items[base_len + 1]);
    try std.testing.expectEqualStrings("conformance second pass caveat", merged.items[base_len + 2]);
}

fn mergeCaveatPass(merged: *std.ArrayList([]const u8), caveats: []const []const u8) !void {
    for (caveats) |caveat| {
        for (merged.items) |existing| {
            if (std.mem.eql(u8, existing, caveat)) break;
        } else {
            try merged.append(std.testing.allocator, caveat);
        }
    }
}

fn compareOrderKey(lhs: anytype, rhs: anytype) std.math.Order {
    inline for (.{
        std.mem.order(u8, lhs.order_key.path, rhs.order_key.path),
        compareU64(lhs.order_key.start_byte, rhs.order_key.start_byte),
        compareU64(lhs.order_key.end_byte, rhs.order_key.end_byte),
        std.mem.order(u8, lhs.order_key.relation, rhs.order_key.relation),
        std.mem.order(u8, lhs.order_key.target, rhs.order_key.target),
    }) |order| {
        if (order != .eq) return order;
    }
    return .eq;
}

fn compareU64(lhs: u64, rhs: u64) std.math.Order {
    if (lhs < rhs) return .lt;
    if (lhs > rhs) return .gt;
    return .eq;
}

fn expectPrivateSafeProvider(provider: anytype) !void {
    try expectPrivateSafeText(provider.name);
    try expectPrivateSafeText(provider.version);
    try expectPrivateSafeText(provider.contract_version);
    if (provider.config_fingerprint) |fingerprint| try expectPrivateSafeText(fingerprint);
    try expectPrivateSafeText(provider.input.identity);
    try expectPrivateSafeText(provider.provenance.provider_name);
    try expectPrivateSafeText(provider.provenance.input_identity);
    for (provider.caveats) |caveat| try expectPrivateSafeText(caveat);
}

fn expectPrivateSafeCandidate(candidate: anytype) !void {
    try expectPrivateSafeEndpoint(candidate.source);
    try expectPrivateSafeEndpoint(candidate.target);
    try expectPrivateSafeText(candidate.evidence_basis);
    try expectPrivateSafeText(candidate.order_key.path);
    try expectPrivateSafeText(candidate.order_key.relation);
    try expectPrivateSafeText(candidate.order_key.target);
    for (candidate.caveats) |caveat| try expectPrivateSafeText(caveat);
}

fn expectPrivateSafeEndpoint(endpoint: anytype) !void {
    switch (endpoint) {
        .file => |file| try expectSafeRelativePath(file.path),
        .current_symbol => |symbol| {
            try expectSafeRelativePath(symbol.path);
            try expectPrivateSafeText(symbol.name);
        },
        .report_symbol => |symbol| {
            try expectSafeRelativePath(symbol.path);
            try expectPrivateSafeText(symbol.name);
        },
        .unresolved, .external_string => |named| try expectPrivateSafeText(named.value),
    }
}

fn expectSafeRelativePath(path: []const u8) !void {
    try expectPrivateSafeText(path);
    try std.testing.expect(path.len > 0);
    try std.testing.expect(!std.fs.path.isAbsolute(path));
    try std.testing.expect(path[0] != '\\');
    try std.testing.expect(!(path.len >= 2 and std.ascii.isAlphabetic(path[0]) and path[1] == ':'));
    var segments = std.mem.splitScalar(u8, path, '/');
    while (segments.next()) |segment| try std.testing.expect(!std.mem.eql(u8, segment, ".."));
}

fn expectPrivateSafeText(text: []const u8) !void {
    const forbidden = [_][]const u8{
        "/home/",
        "/Users/",
        "C:\\",
        "\\\\",
        "git@",
        "fixture@example",
        "Fixture Author",
        "raw private report",
        "commit message:",
    };
    for (forbidden) |needle| try std.testing.expect(std.mem.indexOf(u8, text, needle) == null);
    if (std.mem.indexOf(u8, text, "://")) |scheme_end| {
        const prefix = text[0..scheme_end];
        try std.testing.expect(!std.mem.endsWith(u8, prefix, "http"));
        try std.testing.expect(!std.mem.endsWith(u8, prefix, "https"));
    }
}

fn expectCaveat(caveats: anytype, expected: []const u8) !void {
    for (caveats) |caveat| if (std.mem.eql(u8, caveat, expected)) return;
    return error.ExpectedCaveatMissing;
}

test "relation provider conformance covers Python" {
    const source =
        \\import os.path
        \\from pkg.tools import worker
        \\
        \\CONSTANT = 1
        \\def helper():
        \\    return CONSTANT
        \\class Outer:
        \\    def method(self):
        \\        missing_value
        \\        registry.dynamic
        \\        return helper()
        \\
    ;
    try runSupportedConformance(PythonLane, .{
        .path = "pkg/relations.py",
        .source = source,
        .expected_provider_name = tree_sitter_python.relation_provider_name,
        .expected_kinds = &.{ "contains", "reference", "call", "import_include", "unresolved", "unknown" },
        .expected_targets = &.{ "helper", "Outer", "CONSTANT", "helper", "os.path", "pkg.tools", "missing_value", "registry.dynamic" },
    });
    try runDegradedConformance(PythonLane, .{
        .unsupported_path = "docs/relations.md",
        .valid_source = source,
        .invalid_path = "pkg/broken.py",
        .invalid_source = "def broken(:\n    pass\n",
    });
}

test "relation provider conformance covers internal Go proof" {
    const source =
        \\package proof
        \\
        \\import (
        \\    alias "example.com/worker"
        \\    . "example.com/dot"
        \\    _ "example.com/blank"
        \\    "example.com/plain"
        \\)
        \\
        \\const LIMIT = 3
        \\
        \\type Service struct{}
        \\type Runner interface{ Run() }
        \\
        \\func helper() {}
        \\func (s Service) Serve() {
        \\    helper()
        \\    LIMIT
        \\    missingValue
        \\    alias.Make()
        \\    receiver.Field
        \\}
        \\
    ;
    try runSupportedConformance(GoLane, .{
        .path = "internal/relations.go",
        .source = source,
        .expected_provider_name = tree_sitter_go.relation_provider_name,
        .expected_kinds = &.{ "contains", "reference", "call", "import_include", "unresolved", "unknown" },
        .expected_targets = &.{ "LIMIT", "Service", "Runner", "helper", "Serve", "example.com/worker", "example.com/dot", "example.com/blank", "example.com/plain", "helper", "missingValue", "alias.Make", "receiver.Field" },
    });
    try runDegradedConformance(GoLane, .{
        .unsupported_path = "docs/relations.md",
        .valid_source = source,
        .invalid_path = "internal/broken.go",
        .invalid_source = "package proof\nfunc {",
    });
}

test "relation provider conformance covers JavaScript" {
    const source =
        \\import helperDefault from "./helper.js";
        \\const localValue = 1;
        \\function helper(input) {
        \\  return localValue + input;
        \\}
        \\class Worker {
        \\  run() {
        \\    helper(localValue);
        \\    missingValue;
        \\    missingCall();
        \\    this.dynamic[localValue]();
        \\  }
        \\}
        \\const loaded = require("legacy-lib");
        \\import("dynamic-lib");
        \\
    ;
    try runSupportedConformance(JavaScriptLane, .{
        .path = "packages/app/src/relations.mjs",
        .source = source,
        .expected_provider_name = tree_sitter_javascript.relation_provider_name,
        .expected_kinds = &.{ "contains", "reference", "call", "import_include", "unresolved", "unknown" },
        .expected_targets = &.{ "helper", "Worker", "run", "localValue", "helper", "missingValue", "missingCall", "./helper.js", "legacy-lib", "dynamic-lib", "this.dynamic[localValue]" },
    });
    try runDegradedConformance(JavaScriptLane, .{
        .unsupported_path = "packages/app/src/unsupported.ts",
        .valid_source = source,
        .invalid_path = "packages/app/src/broken.mjs",
        .invalid_source = "export function broken(\n",
    });
}

test "relation provider conformance covers TypeScript" {
    const source =
        \\import { externalThing } from "./external";
        \\type UserId = string;
        \\interface UserShape { id: UserId }
        \\const localValue = 1;
        \\function helper(input: UserId) {
        \\  return localValue;
        \\}
        \\class Worker {
        \\  run(): UserId {
        \\    helper(localValue);
        \\    missingValue;
        \\    missingCall();
        \\    this.dynamic[localValue]();
        \\    return "ok";
        \\  }
        \\}
        \\const loaded = require("legacy-lib");
        \\import("dynamic-lib");
        \\
    ;
    try runSupportedConformance(TypeScriptLane, .{
        .path = "packages/app/src/relations.ts",
        .source = source,
        .expected_provider_name = tree_sitter_typescript.typescript_relation_provider_name,
        .expected_kinds = &.{ "contains", "reference", "call", "import_include", "unresolved", "unknown" },
        .expected_targets = &.{ "UserId", "helper", "Worker", "run", "localValue", "helper", "missingValue", "missingCall", "./external", "legacy-lib", "dynamic-lib" },
    });
    try runDegradedConformance(TypeScriptLane, .{
        .unsupported_path = "packages/app/src/unsupported.js",
        .valid_source = source,
        .invalid_path = "packages/app/src/broken.ts",
        .invalid_source = "export function broken(\n",
    });
}

test "relation provider conformance covers TSX" {
    const source =
        \\type Props = { title: string };
        \\const fallbackTitle = "fallback";
        \\export function Panel(props: Props) {
        \\  missingValue;
        \\  return <section>{props.title || fallbackTitle}</section>;
        \\}
        \\
    ;
    try runSupportedConformance(TypeScriptLane, .{
        .path = "packages/app/src/component.tsx",
        .source = source,
        .expected_provider_name = tree_sitter_typescript.tsx_relation_provider_name,
        .expected_kinds = &.{ "contains", "reference", "unresolved", "unknown" },
        .expected_targets = &.{ "Props", "fallbackTitle", "Panel", "missingValue" },
    });
}

test "relation provider conformance covers Rust" {
    const source =
        \\use crate::tools::worker;
        \\mod external;
        \\const LIMIT: usize = 3;
        \\fn helper() {}
        \\fn caller() {
        \\    helper();
        \\    LIMIT;
        \\    missing_value;
        \\    receiver.method();
        \\}
        \\make_item!(Generated);
        \\
    ;
    try runSupportedConformance(RustLane, .{
        .path = "crates/demo/src/relations.rs",
        .source = source,
        .expected_provider_name = tree_sitter_rust.relation_provider_name,
        .expected_kinds = &.{ "contains", "reference", "call", "import_include", "unresolved", "unknown" },
        .expected_targets = &.{ "LIMIT", "helper", "caller", "crate::tools::worker", "external", "helper", "make_item", "missing_value", "receiver.method" },
    });
    try runDegradedConformance(RustLane, .{
        .unsupported_path = "docs/relations.md",
        .valid_source = source,
        .invalid_path = "crates/demo/src/broken.rs",
        .invalid_source = "fn broken(",
    });
}
