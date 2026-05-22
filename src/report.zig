const std = @import("std");
const model = @import("model.zig");
const version = @import("version.zig");

pub fn renderTable(writer: anytype, analysis: model.Analysis) !void {
    try writer.print("git-hotspots: file-level Git-history investigation prompts\n", .{});
    try writer.print("commits={d} shallow={} partial={} dirty={} auto_fetch=false\n", .{ analysis.history.commit_count, analysis.history.is_shallow, analysis.history.is_partial, analysis.history.dirty_worktree });
    if (analysis.scope.filters_active) {
        try writer.print("scope: include_prefixes=", .{});
        try renderInlineStringArray(writer, analysis.scope.include_prefixes);
        try writer.print(" exclude_prefixes=", .{});
        try renderInlineStringArray(writer, analysis.scope.exclude_prefixes);
        try writer.print(" outside_include_paths={d} outside_include_changes={d} excluded_paths={d} excluded_changes={d}\n", .{ analysis.scope.outside_include_path_count, analysis.scope.outside_include_change_count, analysis.scope.excluded_path_count, analysis.scope.excluded_change_count });
    }
    if (analysis.caveats.len > 0) {
        try writer.print("caveats: ", .{});
        for (analysis.caveats, 0..) |c, i| {
            if (i != 0) try writer.print("; ", .{});
            try writer.print("{s}", .{c});
        }
        try writer.print("\n", .{});
    }
    try writer.print("\n{s:<5} {s:<7} {s:<7} {s:<7} {s:<10} {s}\n", .{ "rank", "score", "changes", "churn", "confidence", "path" });
    for (analysis.results, 0..) |row, i| {
        try writer.print("{d:<5} {d:<7.1} {d:<7} {d:<7} {s:<10} {s}\n", .{ i + 1, row.score.total, row.change_count, row.churn, row.confidence, row.path });
    }
    try writer.print("\nScores are deterministic prompts for investigation, not bug predictions or code-quality ratings.\n", .{});
}

pub fn renderJson(writer: anytype, analysis: model.Analysis) !void {
    try writer.print("{{\n", .{});
    try writer.print("  \"schema_version\": \"1\",\n", .{});
    try writer.print("  \"tool\": {{ \"name\": \"git-hotspots\", \"version\": \"{s}\" }},\n", .{version.value});
    try writer.print("  \"analysis\": {{\n", .{});
    try writer.print("    \"history\": {{ \"head\": ", .{});
    try jsonString(writer, analysis.history.head);
    try writer.print(", \"head_timestamp\": {d}, ", .{analysis.history.head_timestamp});
    try writer.print("\"range\": ", .{});
    if (analysis.history.range) |r| try jsonString(writer, r) else try writer.print("null", .{});
    try writer.print(", \"is_shallow\": {}, \"is_partial\": {}, \"auto_fetch\": false, \"dirty_worktree\": {}, \"commit_count\": {d} }},\n", .{ analysis.history.is_shallow, analysis.history.is_partial, analysis.history.dirty_worktree, analysis.history.commit_count });
    try writer.print("    \"scope\": {{ \"filters_active\": {}, \"include_prefixes\": ", .{analysis.scope.filters_active});
    try stringArray(writer, analysis.scope.include_prefixes);
    try writer.print(", \"exclude_prefixes\": ", .{});
    try stringArray(writer, analysis.scope.exclude_prefixes);
    try writer.print(", \"outside_include_path_count\": {d}, \"outside_include_change_count\": {d}, \"excluded_path_count\": {d}, \"excluded_change_count\": {d} }},\n", .{ analysis.scope.outside_include_path_count, analysis.scope.outside_include_change_count, analysis.scope.excluded_path_count, analysis.scope.excluded_change_count });
    try writer.print("    \"caveats\": ", .{});
    try stringArray(writer, analysis.caveats);
    try writer.print("\n", .{});
    try writer.print("  }},\n", .{});
    try writer.print("  \"results\": [\n", .{});
    for (analysis.results, 0..) |row, i| {
        try writer.print("    {{\n", .{});
        try writer.print("      \"path\": ", .{});
        try jsonString(writer, row.path);
        try writer.print(",\n", .{});
        try writer.print("      \"score\": {{ \"total\": {d:.3}, \"frequency\": {d:.3}, \"churn\": {d:.3}, \"recency\": {d:.3}, \"cochange\": {d:.3} }},\n", .{ row.score.total, row.score.frequency, row.score.churn, row.score.recency, row.score.cochange });
        try writer.print("      \"change_count\": {d}, \"additions\": {d}, \"deletions\": {d}, \"churn\": {d},\n", .{ row.change_count, row.additions, row.deletions, row.churn });
        try writer.print("      \"recency\": {{ \"last_changed_timestamp\": {d}, \"last_changed_commit\": ", .{row.last_changed_timestamp});
        try jsonString(writer, row.last_changed_commit);
        try writer.print(" }},\n", .{});
        try writer.print("      \"current_size\": ", .{});
        if (row.current_size) |s| try writer.print("{d}", .{s}) else try writer.print("null", .{});
        try writer.print(",\n", .{});
        try writer.print("      \"cochanges\": [", .{});
        for (row.cochanges, 0..) |cc, j| {
            if (j != 0) try writer.print(", ", .{});
            try writer.print("{{ \"path\": ", .{});
            try jsonString(writer, cc.path);
            try writer.print(", \"count\": {d} }}", .{cc.count});
        }
        try writer.print("],\n", .{});
        try writer.print("      \"confidence\": ", .{});
        try jsonString(writer, row.confidence);
        try writer.print(",\n", .{});
        try writer.print("      \"caveats\": ", .{});
        try stringArray(writer, row.caveats);
        try writer.print(",\n", .{});
        try writer.print("      \"evidence\": [", .{});
        for (row.evidence, 0..) |ev, j| {
            if (j != 0) try writer.print(", ", .{});
            try writer.print("{{ \"commit\": ", .{});
            try jsonString(writer, ev.commit);
            try writer.print(", \"timestamp\": {d}, \"additions\": ", .{ev.timestamp});
            if (ev.additions) |a| try writer.print("{d}", .{a}) else try writer.print("null", .{});
            try writer.print(", \"deletions\": ", .{});
            if (ev.deletions) |d| try writer.print("{d}", .{d}) else try writer.print("null", .{});
            try writer.print(" }}", .{});
        }
        try writer.print("]\n", .{});
        try writer.print("    }}{s}\n", .{if (i + 1 == analysis.results.len) "" else ","});
    }
    try writer.print("  ]\n", .{});
    try writer.print("}}\n", .{});
}

pub fn renderMarkdown(writer: anytype, analysis: model.Analysis) !void {
    try writer.writeAll("# git-hotspots report\n\n");
    try writer.writeAll("File-level Git-history investigation prompts, not bug predictions or code-quality ratings.\n\n");

    try writer.writeAll("## Run summary\n\n");
    try writer.print("- Tool: git-hotspots {s}\n", .{version.value});
    try writer.writeAll("- Head commit: ");
    try markdownText(writer, analysis.history.head);
    try writer.writeByte('\n');
    try writer.writeAll("- Range: ");
    if (analysis.history.range) |range| try markdownText(writer, range) else try writer.writeAll("None");
    try writer.writeByte('\n');
    try writer.print("- Commit count: {d}\n", .{analysis.history.commit_count});
    try writer.print("- Shallow history: {}\n", .{analysis.history.is_shallow});
    try writer.print("- Partial history: {}\n", .{analysis.history.is_partial});
    try writer.print("- Dirty worktree: {}\n", .{analysis.history.dirty_worktree});
    try writer.writeAll("- Auto fetch: false\n");
    try writer.writeAll("- Paths: repo-relative\n\n");

    try writer.writeAll("## Scope\n\n");
    try writer.print("- Filters active: {}\n", .{analysis.scope.filters_active});
    try writer.writeAll("- Include prefixes: ");
    if (analysis.scope.include_prefixes.len == 0) {
        try writer.writeAll("None");
    } else {
        for (analysis.scope.include_prefixes, 0..) |prefix, i| {
            if (i != 0) try writer.writeAll(", ");
            try markdownText(writer, prefix);
        }
    }
    try writer.writeByte('\n');
    try writer.writeAll("- Exclude prefixes: ");
    if (analysis.scope.exclude_prefixes.len == 0) {
        try writer.writeAll("None");
    } else {
        for (analysis.scope.exclude_prefixes, 0..) |prefix, i| {
            if (i != 0) try writer.writeAll(", ");
            try markdownText(writer, prefix);
        }
    }
    try writer.writeByte('\n');
    try writer.print("- Outside include path count: {d}\n", .{analysis.scope.outside_include_path_count});
    try writer.print("- Outside include change count: {d}\n", .{analysis.scope.outside_include_change_count});
    try writer.print("- Excluded path count: {d}\n", .{analysis.scope.excluded_path_count});
    try writer.print("- Excluded change count: {d}\n\n", .{analysis.scope.excluded_change_count});

    try writer.writeAll("## Caveats\n\n");
    try renderMarkdownStringList(writer, analysis.caveats);

    try writer.writeAll("\n## Top hotspots\n\n");
    try writer.writeAll("| Rank | Path | Score | Changes | Churn | Confidence | Last commit |\n");
    try writer.writeAll("| ---: | --- | ---: | ---: | ---: | --- | --- |\n");
    for (analysis.results, 0..) |row, i| {
        try writer.print("| {d} | ", .{i + 1});
        try markdownText(writer, row.path);
        try writer.print(" | {d:.1} | {d} | {d} | ", .{ row.score.total, row.change_count, row.churn });
        try markdownText(writer, row.confidence);
        try writer.writeAll(" | ");
        try markdownText(writer, row.last_changed_commit);
        try writer.writeAll(" |\n");
    }
    if (analysis.results.len == 0) try writer.writeAll("\nNo hotspots matched the requested scope.\n");

    try writer.writeAll("\n## Evidence\n");
    if (analysis.results.len == 0) {
        try writer.writeAll("\nNo result evidence to show.\n");
        return;
    }

    for (analysis.results, 0..) |row, i| {
        try writer.print("\n### {d}. ", .{i + 1});
        try markdownText(writer, row.path);
        try writer.writeAll("\n\n");
        try writer.print("- Score breakdown: total={d:.3}, frequency={d:.3}, churn={d:.3}, recency={d:.3}, cochange={d:.3}\n", .{ row.score.total, row.score.frequency, row.score.churn, row.score.recency, row.score.cochange });
        try writer.print("- Changes: {d}\n", .{row.change_count});
        try writer.print("- Additions: {d}\n", .{row.additions});
        try writer.print("- Deletions: {d}\n", .{row.deletions});
        try writer.print("- Current size: ", .{});
        if (row.current_size) |size| try writer.print("{d}", .{size}) else try writer.writeAll("None");
        try writer.writeByte('\n');
        try writer.writeAll("- Confidence: ");
        try markdownText(writer, row.confidence);
        try writer.writeByte('\n');
        try writer.writeAll("- Last commit: ");
        try markdownText(writer, row.last_changed_commit);
        try writer.writeByte('\n');

        try writer.writeAll("- Top co-changes:\n");
        if (row.cochanges.len == 0) {
            try writer.writeAll("  - None\n");
        } else {
            for (row.cochanges) |cc| {
                try writer.writeAll("  - ");
                try markdownText(writer, cc.path);
                try writer.print(" (count={d})\n", .{cc.count});
            }
        }

        try writer.writeAll("- Evidence commits:\n");
        if (row.evidence.len == 0) {
            try writer.writeAll("  - None\n");
        } else {
            for (row.evidence) |ev| {
                try writer.writeAll("  - commit=");
                try markdownText(writer, ev.commit);
                try writer.print(" timestamp={d} additions=", .{ev.timestamp});
                try renderOptionalU64(writer, ev.additions);
                try writer.writeAll(" deletions=");
                try renderOptionalU64(writer, ev.deletions);
                try writer.writeByte('\n');
            }
        }

        try writer.writeAll("- Row caveats:\n");
        if (row.caveats.len == 0) {
            try writer.writeAll("  - None\n");
        } else {
            for (row.caveats) |caveat| {
                try writer.writeAll("  - ");
                try markdownText(writer, caveat);
                try writer.writeByte('\n');
            }
        }
    }
}

fn stringArray(writer: anytype, values: []const []const u8) !void {
    try writer.print("[", .{});
    for (values, 0..) |v, i| {
        if (i != 0) try writer.print(", ", .{});
        try jsonString(writer, v);
    }
    try writer.print("]", .{});
}

fn renderInlineStringArray(writer: anytype, values: []const []const u8) !void {
    try writer.print("[", .{});
    for (values, 0..) |value, i| {
        if (i != 0) try writer.print(",", .{});
        try writer.print("{s}", .{value});
    }
    try writer.print("]", .{});
}

fn renderMarkdownStringList(writer: anytype, values: []const []const u8) !void {
    if (values.len == 0) {
        try writer.writeAll("- None\n");
        return;
    }
    for (values) |value| {
        try writer.writeAll("- ");
        try markdownText(writer, value);
        try writer.writeByte('\n');
    }
}

fn renderOptionalU64(writer: anytype, value: ?u64) !void {
    if (value) |v| try writer.print("{d}", .{v}) else try writer.writeAll("None");
}

fn markdownText(writer: anytype, value: []const u8) !void {
    for (value) |c| switch (c) {
        '\\' => try writer.writeAll("\\\\"),
        '`' => try writer.writeAll("\\`"),
        '*' => try writer.writeAll("\\*"),
        '_' => try writer.writeAll("\\_"),
        '{' => try writer.writeAll("\\{"),
        '}' => try writer.writeAll("\\}"),
        '[' => try writer.writeAll("\\["),
        ']' => try writer.writeAll("\\]"),
        '(' => try writer.writeAll("\\("),
        ')' => try writer.writeAll("\\)"),
        '#' => try writer.writeAll("\\#"),
        '+' => try writer.writeAll("\\+"),
        '-' => try writer.writeAll("\\-"),
        '!' => try writer.writeAll("\\!"),
        '|' => try writer.writeAll("\\|"),
        '>' => try writer.writeAll("\\>"),
        '\n' => try writer.writeAll("\\n"),
        '\r' => try writer.writeAll("\\r"),
        '\t' => try writer.writeAll("\\t"),
        0...8, 11...12, 14...0x1f, 0x7f => try writer.print("\\x{x:0>2}", .{c}),
        else => try writer.writeByte(c),
    };
}

fn jsonString(writer: anytype, value: []const u8) !void {
    try writer.writeByte('"');
    for (value) |c| switch (c) {
        '"' => try writer.writeAll("\\\""),
        '\\' => try writer.writeAll("\\\\"),
        '\n' => try writer.writeAll("\\n"),
        '\r' => try writer.writeAll("\\r"),
        '\t' => try writer.writeAll("\\t"),
        0...8, 11...12, 14...0x1f => try writer.print("\\u{x:0>4}", .{c}),
        else => try writer.writeByte(c),
    };
    try writer.writeByte('"');
}

test "json string escapes paths" {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try jsonString(&aw.writer, "a b/é\t\\q\"");
    try std.testing.expectEqualStrings("\"a b/é\\t\\\\q\\\"\"", aw.written());
}

test "markdown text escapes markdown and control characters" {
    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try markdownText(&aw.writer, "# [a|b] `x`\t\\q\x01");
    try std.testing.expectEqualStrings("\\# \\[a\\|b\\] \\`x\\`\\t\\\\q\\x01", aw.written());
}

test "markdown report has stable sections and no raw private root" {
    var include_prefixes = [_][]const u8{"src/"};
    var prefixes = [_][]const u8{ ".flow/", "glob/*" };
    var global_caveats = [_][]const u8{"dirty worktree detected; ranking uses committed history only"};
    var cochanges = [_]model.CoChange{.{ .path = "co|path\t`x`.zig", .count = 2 }};
    var row_caveats = [_][]const u8{"path # caveat\tbinary"};
    var evidence = [_]model.Evidence{.{ .commit = "abc123", .timestamp = 123, .additions = 1, .deletions = null }};
    var results = [_]model.Result{.{
        .path = "# heading|path\t`x`.zig",
        .score = .{ .frequency = 1.0, .churn = 2.0, .recency = 3.0, .cochange = 4.0, .total = 10.0 },
        .change_count = 2,
        .additions = 7,
        .deletions = 5,
        .churn = 12,
        .last_changed_timestamp = 456,
        .last_changed_commit = "def456",
        .current_size = null,
        .cochanges = cochanges[0..],
        .confidence = "medium",
        .caveats = row_caveats[0..],
        .evidence = evidence[0..],
    }};
    const analysis = model.Analysis{
        .allocator = std.testing.allocator,
        .repo_root = "/private/root",
        .history = .{ .head = "head123", .head_timestamp = 999, .range = null, .is_shallow = false, .is_partial = false, .dirty_worktree = true, .commit_count = 3 },
        .scope = .{ .filters_active = true, .include_prefixes = include_prefixes[0..], .exclude_prefixes = prefixes[0..], .outside_include_path_count = 3, .outside_include_change_count = 4, .excluded_path_count = 2, .excluded_change_count = 5 },
        .results = results[0..],
        .caveats = global_caveats[0..],
    };

    var aw: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer aw.deinit();
    try renderMarkdown(&aw.writer, analysis);
    const out = aw.written();

    try std.testing.expect(std.mem.indexOf(u8, out, "# git-hotspots report\n\n") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "File-level Git-history investigation prompts, not bug predictions or code-quality ratings.") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Run summary\n\n- Tool: git-hotspots 0.1.0-alpha.1") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Scope") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Caveats") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Top hotspots") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "## Evidence") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "\\# heading\\|path\\t\\`x\\`") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "co\\|path\\t\\`x\\`") != null);
    try std.testing.expect(std.mem.indexOfScalar(u8, out, '\t') == null);
    try std.testing.expect(std.mem.indexOf(u8, out, "/private/root") == null);
}
