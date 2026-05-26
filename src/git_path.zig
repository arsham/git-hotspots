const std = @import("std");

pub fn pathPassesFilters(path: []const u8, include_prefixes: []const []const u8, exclude_prefixes: []const []const u8) bool {
    return !isExcludedPath(path, exclude_prefixes) and isIncludedPath(path, include_prefixes);
}

pub fn noteFilteredPath(
    allocator: std.mem.Allocator,
    path: []const u8,
    outside_include_paths: *std.StringHashMap(void),
    outside_include_change_count: *usize,
    excluded_paths: *std.StringHashMap(void),
    excluded_change_count: *usize,
    include_prefixes: []const []const u8,
    exclude_prefixes: []const []const u8,
) !void {
    if (isExcludedPath(path, exclude_prefixes)) {
        excluded_change_count.* += 1;
        if (excluded_paths.get(path) == null) {
            const owned = try allocator.dupe(u8, path);
            errdefer allocator.free(owned);
            try excluded_paths.put(owned, {});
        }
        return;
    }
    if (!isIncludedPath(path, include_prefixes)) {
        outside_include_change_count.* += 1;
        if (outside_include_paths.get(path) == null) {
            const owned = try allocator.dupe(u8, path);
            errdefer allocator.free(owned);
            try outside_include_paths.put(owned, {});
        }
    }
}

pub fn isIncludedPath(path: []const u8, include_prefixes: []const []const u8) bool {
    if (include_prefixes.len == 0) return true;
    for (include_prefixes) |prefix| {
        if (std.mem.startsWith(u8, path, prefix)) return true;
    }
    return false;
}

pub fn isExcludedPath(path: []const u8, exclude_prefixes: []const []const u8) bool {
    for (exclude_prefixes) |prefix| {
        if (std.mem.startsWith(u8, path, prefix)) return true;
    }
    return false;
}

pub fn normalizePath(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
    const unquoted = try unquoteGitPath(allocator, raw);
    errdefer allocator.free(unquoted);

    if (std.mem.indexOf(u8, unquoted, " => ") == null) return unquoted;

    if (std.mem.indexOfScalar(u8, unquoted, '{')) |open| {
        if (std.mem.lastIndexOfScalar(u8, unquoted, '}')) |close| {
            if (open < close) {
                const inner = unquoted[open + 1 .. close];
                if (std.mem.indexOf(u8, inner, " => ")) |_| {
                    var split = std.mem.splitSequence(u8, inner, " => ");
                    _ = split.next();
                    const renamed = split.next() orelse inner;
                    const normalized = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ unquoted[0..open], renamed, unquoted[close + 1 ..] });
                    allocator.free(unquoted);
                    return normalized;
                }
            }
        }
    }

    var split = std.mem.splitSequence(u8, unquoted, " => ");
    _ = split.next();
    const renamed = split.next() orelse return unquoted;
    const normalized = try allocator.dupe(u8, renamed);
    allocator.free(unquoted);
    return normalized;
}

pub const RenamePath = struct { old_path: []u8, new_path: []u8 };

pub fn parseRenamePath(allocator: std.mem.Allocator, raw: []const u8) !?RenamePath {
    const unquoted = try unquoteGitPath(allocator, raw);
    defer allocator.free(unquoted);

    if (std.mem.indexOf(u8, unquoted, " => ") == null) return null;

    if (std.mem.indexOfScalar(u8, unquoted, '{')) |open| {
        if (std.mem.lastIndexOfScalar(u8, unquoted, '}')) |close| {
            if (open < close) {
                const inner = unquoted[open + 1 .. close];
                if (std.mem.indexOf(u8, inner, " => ")) |_| {
                    var split = std.mem.splitSequence(u8, inner, " => ");
                    const old_part = split.next() orelse return null;
                    const new_part = split.next() orelse return null;
                    const old_full = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ unquoted[0..open], old_part, unquoted[close + 1 ..] });
                    errdefer allocator.free(old_full);
                    const new_full = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ unquoted[0..open], new_part, unquoted[close + 1 ..] });
                    return .{ .old_path = old_full, .new_path = new_full };
                }
            }
        }
    }

    var split = std.mem.splitSequence(u8, unquoted, " => ");
    const old_path = split.next() orelse return null;
    const new_path = split.next() orelse return null;
    const old_path_owned = try allocator.dupe(u8, old_path);
    errdefer allocator.free(old_path_owned);
    const new_path_owned = try allocator.dupe(u8, new_path);
    return .{ .old_path = old_path_owned, .new_path = new_path_owned };
}

pub fn unquoteGitPath(allocator: std.mem.Allocator, raw: []const u8) ![]u8 {
    if (raw.len < 2 or raw[0] != '"' or raw[raw.len - 1] != '"') return allocator.dupe(u8, raw);

    var out = std.array_list.Managed(u8).init(allocator);
    errdefer out.deinit();

    var i: usize = 1;
    while (i + 1 < raw.len) {
        const c = raw[i];
        i += 1;
        if (c != '\\') {
            try out.append(c);
            continue;
        }
        if (i + 1 >= raw.len) {
            try out.append('\\');
            continue;
        }
        const escaped = raw[i];
        i += 1;
        switch (escaped) {
            't' => try out.append('\t'),
            'n' => try out.append('\n'),
            'r' => try out.append('\r'),
            'b' => try out.append(0x08),
            'f' => try out.append(0x0c),
            '\\' => try out.append('\\'),
            '"' => try out.append('"'),
            '0'...'7' => {
                var value: u8 = escaped - '0';
                var digits: usize = 1;
                while (digits < 3 and i + 1 < raw.len and raw[i] >= '0' and raw[i] <= '7') : (digits += 1) {
                    value = value * 8 + (raw[i] - '0');
                    i += 1;
                }
                try out.append(value);
            },
            else => try out.append(escaped),
        }
    }
    return out.toOwnedSlice();
}

test "normalizes simple rename syntax" {
    const normalized = try normalizePath(std.testing.allocator, "old.zig => new.zig");
    defer std.testing.allocator.free(normalized);
    try std.testing.expectEqualStrings("new.zig", normalized);
}

test "matches literal exclude prefixes" {
    try std.testing.expect(isExcludedPath(".flow/state.yaml", &.{".flow/"}));
    try std.testing.expect(!isExcludedPath(".flowish/state.yaml", &.{".flow/"}));
    try std.testing.expect(!isExcludedPath("src/.flow_adapter.zig", &.{".flow/"}));
    try std.testing.expect(isExcludedPath("vendor/lib.zig", &.{"vendor/"}));
    try std.testing.expect(!isExcludedPath("src/vendor_adapter.zig", &.{"vendor/"}));
    try std.testing.expect(!isExcludedPath("glob/[literal]*.zig", &.{"glob/*"}));
}

test "matches literal include prefixes" {
    try std.testing.expect(isIncludedPath("src/app.zig", &.{}));
    try std.testing.expect(isIncludedPath("src/app.zig", &.{"src/"}));
    try std.testing.expect(isIncludedPath("vendor/lib.zig", &.{ "src/", "vendor/" }));
    try std.testing.expect(!isIncludedPath("docs/readme.md", &.{ "src/", "vendor/" }));
    try std.testing.expect(!isIncludedPath("glob/[literal]*.zig", &.{"glob/*"}));
}

test "normalizes braced rename before prefix matching" {
    const normalized = try normalizePath(std.testing.allocator, "src/{old.zig => new.zig}");
    defer std.testing.allocator.free(normalized);
    try std.testing.expectEqualStrings("src/new.zig", normalized);
    try std.testing.expect(isExcludedPath(normalized, &.{"src/"}));
}

test "parses simple and braced rename aliases" {
    const simple = (try parseRenamePath(std.testing.allocator, "old.zig => new.zig")).?;
    defer std.testing.allocator.free(simple.old_path);
    defer std.testing.allocator.free(simple.new_path);
    try std.testing.expectEqualStrings("old.zig", simple.old_path);
    try std.testing.expectEqualStrings("new.zig", simple.new_path);

    const braced = (try parseRenamePath(std.testing.allocator, "src/{old.zig => new.zig}")).?;
    defer std.testing.allocator.free(braced.old_path);
    defer std.testing.allocator.free(braced.new_path);
    try std.testing.expectEqualStrings("src/old.zig", braced.old_path);
    try std.testing.expectEqualStrings("src/new.zig", braced.new_path);
}

test "unquotes git quoted tab path before prefix matching" {
    const normalized = try normalizePath(std.testing.allocator, "\"weird/tab\\tname.txt\"");
    defer std.testing.allocator.free(normalized);
    try std.testing.expectEqualStrings("weird/tab\tname.txt", normalized);
    try std.testing.expect(isExcludedPath(normalized, &.{"weird/"}));
}
