const std = @import("std");

const typescript_symbol_line_history_out_of_scope_caveat = "module names are repo-relative .ts/.mts/.cts/.tsx paths; package, workspace, Node, module-resolution, tsconfig, type checking, LSP, and symbol line history are out of scope";
const typescript_true_symbol_history_out_of_scope_caveat = "module names are repo-relative .ts/.mts/.cts/.tsx paths; package, workspace, Node, module-resolution, tsconfig, type checking, LSP, and true symbol history are out of scope";

pub fn renderCaveatInline(writer: anytype, caveats: []const []const u8) !void {
    if (caveats.len == 0) {
        try writer.writeAll("none");
        return;
    }
    var emitted = false;
    for (caveats, 0..) |caveat, i| {
        if (isDuplicateCaveat(caveats, i, caveat, false)) continue;
        if (emitted) try writer.writeAll("; ");
        try writer.writeAll(caveat);
        emitted = true;
    }
    if (!emitted) try writer.writeAll("none");
}

pub fn renderMarkdownCaveatInline(writer: anytype, caveats: []const []const u8) !void {
    if (caveats.len == 0) {
        try writer.writeAll("none");
        return;
    }
    var emitted = false;
    for (caveats, 0..) |caveat, i| {
        if (isDuplicateCaveat(caveats, i, caveat, false)) continue;
        if (emitted) try writer.writeAll("; ");
        try markdownText(writer, caveat);
        emitted = true;
    }
    if (!emitted) try writer.writeAll("none");
}

pub fn stringArray(writer: anytype, values: []const []const u8) !void {
    try writer.print("[", .{});
    for (values, 0..) |v, i| {
        if (i != 0) try writer.print(", ", .{});
        try jsonString(writer, v);
    }
    try writer.print("]", .{});
}

pub fn stringArrayWithLineHistoryContext(writer: anytype, values: []const []const u8, line_history_context: bool) !void {
    try writer.print("[", .{});
    for (values, 0..) |v, i| {
        if (i != 0) try writer.print(", ", .{});
        try jsonString(writer, caveatForLineHistoryContext(v, line_history_context));
    }
    try writer.print("]", .{});
}

pub fn caveatArray(writer: anytype, caveats: []const []const u8) !void {
    try caveatArrayWithLineHistoryContext(writer, caveats, false);
}

pub fn caveatArrayWithLineHistoryContext(writer: anytype, caveats: []const []const u8, line_history_context: bool) !void {
    try writer.print("[", .{});
    var emitted = false;
    for (caveats, 0..) |caveat, i| {
        const normalized = caveatForLineHistoryContext(caveat, line_history_context);
        if (isDuplicateCaveat(caveats, i, normalized, line_history_context)) continue;
        if (emitted) try writer.print(", ", .{});
        try jsonString(writer, normalized);
        emitted = true;
    }
    try writer.print("]", .{});
}

pub fn caveatForLineHistoryContext(caveat: []const u8, line_history_context: bool) []const u8 {
    if (line_history_context and std.mem.eql(u8, caveat, typescript_symbol_line_history_out_of_scope_caveat)) return typescript_true_symbol_history_out_of_scope_caveat;
    return caveat;
}

pub fn renderInlineStringArray(writer: anytype, values: []const []const u8) !void {
    try writer.print("[", .{});
    for (values, 0..) |value, i| {
        if (i != 0) try writer.print(",", .{});
        try writer.print("{s}", .{value});
    }
    try writer.print("]", .{});
}

pub fn renderMarkdownStringList(writer: anytype, values: []const []const u8) !void {
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

pub fn renderMarkdownCaveatList(writer: anytype, caveats: []const []const u8) !void {
    if (caveats.len == 0) {
        try writer.writeAll("- None\n");
        return;
    }
    var emitted = false;
    for (caveats, 0..) |caveat, i| {
        if (isDuplicateCaveat(caveats, i, caveat, false)) continue;
        try writer.writeAll("- ");
        try markdownText(writer, caveat);
        try writer.writeByte('\n');
        emitted = true;
    }
    if (!emitted) try writer.writeAll("- None\n");
}

pub fn isDuplicateCaveat(caveats: []const []const u8, index: usize, normalized: []const u8, line_history_context: bool) bool {
    for (caveats[0..index]) |previous| {
        if (std.mem.eql(u8, caveatForLineHistoryContext(previous, line_history_context), normalized)) return true;
    }
    return false;
}

pub fn containsCaveat(caveats: []const []const u8, normalized: []const u8, line_history_context: bool) bool {
    for (caveats) |caveat| {
        if (std.mem.eql(u8, caveatForLineHistoryContext(caveat, line_history_context), normalized)) return true;
    }
    return false;
}

pub fn renderOptionalU64(writer: anytype, value: ?u64) !void {
    if (value) |v| try writer.print("{d}", .{v}) else try writer.writeAll("None");
}

pub fn markdownText(writer: anytype, value: []const u8) !void {
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

pub fn jsonString(writer: anytype, value: []const u8) !void {
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

test "caveat renderers preserve order while removing duplicates" {
    const caveats = [_][]const u8{ "first caveat", "second caveat", "first caveat" };

    var inline_writer: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer inline_writer.deinit();
    try renderCaveatInline(&inline_writer.writer, &caveats);
    try std.testing.expectEqualStrings("first caveat; second caveat", inline_writer.written());

    var json: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer json.deinit();
    try caveatArray(&json.writer, &caveats);
    try std.testing.expectEqualStrings("[\"first caveat\", \"second caveat\"]", json.written());

    var markdown: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer markdown.deinit();
    try renderMarkdownCaveatList(&markdown.writer, &caveats);
    try std.testing.expectEqualStrings("- first caveat\n- second caveat\n", markdown.written());
}
