const std = @import("std");
const model = @import("model.zig");

pub fn renderTable(writer: anytype, analysis: model.Analysis) !void {
    try writer.print("git-hotspots: file-level Git-history investigation prompts\n", .{});
    try writer.print("commits={d} shallow={} partial={} dirty={} auto_fetch=false\n", .{ analysis.history.commit_count, analysis.history.is_shallow, analysis.history.is_partial, analysis.history.dirty_worktree });
    if (analysis.scope.filters_active) {
        try writer.print("scope: exclude_prefixes=", .{});
        try renderInlineStringArray(writer, analysis.scope.exclude_prefixes);
        try writer.print(" excluded_paths={d} excluded_changes={d}\n", .{ analysis.scope.excluded_path_count, analysis.scope.excluded_change_count });
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
    try writer.print("  \"tool\": {{ \"name\": \"git-hotspots\", \"version\": \"0.0.0-spike\" }},\n", .{});
    try writer.print("  \"analysis\": {{\n", .{});
    try writer.print("    \"history\": {{ \"head\": ", .{});
    try jsonString(writer, analysis.history.head);
    try writer.print(", \"head_timestamp\": {d}, ", .{analysis.history.head_timestamp});
    try writer.print("\"range\": ", .{});
    if (analysis.history.range) |r| try jsonString(writer, r) else try writer.print("null", .{});
    try writer.print(", \"is_shallow\": {}, \"is_partial\": {}, \"auto_fetch\": false, \"dirty_worktree\": {}, \"commit_count\": {d} }},\n", .{ analysis.history.is_shallow, analysis.history.is_partial, analysis.history.dirty_worktree, analysis.history.commit_count });
    try writer.print("    \"scope\": {{ \"filters_active\": {}, \"exclude_prefixes\": ", .{analysis.scope.filters_active});
    try stringArray(writer, analysis.scope.exclude_prefixes);
    try writer.print(", \"excluded_path_count\": {d}, \"excluded_change_count\": {d} }},\n", .{ analysis.scope.excluded_path_count, analysis.scope.excluded_change_count });
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
