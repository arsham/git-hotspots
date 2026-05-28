const std = @import("std");
const model = @import("model.zig");

pub const usage =
    \\git-hotspots: deterministic local Git-history hotspot prompts
    \\
    \\Usage:
    \\  git-hotspots [OPTIONS]
    \\  git-hotspots --explain
    \\  git-hotspots --version
    \\  git-hotspots --help | -h
    \\
    \\Repository and output:
    \\  --repo PATH       Local Git worktree to analyse (default: .)
    \\  --limit N         Maximum ranked files to emit (default: 10)
    \\  --format FORMAT   table, json, or markdown (default: table)
    \\  --since REV       Analyse commits after REV through HEAD
    \\  --progress        Write opt-in coarse analysis progress to stderr
    \\
    \\Scope and filters:
    \\  --scope VALUE     project (default) or all; project excludes the literal
    \\                    repo-root prefixes .flow/, .zig-cache/, zig-out/,
    \\                    target/, node_modules/, dist/, build/, and coverage/
    \\                    before scoring; all uses the full local Git-history
    \\                    evidence universe
    \\  --include-prefix PATH
    \\                    Repeatable repo-relative literal Git path prefix to include;
    \\                    narrows the evidence universe before scoring; not a glob
    \\  --exclude-prefix PATH
    \\                    Repeatable repo-relative literal Git path prefix to exclude
    \\                    before scoring; use / separators, not globs
    \\
    \\Inspect and provider evidence:
    \\  --inspect PATH    Exact repo-relative file drilldown; selects one file after
    \\                    scoring and ranking, before normal --limit truncation;
    \\                    accepted in-scope Git rename aliases may resolve to the
    \\                    canonical path; use \\t to target a tab in a Git path
    \\  --symbols         Add opt-in current working-tree Tree-sitter Zig, Go,
    \\                    Python, JavaScript, Lua, Rust, TypeScript, or TSX
    \\                    symbols for retained ranked files, or one inspected file;
    \\                    Rust covers .rs; JavaScript covers .js, .mjs, .cjs, and
    \\                    admitted .jsx; Lua covers .lua; TypeScript/TSX covers
    \\                    .ts, .mts, .cts, and .tsx;
    \\                    does not affect score, rank, lineage, confidence, or
    \\                    file-level evidence
    \\  --symbol-line-history
    \\                    With --symbols, add opt-in current-line
    \\                    Git evidence for current Zig, Go, Python, JavaScript,
    \\                    Lua, Rust, TypeScript, or TSX symbol line ranges at HEAD; not true
    \\                    symbol history, lineage, scoring, or ownership
    \\  --historical-symbols
    \\                    With --symbols, add opt-in true historical hunk attribution
    \\                    for retained ranked-file candidates; separate from current
    \\                    working-tree symbols and current-line HEAD evidence; does not
    \\                    affect score, rank, lineage, confidence, or file-level evidence
    \\  --symbol-relationships
    \\                    With --symbols, add opt-in bounded local relation evidence for
    \\                    retained ranked-file candidates; caveated investigation
    \\                    context only, not call-graph truth, dependency proof,
    \\                    scoring, ownership, developer metrics, or bug prediction
    \\  --symbol-limit N  With --symbols, limit human table and
    \\                    Markdown current, historical, and relationship rows
    \\                    (default: 25); JSON item arrays remain complete within
    \\                    internal bounds
    \\
    \\Standalone help:
    \\  --explain         Explain current scoring semantics without analysing a repo
    \\  --version         Show the git-hotspots version without analysing a repo
    \\  -h, --help        Show this help without analysing a repo
    \\
    \\Examples:
    \\  git-hotspots --repo . --limit 10 --format table
    \\  git-hotspots --repo . --scope project --since HEAD~500 --progress --format markdown
    \\  git-hotspots --repo . --limit 5 --symbols --format markdown
    \\  git-hotspots --repo . --limit 5 --symbols --historical-symbols --format markdown
    \\  git-hotspots --repo . --limit 5 --symbols --symbol-relationships --format markdown
    \\  git-hotspots --repo . --inspect src/main.zig --symbols --format markdown
    \\  git-hotspots --explain
    \\
    \\Diagnostics:
    \\  Invalid CLI combinations exit 2 with concise stderr diagnostics and, when
    \\  deterministic, a valid next command shape. For symbol evidence, use:
    \\  git-hotspots --repo . --symbols
    \\
    \\Local-first/no-telemetry boundaries:
    \\  Hotspots are investigation prompts from deterministic local Git history,
    \\  not bug predictions, developer rankings, or objective code-quality scores.
    \\  This alpha never fetches, pushes, uploads source, contacts remotes, or
    \\  emits telemetry. Git-detected file renames are folded conservatively when
    \\  in scope; this is not symbol/function lineage or semantic ownership.
    \\
    \\Provider capability:
    \\  --symbols is opt-in current working-tree symbol evidence for retained
    \\  ranked files, or for one inspected file when --inspect PATH is present.
    \\  Supported lanes are Zig (.zig), Go (.go), Python (.py), JavaScript (.js/.mjs/.cjs/.jsx),
    \\  Lua (.lua), Rust (.rs), TypeScript (.ts/.mts/.cts), and TSX (.tsx).
    \\  Other ranked current files are counted as unsupported while preserving file evidence.
    \\  Rust support is current syntax evidence only: no Cargo, crates, module
    \\  resolution, macro expansion, cfg/feature evaluation, type checking,
    \\  dependency graphs, or semantic Rust analysis.
    \\  --symbol-line-history adds current-line Git evidence for HEAD symbol
    \\  ranges only; it is not true symbol history, lineage, scoring, or ownership.
    \\  --historical-symbols adds true historical hunk attribution for retained
    \\  ranked-file candidates only; it is not semantic lineage, reference/use
    \\  analysis, ownership, bug prediction, scoring replacement, or ranking input.
    \\  --symbol-relationships adds bounded local relation evidence for retained
    \\  ranked-file candidates in Python, JavaScript, Rust, TypeScript, and TSX
    \\  lanes only; it is caveated syntax/provider evidence, not
    \\  call-graph truth, dependency proof, scoring replacement, ownership,
    \\  developer metrics, or bug prediction.
    \\
;

pub const CliMode = union(enum) {
    analyze: model.Config,
    explain,
    version,
};

pub const CliError = error{
    HelpRequested,
    InvalidArguments,
    InvalidExplainCombination,
    InvalidVersionCombination,
    MissingRepoValue,
    MissingLimitValue,
    InvalidLimit,
    MissingFormatValue,
    InvalidFormat,
    MissingSinceValue,
    MissingIncludePrefixValue,
    MissingExcludePrefixValue,
    MissingInspectValue,
    UnknownOption,
    UnexpectedArgument,
    InvalidIncludePrefix,
    InvalidExcludePrefix,
    InvalidInspectPath,
    InvalidInspectLimitCombination,
    InvalidSymbolsCombination,
    InvalidSymbolLineHistoryCombination,
    InvalidHistoricalSymbolsCombination,
    InvalidSymbolRelationshipsCombination,
    InvalidSymbolLimitCombination,
    InvalidSymbolLimit,
    InvalidScope,
} || std.mem.Allocator.Error;

pub fn parseArgs(allocator: std.mem.Allocator, args: []const [:0]const u8) CliError!CliMode {
    var cfg = model.Config{ .repo_path = try allocator.dupe(u8, ".") };
    errdefer freeConfig(allocator, cfg);

    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) return error.HelpRequested;
    }

    var explain_requested = false;
    var version_requested = false;
    var analysis_flag_seen = false;
    var limit_seen = false;
    var scope_seen = false;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) return error.HelpRequested;
        if (std.mem.eql(u8, arg, "--explain")) {
            if (version_requested) return error.InvalidVersionCombination;
            explain_requested = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--version")) {
            if (explain_requested) return error.InvalidVersionCombination;
            version_requested = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--progress")) {
            analysis_flag_seen = true;
            if (explain_requested) return error.InvalidExplainCombination;
            if (version_requested) return error.InvalidVersionCombination;
            cfg.progress = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--symbols")) {
            analysis_flag_seen = true;
            if (explain_requested) return error.InvalidExplainCombination;
            if (version_requested) return error.InvalidVersionCombination;
            cfg.symbols = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--symbol-line-history")) {
            analysis_flag_seen = true;
            if (explain_requested) return error.InvalidExplainCombination;
            if (version_requested) return error.InvalidVersionCombination;
            cfg.symbol_line_history = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--historical-symbols")) {
            analysis_flag_seen = true;
            if (explain_requested) return error.InvalidExplainCombination;
            if (version_requested) return error.InvalidVersionCombination;
            cfg.historical_symbols = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--symbol-relationships")) {
            analysis_flag_seen = true;
            if (explain_requested) return error.InvalidExplainCombination;
            if (version_requested) return error.InvalidVersionCombination;
            cfg.symbol_relationships = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--symbol-limit")) {
            analysis_flag_seen = true;
            if (explain_requested) return error.InvalidExplainCombination;
            if (version_requested) return error.InvalidVersionCombination;
            i += 1;
            if (i >= args.len) return error.InvalidSymbolLimit;
            cfg.symbol_limit = std.fmt.parseInt(usize, args[i], 10) catch return error.InvalidSymbolLimit;
            if (cfg.symbol_limit.? == 0) return error.InvalidSymbolLimit;
            continue;
        }
        if (std.mem.eql(u8, arg, "--repo")) {
            analysis_flag_seen = true;
            if (explain_requested) return error.InvalidExplainCombination;
            if (version_requested) return error.InvalidVersionCombination;
            i += 1;
            if (i >= args.len) return error.MissingRepoValue;
            const v = args[i];
            allocator.free(cfg.repo_path);
            cfg.repo_path = try allocator.dupe(u8, v);
        } else if (std.mem.eql(u8, arg, "--limit")) {
            analysis_flag_seen = true;
            if (explain_requested) return error.InvalidExplainCombination;
            if (version_requested) return error.InvalidVersionCombination;
            i += 1;
            if (i >= args.len) return error.MissingLimitValue;
            const v = args[i];
            limit_seen = true;
            cfg.limit = std.fmt.parseInt(usize, v, 10) catch return error.InvalidLimit;
        } else if (std.mem.eql(u8, arg, "--format")) {
            analysis_flag_seen = true;
            if (explain_requested) return error.InvalidExplainCombination;
            if (version_requested) return error.InvalidVersionCombination;
            i += 1;
            if (i >= args.len) return error.MissingFormatValue;
            const v = args[i];
            if (std.mem.eql(u8, v, "table")) cfg.format = .table else if (std.mem.eql(u8, v, "json")) cfg.format = .json else if (std.mem.eql(u8, v, "markdown")) cfg.format = .markdown else return error.InvalidFormat;
        } else if (std.mem.eql(u8, arg, "--since")) {
            analysis_flag_seen = true;
            if (explain_requested) return error.InvalidExplainCombination;
            if (version_requested) return error.InvalidVersionCombination;
            i += 1;
            if (i >= args.len) return error.MissingSinceValue;
            const v = args[i];
            if (cfg.since) |old| allocator.free(old);
            cfg.since = try allocator.dupe(u8, v);
        } else if (std.mem.eql(u8, arg, "--scope")) {
            analysis_flag_seen = true;
            if (explain_requested) return error.InvalidExplainCombination;
            if (version_requested) return error.InvalidVersionCombination;
            if (scope_seen) return error.InvalidScope;
            scope_seen = true;
            i += 1;
            if (i >= args.len) return error.InvalidScope;
            const v = args[i];
            if (std.mem.eql(u8, v, "all")) cfg.scope = .all else if (std.mem.eql(u8, v, "project")) cfg.scope = .project else return error.InvalidScope;
        } else if (std.mem.eql(u8, arg, "--include-prefix")) {
            analysis_flag_seen = true;
            if (explain_requested) return error.InvalidExplainCombination;
            if (version_requested) return error.InvalidVersionCombination;
            i += 1;
            if (i >= args.len) return error.MissingIncludePrefixValue;
            try appendIncludePrefix(allocator, &cfg, args[i]);
        } else if (std.mem.eql(u8, arg, "--exclude-prefix")) {
            analysis_flag_seen = true;
            if (explain_requested) return error.InvalidExplainCombination;
            if (version_requested) return error.InvalidVersionCombination;
            i += 1;
            if (i >= args.len) return error.MissingExcludePrefixValue;
            try appendExcludePrefix(allocator, &cfg, args[i]);
        } else if (std.mem.eql(u8, arg, "--inspect")) {
            analysis_flag_seen = true;
            if (explain_requested) return error.InvalidExplainCombination;
            if (version_requested) return error.InvalidVersionCombination;
            i += 1;
            if (i >= args.len) return error.MissingInspectValue;
            if (cfg.inspect_path) |old| allocator.free(old);
            cfg.inspect_path = normalizeInspectPath(allocator, args[i]) catch |err| switch (err) {
                error.InvalidPrefix => return error.InvalidInspectPath,
                error.OutOfMemory => return error.OutOfMemory,
            };
        } else if (std.mem.startsWith(u8, arg, "-")) return error.UnknownOption else return error.UnexpectedArgument;
    }
    if (explain_requested) {
        if (analysis_flag_seen) return error.InvalidExplainCombination;
        freeConfig(allocator, cfg);
        return .explain;
    }
    if (version_requested) {
        if (analysis_flag_seen or explain_requested) return error.InvalidVersionCombination;
        freeConfig(allocator, cfg);
        return .version;
    }
    if (cfg.limit == 0) return error.InvalidLimit;
    if (cfg.inspect_path != null and limit_seen) return error.InvalidInspectLimitCombination;
    if (cfg.symbol_line_history and !cfg.symbols) return error.InvalidSymbolLineHistoryCombination;
    if (cfg.historical_symbols and !cfg.symbols) return error.InvalidHistoricalSymbolsCombination;
    if (cfg.symbol_relationships and !cfg.symbols) return error.InvalidSymbolRelationshipsCombination;
    if (cfg.symbol_limit != null and !cfg.symbols) return error.InvalidSymbolLimitCombination;
    try applyScopePreset(allocator, &cfg);
    return .{ .analyze = cfg };
}

pub fn freeConfig(allocator: std.mem.Allocator, cfg: model.Config) void {
    allocator.free(cfg.repo_path);
    if (cfg.since) |s| allocator.free(s);
    if (cfg.inspect_path) |p| allocator.free(p);
    for (cfg.include_prefixes) |prefix| allocator.free(prefix);
    if (cfg.include_prefixes.len > 0) allocator.free(cfg.include_prefixes);
    for (cfg.exclude_prefixes) |prefix| allocator.free(prefix);
    if (cfg.exclude_prefixes.len > 0) allocator.free(cfg.exclude_prefixes);
}

fn normalizeInspectPath(allocator: std.mem.Allocator, raw: []const u8) PrefixError![]const u8 {
    var path = raw;
    while (std.mem.startsWith(u8, path, "./")) path = path[2..];
    if (path.len == 0) return error.InvalidPrefix;
    if (std.fs.path.isAbsolute(path) or path[0] == '\\') return error.InvalidPrefix;
    if (path.len >= 2 and std.ascii.isAlphabetic(path[0]) and path[1] == ':') return error.InvalidPrefix;
    for (path) |c| if (c < 0x20 or c == 0x7f) return error.InvalidPrefix;

    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();
    var i: usize = 0;
    while (i < path.len) {
        const c = path[i];
        i += 1;
        if (c == '\\' and i < path.len and path[i] == 't') {
            try out.append('\t');
            i += 1;
        } else {
            try out.append(c);
        }
    }

    const normalized = try out.toOwnedSlice();
    errdefer allocator.free(normalized);
    if (normalized.len == 0) return error.InvalidPrefix;
    if (std.fs.path.isAbsolute(normalized) or normalized[0] == '\\') return error.InvalidPrefix;
    if (normalized.len >= 2 and std.ascii.isAlphabetic(normalized[0]) and normalized[1] == ':') return error.InvalidPrefix;

    var segments = std.mem.splitScalar(u8, normalized, '/');
    while (segments.next()) |segment| {
        if (std.mem.eql(u8, segment, "..")) return error.InvalidPrefix;
    }
    return normalized;
}

fn appendIncludePrefix(allocator: std.mem.Allocator, cfg: *model.Config, raw: []const u8) CliError!void {
    const normalized = normalizePrefix(allocator, raw) catch |err| switch (err) {
        error.InvalidPrefix => return error.InvalidIncludePrefix,
        error.OutOfMemory => return error.OutOfMemory,
    };
    errdefer allocator.free(normalized);

    const expanded = try allocator.alloc([]const u8, cfg.include_prefixes.len + 1);
    @memcpy(expanded[0..cfg.include_prefixes.len], cfg.include_prefixes);
    expanded[cfg.include_prefixes.len] = normalized;
    if (cfg.include_prefixes.len > 0) allocator.free(cfg.include_prefixes);
    cfg.include_prefixes = expanded;
}

fn appendExcludePrefix(allocator: std.mem.Allocator, cfg: *model.Config, raw: []const u8) CliError!void {
    const normalized = normalizePrefix(allocator, raw) catch |err| switch (err) {
        error.InvalidPrefix => return error.InvalidExcludePrefix,
        error.OutOfMemory => return error.OutOfMemory,
    };
    errdefer allocator.free(normalized);

    const expanded = try allocator.alloc([]const u8, cfg.exclude_prefixes.len + 1);
    @memcpy(expanded[0..cfg.exclude_prefixes.len], cfg.exclude_prefixes);
    expanded[cfg.exclude_prefixes.len] = normalized;
    if (cfg.exclude_prefixes.len > 0) allocator.free(cfg.exclude_prefixes);
    cfg.exclude_prefixes = expanded;
}

fn applyScopePreset(allocator: std.mem.Allocator, cfg: *model.Config) CliError!void {
    switch (cfg.scope) {
        .all => {},
        .project => try applyProjectScopePreset(allocator, cfg),
    }
}

fn applyProjectScopePreset(allocator: std.mem.Allocator, cfg: *model.Config) CliError!void {
    const project_prefixes = [_][]const u8{ ".flow/", ".zig-cache/", "zig-out/", "target/", "node_modules/", "dist/", "build/", "coverage/" };
    var duplicate_count: usize = 0;
    for (cfg.exclude_prefixes) |existing| {
        if (containsString(project_prefixes[0..], existing)) duplicate_count += 1;
    }

    const expanded = try allocator.alloc([]const u8, cfg.exclude_prefixes.len - duplicate_count + project_prefixes.len);
    errdefer allocator.free(expanded);
    var out_i: usize = 0;
    errdefer for (expanded[0..out_i]) |owned| allocator.free(owned);
    for (project_prefixes) |project_prefix| {
        expanded[out_i] = try allocator.dupe(u8, project_prefix);
        out_i += 1;
    }
    for (cfg.exclude_prefixes) |existing| {
        if (containsString(project_prefixes[0..], existing)) {
            allocator.free(existing);
        } else {
            expanded[out_i] = existing;
            out_i += 1;
        }
    }
    if (cfg.exclude_prefixes.len > 0) allocator.free(cfg.exclude_prefixes);
    cfg.exclude_prefixes = expanded;
}

fn containsString(haystack: []const []const u8, needle: []const u8) bool {
    for (haystack) |value| {
        if (std.mem.eql(u8, value, needle)) return true;
    }
    return false;
}

const PrefixError = error{InvalidPrefix} || std.mem.Allocator.Error;

fn normalizePrefix(allocator: std.mem.Allocator, raw: []const u8) PrefixError![]const u8 {
    var prefix = raw;
    while (std.mem.startsWith(u8, prefix, "./")) prefix = prefix[2..];
    if (prefix.len == 0) return error.InvalidPrefix;
    if (std.fs.path.isAbsolute(prefix) or prefix[0] == '\\') return error.InvalidPrefix;
    if (prefix.len >= 2 and std.ascii.isAlphabetic(prefix[0]) and prefix[1] == ':') return error.InvalidPrefix;
    for (prefix) |c| if (c < 0x20 or c == 0x7f) return error.InvalidPrefix;

    var segments = std.mem.splitScalar(u8, prefix, '/');
    while (segments.next()) |segment| {
        if (std.mem.eql(u8, segment, "..")) return error.InvalidPrefix;
    }
    return allocator.dupe(u8, prefix);
}

test "parse defaults are documented through config shape" {
    const cfg = model.Config{ .repo_path = "." };
    try std.testing.expectEqual(@as(usize, 10), cfg.limit);
    try std.testing.expectEqual(model.Format.table, cfg.format);
    try std.testing.expectEqual(model.ScopePreset.project, cfg.scope);
    try std.testing.expect(!cfg.progress);
    try std.testing.expect(!cfg.symbols);
    try std.testing.expect(!cfg.symbol_line_history);
    try std.testing.expect(!cfg.historical_symbols);
    try std.testing.expect(!cfg.symbol_relationships);
    try std.testing.expectEqual(@as(?usize, null), cfg.symbol_limit);
}

test "parse omitted scope defaults to project preset" {
    const args = [_][:0]const u8{"git-hotspots"};
    const mode = try parseArgs(std.testing.allocator, &args);
    const cfg = mode.analyze;
    defer freeConfig(std.testing.allocator, cfg);
    try std.testing.expectEqual(model.ScopePreset.project, cfg.scope);
    try expectProjectScopePrefixes(cfg.exclude_prefixes);
}

test "parse progress analysis flag independent of order" {
    const before_args = [_][:0]const u8{ "git-hotspots", "--progress", "--repo", "fixtures/basic", "--format", "json" };
    const before_mode = try parseArgs(std.testing.allocator, &before_args);
    const before_cfg = before_mode.analyze;
    defer freeConfig(std.testing.allocator, before_cfg);
    try std.testing.expect(before_cfg.progress);
    try std.testing.expectEqual(model.Format.json, before_cfg.format);
    try std.testing.expectEqualStrings("fixtures/basic", before_cfg.repo_path);

    const after_args = [_][:0]const u8{ "git-hotspots", "--repo", "fixtures/basic", "--format", "markdown", "--progress" };
    const after_mode = try parseArgs(std.testing.allocator, &after_args);
    const after_cfg = after_mode.analyze;
    defer freeConfig(std.testing.allocator, after_cfg);
    try std.testing.expect(after_cfg.progress);
    try std.testing.expectEqual(model.Format.markdown, after_cfg.format);
}

test "parse standalone explain mode" {
    const args = [_][:0]const u8{ "git-hotspots", "--explain" };
    const mode = try parseArgs(std.testing.allocator, &args);
    try std.testing.expectEqual(std.meta.Tag(CliMode).explain, mode);
}

test "parse standalone version mode" {
    const args = [_][:0]const u8{ "git-hotspots", "--version" };
    const mode = try parseArgs(std.testing.allocator, &args);
    try std.testing.expectEqual(std.meta.Tag(CliMode).version, mode);
}

test "parse help has high precedence independent of order" {
    const cases = [_][]const [:0]const u8{
        &[_][:0]const u8{ "git-hotspots", "--symbols", "--help" },
        &[_][:0]const u8{ "git-hotspots", "--help", "--symbols" },
        &[_][:0]const u8{ "git-hotspots", "--historical-symbols", "--help" },
        &[_][:0]const u8{ "git-hotspots", "--symbol-relationships", "--help" },
        &[_][:0]const u8{ "git-hotspots", "--repo", "--help" },
        &[_][:0]const u8{ "git-hotspots", "--format", "--help" },
        &[_][:0]const u8{ "git-hotspots", "-h", "--symbol-limit", "0" },
    };
    for (cases) |args| try std.testing.expectError(error.HelpRequested, parseArgs(std.testing.allocator, args));
}

test "reject explain combined with analysis flags" {
    const cases = [_][]const [:0]const u8{
        &[_][:0]const u8{ "git-hotspots", "--explain", "--repo", "." },
        &[_][:0]const u8{ "git-hotspots", "--repo", ".", "--explain" },
        &[_][:0]const u8{ "git-hotspots", "--explain", "--limit", "1" },
        &[_][:0]const u8{ "git-hotspots", "--explain", "--format", "markdown" },
        &[_][:0]const u8{ "git-hotspots", "--explain", "--since", "HEAD~1" },
        &[_][:0]const u8{ "git-hotspots", "--explain", "--scope", "project" },
        &[_][:0]const u8{ "git-hotspots", "--explain", "--include-prefix", "src/" },
        &[_][:0]const u8{ "git-hotspots", "--explain", "--exclude-prefix", ".flow/" },
        &[_][:0]const u8{ "git-hotspots", "--explain", "--inspect", "src/app.zig" },
        &[_][:0]const u8{ "git-hotspots", "--inspect", "src/app.zig", "--explain" },
        &[_][:0]const u8{ "git-hotspots", "--explain", "--progress" },
        &[_][:0]const u8{ "git-hotspots", "--progress", "--explain" },
        &[_][:0]const u8{ "git-hotspots", "--explain", "--symbols" },
        &[_][:0]const u8{ "git-hotspots", "--symbols", "--explain" },
        &[_][:0]const u8{ "git-hotspots", "--explain", "--historical-symbols" },
        &[_][:0]const u8{ "git-hotspots", "--historical-symbols", "--explain" },
        &[_][:0]const u8{ "git-hotspots", "--explain", "--symbol-relationships" },
        &[_][:0]const u8{ "git-hotspots", "--symbol-relationships", "--explain" },
        &[_][:0]const u8{ "git-hotspots", "--explain", "--symbol-limit", "1" },
        &[_][:0]const u8{ "git-hotspots", "--symbol-limit", "1", "--explain" },
    };
    for (cases) |args| try std.testing.expectError(error.InvalidExplainCombination, parseArgs(std.testing.allocator, args));
}

test "reject version combined with analysis flags" {
    const cases = [_][]const [:0]const u8{
        &[_][:0]const u8{ "git-hotspots", "--version", "--repo", "." },
        &[_][:0]const u8{ "git-hotspots", "--repo", ".", "--version" },
        &[_][:0]const u8{ "git-hotspots", "--version", "--limit", "1" },
        &[_][:0]const u8{ "git-hotspots", "--version", "--format", "markdown" },
        &[_][:0]const u8{ "git-hotspots", "--version", "--since", "HEAD~1" },
        &[_][:0]const u8{ "git-hotspots", "--version", "--scope", "project" },
        &[_][:0]const u8{ "git-hotspots", "--version", "--include-prefix", "src/" },
        &[_][:0]const u8{ "git-hotspots", "--version", "--exclude-prefix", ".flow/" },
        &[_][:0]const u8{ "git-hotspots", "--version", "--explain" },
        &[_][:0]const u8{ "git-hotspots", "--version", "--inspect", "src/app.zig" },
        &[_][:0]const u8{ "git-hotspots", "--inspect", "src/app.zig", "--version" },
        &[_][:0]const u8{ "git-hotspots", "--version", "--progress" },
        &[_][:0]const u8{ "git-hotspots", "--progress", "--version" },
        &[_][:0]const u8{ "git-hotspots", "--version", "--symbols" },
        &[_][:0]const u8{ "git-hotspots", "--symbols", "--version" },
        &[_][:0]const u8{ "git-hotspots", "--version", "--historical-symbols" },
        &[_][:0]const u8{ "git-hotspots", "--historical-symbols", "--version" },
        &[_][:0]const u8{ "git-hotspots", "--version", "--symbol-relationships" },
        &[_][:0]const u8{ "git-hotspots", "--symbol-relationships", "--version" },
        &[_][:0]const u8{ "git-hotspots", "--version", "--symbol-limit", "1" },
        &[_][:0]const u8{ "git-hotspots", "--symbol-limit", "1", "--version" },
    };
    for (cases) |args| try std.testing.expectError(error.InvalidVersionCombination, parseArgs(std.testing.allocator, args));
}

test "parse scope preset values" {
    const all_args = [_][:0]const u8{ "git-hotspots", "--scope", "all" };
    const all_mode = try parseArgs(std.testing.allocator, &all_args);
    const all_cfg = all_mode.analyze;
    defer freeConfig(std.testing.allocator, all_cfg);
    try std.testing.expectEqual(model.ScopePreset.all, all_cfg.scope);
    try std.testing.expectEqual(@as(usize, 0), all_cfg.exclude_prefixes.len);

    const project_args = [_][:0]const u8{ "git-hotspots", "--scope", "project" };
    const project_mode = try parseArgs(std.testing.allocator, &project_args);
    const project_cfg = project_mode.analyze;
    defer freeConfig(std.testing.allocator, project_cfg);
    try std.testing.expectEqual(model.ScopePreset.project, project_cfg.scope);
    try expectProjectScopePrefixes(project_cfg.exclude_prefixes);
}

test "reject invalid scope values" {
    const cases = [_][]const [:0]const u8{
        &[_][:0]const u8{ "git-hotspots", "--scope" },
        &[_][:0]const u8{ "git-hotspots", "--scope", "unknown" },
        &[_][:0]const u8{ "git-hotspots", "--scope", "Project" },
        &[_][:0]const u8{ "git-hotspots", "--scope", "PROJECT" },
        &[_][:0]const u8{ "git-hotspots", "--scope", "all", "--scope", "project" },
    };
    for (cases) |args| try std.testing.expectError(error.InvalidScope, parseArgs(std.testing.allocator, args));
}

test "reject parser misuse with specific errors" {
    const cases = [_]struct {
        args: []const [:0]const u8,
        expected: CliError,
    }{
        .{ .args = &[_][:0]const u8{ "git-hotspots", "--repo" }, .expected = error.MissingRepoValue },
        .{ .args = &[_][:0]const u8{ "git-hotspots", "--limit" }, .expected = error.MissingLimitValue },
        .{ .args = &[_][:0]const u8{ "git-hotspots", "--limit", "nope" }, .expected = error.InvalidLimit },
        .{ .args = &[_][:0]const u8{ "git-hotspots", "--limit", "0" }, .expected = error.InvalidLimit },
        .{ .args = &[_][:0]const u8{ "git-hotspots", "--format" }, .expected = error.MissingFormatValue },
        .{ .args = &[_][:0]const u8{ "git-hotspots", "--format", "xml" }, .expected = error.InvalidFormat },
        .{ .args = &[_][:0]const u8{ "git-hotspots", "--since" }, .expected = error.MissingSinceValue },
        .{ .args = &[_][:0]const u8{ "git-hotspots", "--include-prefix" }, .expected = error.MissingIncludePrefixValue },
        .{ .args = &[_][:0]const u8{ "git-hotspots", "--exclude-prefix" }, .expected = error.MissingExcludePrefixValue },
        .{ .args = &[_][:0]const u8{ "git-hotspots", "--inspect" }, .expected = error.MissingInspectValue },
        .{ .args = &[_][:0]const u8{ "git-hotspots", "--unknown" }, .expected = error.UnknownOption },
        .{ .args = &[_][:0]const u8{ "git-hotspots", "fixtures/basic" }, .expected = error.UnexpectedArgument },
    };
    for (cases) |case| try std.testing.expectError(case.expected, parseArgs(std.testing.allocator, case.args));
}

test "project scope combines with prefixes independent of flag order" {
    const before_args = [_][:0]const u8{ "git-hotspots", "--scope", "project", "--include-prefix", ".flow/", "--exclude-prefix", "vendor/", "--exclude-prefix", ".flow/", "--exclude-prefix", "target/" };
    const before_mode = try parseArgs(std.testing.allocator, &before_args);
    const before_cfg = before_mode.analyze;
    defer freeConfig(std.testing.allocator, before_cfg);
    try std.testing.expectEqual(model.ScopePreset.project, before_cfg.scope);
    try std.testing.expectEqual(@as(usize, 1), before_cfg.include_prefixes.len);
    try std.testing.expectEqualStrings(".flow/", before_cfg.include_prefixes[0]);
    try std.testing.expectEqual(@as(usize, 9), before_cfg.exclude_prefixes.len);
    try expectProjectScopePrefixes(before_cfg.exclude_prefixes[0..8]);
    try std.testing.expectEqualStrings("vendor/", before_cfg.exclude_prefixes[8]);

    const after_args = [_][:0]const u8{ "git-hotspots", "--exclude-prefix", ".flow/", "--exclude-prefix", "target/", "--exclude-prefix", "vendor/", "--include-prefix", ".flow/", "--scope", "project" };
    const after_mode = try parseArgs(std.testing.allocator, &after_args);
    const after_cfg = after_mode.analyze;
    defer freeConfig(std.testing.allocator, after_cfg);
    try std.testing.expectEqual(model.ScopePreset.project, after_cfg.scope);
    try std.testing.expectEqualStrings(before_cfg.include_prefixes[0], after_cfg.include_prefixes[0]);
    try std.testing.expectEqual(before_cfg.exclude_prefixes.len, after_cfg.exclude_prefixes.len);
    for (before_cfg.exclude_prefixes, after_cfg.exclude_prefixes) |before_prefix, after_prefix| {
        try std.testing.expectEqualStrings(before_prefix, after_prefix);
    }
}

test "project scope deduplicates every built-in prefix" {
    const args = [_][:0]const u8{ "git-hotspots", "--scope", "project", "--exclude-prefix", ".flow/", "--exclude-prefix", ".zig-cache/", "--exclude-prefix", "zig-out/", "--exclude-prefix", "target/", "--exclude-prefix", "node_modules/", "--exclude-prefix", "dist/", "--exclude-prefix", "build/", "--exclude-prefix", "coverage/" };
    const mode = try parseArgs(std.testing.allocator, &args);
    const cfg = mode.analyze;
    defer freeConfig(std.testing.allocator, cfg);
    try expectProjectScopePrefixes(cfg.exclude_prefixes);
}

test "parse repeatable exclude prefixes" {
    const args = [_][:0]const u8{ "git-hotspots", "--scope", "all", "--exclude-prefix", "./.flow/", "--exclude-prefix", "vendor/" };
    const mode = try parseArgs(std.testing.allocator, &args);
    const cfg = mode.analyze;
    defer freeConfig(std.testing.allocator, cfg);
    try std.testing.expectEqual(@as(usize, 2), cfg.exclude_prefixes.len);
    try std.testing.expectEqualStrings(".flow/", cfg.exclude_prefixes[0]);
    try std.testing.expectEqualStrings("vendor/", cfg.exclude_prefixes[1]);
}

test "parse repeatable include prefixes" {
    const args = [_][:0]const u8{ "git-hotspots", "--include-prefix", "./src/", "--include-prefix", "vendor/" };
    const mode = try parseArgs(std.testing.allocator, &args);
    const cfg = mode.analyze;
    defer freeConfig(std.testing.allocator, cfg);
    try std.testing.expectEqual(@as(usize, 2), cfg.include_prefixes.len);
    try std.testing.expectEqualStrings("src/", cfg.include_prefixes[0]);
    try std.testing.expectEqualStrings("vendor/", cfg.include_prefixes[1]);
}

test "parse inspect path" {
    const args = [_][:0]const u8{ "git-hotspots", "--repo", "fixtures/basic", "--inspect", "./src/app.txt", "--format", "json" };
    const mode = try parseArgs(std.testing.allocator, &args);
    const cfg = mode.analyze;
    defer freeConfig(std.testing.allocator, cfg);
    try std.testing.expectEqualStrings("fixtures/basic", cfg.repo_path);
    try std.testing.expectEqualStrings("src/app.txt", cfg.inspect_path.?);
    try std.testing.expectEqual(model.Format.json, cfg.format);
}

test "parse inspect path decodes git-style tab escape" {
    const args = [_][:0]const u8{ "git-hotspots", "--inspect", "weird/tab\\tname.txt" };
    const mode = try parseArgs(std.testing.allocator, &args);
    const cfg = mode.analyze;
    defer freeConfig(std.testing.allocator, cfg);
    try std.testing.expectEqualStrings("weird/tab\tname.txt", cfg.inspect_path.?);
}

test "parse symbols works for project and inspect" {
    const project_args = [_][:0]const u8{ "git-hotspots", "--symbols" };
    const project_mode = try parseArgs(std.testing.allocator, &project_args);
    const project_cfg = project_mode.analyze;
    defer freeConfig(std.testing.allocator, project_cfg);
    try std.testing.expect(project_cfg.symbols);
    try std.testing.expect(project_cfg.inspect_path == null);

    const args = [_][:0]const u8{ "git-hotspots", "--inspect", "src/app.zig", "--symbols" };
    const mode = try parseArgs(std.testing.allocator, &args);
    const cfg = mode.analyze;
    defer freeConfig(std.testing.allocator, cfg);
    try std.testing.expect(cfg.symbols);
    try std.testing.expectEqualStrings("src/app.zig", cfg.inspect_path.?);
}

test "parse symbol line history requires symbols" {
    const project_args = [_][:0]const u8{ "git-hotspots", "--symbols", "--symbol-line-history" };
    const project_mode = try parseArgs(std.testing.allocator, &project_args);
    const project_cfg = project_mode.analyze;
    defer freeConfig(std.testing.allocator, project_cfg);
    try std.testing.expect(project_cfg.symbols);
    try std.testing.expect(project_cfg.symbol_line_history);

    const args = [_][:0]const u8{ "git-hotspots", "--inspect", "src/app.zig", "--symbols", "--symbol-line-history" };
    const mode = try parseArgs(std.testing.allocator, &args);
    const cfg = mode.analyze;
    defer freeConfig(std.testing.allocator, cfg);
    try std.testing.expect(cfg.symbols);
    try std.testing.expect(cfg.symbol_line_history);
    try std.testing.expectEqualStrings("src/app.zig", cfg.inspect_path.?);
    try std.testing.expectError(error.InvalidSymbolLineHistoryCombination, parseArgs(std.testing.allocator, &[_][:0]const u8{ "git-hotspots", "--symbol-line-history" }));
    try std.testing.expectError(error.InvalidSymbolLineHistoryCombination, parseArgs(std.testing.allocator, &[_][:0]const u8{ "git-hotspots", "--inspect", "src/app.zig", "--symbol-line-history" }));
}

test "parse historical symbols requires symbols" {
    const project_args = [_][:0]const u8{ "git-hotspots", "--symbols", "--historical-symbols" };
    const project_mode = try parseArgs(std.testing.allocator, &project_args);
    const project_cfg = project_mode.analyze;
    defer freeConfig(std.testing.allocator, project_cfg);
    try std.testing.expect(project_cfg.symbols);
    try std.testing.expect(project_cfg.historical_symbols);

    const args = [_][:0]const u8{ "git-hotspots", "--inspect", "src/app.zig", "--symbols", "--historical-symbols" };
    const mode = try parseArgs(std.testing.allocator, &args);
    const cfg = mode.analyze;
    defer freeConfig(std.testing.allocator, cfg);
    try std.testing.expect(cfg.symbols);
    try std.testing.expect(cfg.historical_symbols);
    try std.testing.expectEqualStrings("src/app.zig", cfg.inspect_path.?);

    try std.testing.expectError(error.InvalidHistoricalSymbolsCombination, parseArgs(std.testing.allocator, &[_][:0]const u8{ "git-hotspots", "--historical-symbols" }));
    try std.testing.expectError(error.InvalidHistoricalSymbolsCombination, parseArgs(std.testing.allocator, &[_][:0]const u8{ "git-hotspots", "--inspect", "src/app.zig", "--historical-symbols" }));
}

test "parse symbol relationships requires symbols" {
    const project_args = [_][:0]const u8{ "git-hotspots", "--symbols", "--symbol-relationships" };
    const project_mode = try parseArgs(std.testing.allocator, &project_args);
    const project_cfg = project_mode.analyze;
    defer freeConfig(std.testing.allocator, project_cfg);
    try std.testing.expect(project_cfg.symbols);
    try std.testing.expect(project_cfg.symbol_relationships);

    const args = [_][:0]const u8{ "git-hotspots", "--inspect", "src/app.zig", "--symbols", "--symbol-relationships" };
    const mode = try parseArgs(std.testing.allocator, &args);
    const cfg = mode.analyze;
    defer freeConfig(std.testing.allocator, cfg);
    try std.testing.expect(cfg.symbols);
    try std.testing.expect(cfg.symbol_relationships);
    try std.testing.expectEqualStrings("src/app.zig", cfg.inspect_path.?);

    try std.testing.expectError(error.InvalidSymbolRelationshipsCombination, parseArgs(std.testing.allocator, &[_][:0]const u8{ "git-hotspots", "--symbol-relationships" }));
    try std.testing.expectError(error.InvalidSymbolRelationshipsCombination, parseArgs(std.testing.allocator, &[_][:0]const u8{ "git-hotspots", "--inspect", "src/app.zig", "--symbol-relationships" }));
}

test "parse symbol limit is human display only with symbols" {
    const project_args = [_][:0]const u8{ "git-hotspots", "--symbols", "--symbol-limit", "7" };
    const project_mode = try parseArgs(std.testing.allocator, &project_args);
    const project_cfg = project_mode.analyze;
    defer freeConfig(std.testing.allocator, project_cfg);
    try std.testing.expect(project_cfg.symbols);
    try std.testing.expectEqual(@as(?usize, 7), project_cfg.symbol_limit);

    const args = [_][:0]const u8{ "git-hotspots", "--inspect", "src/app.zig", "--symbols", "--symbol-limit", "7" };
    const mode = try parseArgs(std.testing.allocator, &args);
    const cfg = mode.analyze;
    defer freeConfig(std.testing.allocator, cfg);
    try std.testing.expect(cfg.symbols);
    try std.testing.expectEqualStrings("src/app.zig", cfg.inspect_path.?);
    try std.testing.expectEqual(@as(?usize, 7), cfg.symbol_limit);

    try std.testing.expectError(error.InvalidSymbolLimitCombination, parseArgs(std.testing.allocator, &[_][:0]const u8{ "git-hotspots", "--symbol-limit", "7" }));
    try std.testing.expectError(error.InvalidSymbolLimitCombination, parseArgs(std.testing.allocator, &[_][:0]const u8{ "git-hotspots", "--inspect", "src/app.zig", "--symbol-limit", "7" }));
    try std.testing.expectError(error.InvalidSymbolLimit, parseArgs(std.testing.allocator, &[_][:0]const u8{ "git-hotspots", "--inspect", "src/app.zig", "--symbols", "--symbol-limit", "0" }));
    try std.testing.expectError(error.InvalidSymbolLimit, parseArgs(std.testing.allocator, &[_][:0]const u8{ "git-hotspots", "--inspect", "src/app.zig", "--symbols", "--symbol-limit", "nope" }));
}

test "reject invalid inspect paths and limit combination" {
    const invalid = [_][]const [:0]const u8{
        &[_][:0]const u8{ "git-hotspots", "--inspect", "" },
        &[_][:0]const u8{ "git-hotspots", "--inspect", "/tmp" },
        &[_][:0]const u8{ "git-hotspots", "--inspect", "C:/tmp" },
        &[_][:0]const u8{ "git-hotspots", "--inspect", "\\tmp" },
        &[_][:0]const u8{ "git-hotspots", "--inspect", "src/../lib" },
        &[_][:0]const u8{ "git-hotspots", "--inspect", "bad\npath" },
    };
    for (invalid) |args| try std.testing.expectError(error.InvalidInspectPath, parseArgs(std.testing.allocator, args));

    try std.testing.expectError(error.InvalidInspectLimitCombination, parseArgs(std.testing.allocator, &[_][:0]const u8{ "git-hotspots", "--limit", "1", "--inspect", "src/app.txt" }));
    try std.testing.expectError(error.InvalidInspectLimitCombination, parseArgs(std.testing.allocator, &[_][:0]const u8{ "git-hotspots", "--inspect", "src/app.txt", "--limit", "1" }));
}

test "reject invalid exclude prefixes" {
    const cases = [_][]const u8{ "", "/tmp", "../src", "src/../lib", "bad\npath" };
    for (cases) |value| {
        var cfg = model.Config{ .repo_path = try std.testing.allocator.dupe(u8, ".") };
        defer freeConfig(std.testing.allocator, cfg);
        try std.testing.expectError(error.InvalidExcludePrefix, appendExcludePrefix(std.testing.allocator, &cfg, value));
    }
}

test "reject invalid include prefixes" {
    const cases = [_][]const u8{ "", "/tmp", "C:/tmp", "\\tmp", "../src", "src/../lib", "bad\npath" };
    for (cases) |value| {
        var cfg = model.Config{ .repo_path = try std.testing.allocator.dupe(u8, ".") };
        defer freeConfig(std.testing.allocator, cfg);
        try std.testing.expectError(error.InvalidIncludePrefix, appendIncludePrefix(std.testing.allocator, &cfg, value));
    }
}

fn expectProjectScopePrefixes(prefixes: []const []const u8) !void {
    const expected = [_][]const u8{ ".flow/", ".zig-cache/", "zig-out/", "target/", "node_modules/", "dist/", "build/", "coverage/" };
    try std.testing.expectEqual(expected.len, prefixes.len);
    for (expected, prefixes) |expected_prefix, actual_prefix| {
        try std.testing.expectEqualStrings(expected_prefix, actual_prefix);
    }
}
