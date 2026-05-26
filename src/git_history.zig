const std = @import("std");
const model = @import("model.zig");
const scoring = @import("scoring.zig");

pub const EvidenceBuilder = struct { commit: []u8, timestamp: i64, additions: ?u64, deletions: ?u64 };
pub const FileAgg = struct {
    path: []u8,
    lineage_aliases: std.array_list.Managed([]u8),
    lineage_partial: bool = false,
    change_count: u32 = 0,
    additions: u64 = 0,
    deletions: u64 = 0,
    binary_count: u32 = 0,
    last_ts: i64 = 0,
    last_commit: []u8,
    large_commit: bool = false,
    evidence: std.array_list.Managed(EvidenceBuilder),
    cochanges: std.StringHashMap(u32),
};

pub fn deinitAgg(key: []const u8, agg: FileAgg, allocator: std.mem.Allocator) void {
    allocator.free(key);
    allocator.free(agg.path);
    for (agg.lineage_aliases.items) |alias| allocator.free(alias);
    agg.lineage_aliases.deinit();
    allocator.free(agg.last_commit);
    for (agg.evidence.items) |ev| allocator.free(ev.commit);
    agg.evidence.deinit();
    var it = agg.cochanges.keyIterator();
    while (it.next()) |k| allocator.free(k.*);
    var c = agg.cochanges;
    c.deinit();
}

pub fn addCaveat(allocator: std.mem.Allocator, list: *std.array_list.Managed([]const u8), text: []const u8) !void {
    try list.append(try allocator.dupe(u8, text));
}

pub fn newAgg(allocator: std.mem.Allocator, path: []const u8) !FileAgg {
    const owned_path = try allocator.dupe(u8, path);
    errdefer allocator.free(owned_path);
    const last_commit = try allocator.dupe(u8, "");
    errdefer allocator.free(last_commit);
    return .{
        .path = owned_path,
        .lineage_aliases = std.array_list.Managed([]u8).init(allocator),
        .last_commit = last_commit,
        .evidence = std.array_list.Managed(EvidenceBuilder).init(allocator),
        .cochanges = std.StringHashMap(u32).init(allocator),
    };
}

pub fn resolveAliasOwned(allocator: std.mem.Allocator, aliases: *std.StringHashMap([]u8), path: []const u8) ![]u8 {
    var current = path;
    var depth: usize = 0;
    while (aliases.get(current)) |next| {
        current = next;
        depth += 1;
        if (depth > 64) break;
    }
    return allocator.dupe(u8, current);
}

pub fn putAlias(allocator: std.mem.Allocator, aliases: *std.StringHashMap([]u8), old_path: []const u8, canonical: []const u8) !void {
    if (std.mem.eql(u8, old_path, canonical)) return;
    if (aliases.getPtr(old_path)) |value| {
        const new_value = try allocator.dupe(u8, canonical);
        allocator.free(value.*);
        value.* = new_value;
        return;
    }
    try aliases.ensureUnusedCapacity(1);
    const owned_key = try allocator.dupe(u8, old_path);
    errdefer allocator.free(owned_key);
    const owned_value = try allocator.dupe(u8, canonical);
    aliases.putAssumeCapacityNoClobber(owned_key, owned_value);
}

pub fn addAliasToAgg(allocator: std.mem.Allocator, map: *std.StringHashMap(FileAgg), canonical: []const u8, alias: []const u8) !void {
    if (std.mem.eql(u8, canonical, alias)) return;
    const agg = map.getPtr(canonical) orelse blk: {
        try map.ensureUnusedCapacity(1);
        const owned_key = try allocator.dupe(u8, canonical);
        errdefer allocator.free(owned_key);
        const new_agg = try newAgg(allocator, canonical);
        map.putAssumeCapacityNoClobber(owned_key, new_agg);
        break :blk map.getPtr(canonical).?;
    };
    for (agg.lineage_aliases.items) |existing| {
        if (std.mem.eql(u8, existing, alias)) return;
    }
    try agg.lineage_aliases.append(try allocator.dupe(u8, alias));
    std.mem.sort([]u8, agg.lineage_aliases.items, {}, stringSliceLessThan);
}

pub fn hasLineageAlias(row: model.Result, requested: []const u8) bool {
    for (row.lineage_aliases) |alias| {
        if (std.mem.eql(u8, alias, requested)) return true;
    }
    return false;
}

fn stringSliceLessThan(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

pub fn freeStringList(allocator: std.mem.Allocator, values: []const []const u8) void {
    for (values) |value| allocator.free(value);
    allocator.free(values);
}

pub fn dupeStringList(allocator: std.mem.Allocator, values: []const []const u8) ![][]const u8 {
    const out = try allocator.alloc([]const u8, values.len);
    var initialized: usize = 0;
    errdefer {
        for (out[0..initialized]) |owned| allocator.free(owned);
        allocator.free(out);
    }
    for (values, 0..) |value, i| {
        out[i] = try allocator.dupe(u8, value);
        initialized += 1;
    }
    return out;
}

pub fn finishCommit(allocator: std.mem.Allocator, map: *std.StringHashMap(FileAgg), paths: []const []const u8) !void {
    if (paths.len == 0) return;
    for (paths) |p| {
        if (map.getPtr(p)) |agg| {
            if (paths.len > 50) agg.large_commit = true;
            for (paths) |other| {
                if (std.mem.eql(u8, p, other)) continue;
                if (agg.cochanges.getPtr(other)) |count| {
                    count.* += 1;
                } else {
                    try agg.cochanges.ensureUnusedCapacity(1);
                    const owned_key = try allocator.dupe(u8, other);
                    agg.cochanges.putAssumeCapacityNoClobber(owned_key, 1);
                }
            }
        }
    }
}

pub fn appendResult(allocator: std.mem.Allocator, io: std.Io, out: *std.array_list.Managed(model.Result), repo_root: []const u8, agg: FileAgg, head_ts: i64) !void {
    var row_caveats = std.array_list.Managed([]const u8).init(allocator);
    errdefer {
        for (row_caveats.items) |c| allocator.free(c);
        row_caveats.deinit();
    }
    if (agg.binary_count > 0) try addCaveat(allocator, &row_caveats, "binary or non-text churn unavailable for some changes");
    if (agg.large_commit) try addCaveat(allocator, &row_caveats, "changed in a large commit; evidence may include generated or vendor-like churn");

    const full = try std.fs.path.join(allocator, &.{ repo_root, agg.path });
    defer allocator.free(full);
    var size: ?u64 = null;
    if (std.Io.Dir.openFileAbsolute(io, full, .{})) |f| {
        var file = f;
        defer file.close(io);
        size = (try file.stat(io)).size;
    } else |_| {
        try addCaveat(allocator, &row_caveats, "path is deleted or not present at HEAD");
    }

    var cc_list = std.array_list.Managed(model.CoChange).init(allocator);
    errdefer {
        for (cc_list.items) |cc| allocator.free(cc.path);
        cc_list.deinit();
    }
    var cc_it = agg.cochanges.iterator();
    while (cc_it.next()) |e| try cc_list.append(.{ .path = try allocator.dupe(u8, e.key_ptr.*), .count = e.value_ptr.* });
    std.mem.sort(model.CoChange, cc_list.items, {}, cochangeLessThan);
    if (cc_list.items.len > 5) {
        for (cc_list.items[5..]) |cc| allocator.free(cc.path);
        cc_list.shrinkRetainingCapacity(5);
    }
    var cc_total: u32 = 0;
    for (cc_list.items) |cc| cc_total += cc.count;

    var evs = std.array_list.Managed(model.Evidence).init(allocator);
    errdefer {
        for (evs.items) |ev| allocator.free(ev.commit);
        evs.deinit();
    }
    for (agg.evidence.items) |ev| try evs.append(.{ .commit = try allocator.dupe(u8, ev.commit), .timestamp = ev.timestamp, .additions = ev.additions, .deletions = ev.deletions });

    const lineage_aliases = try dupeStringList(allocator, agg.lineage_aliases.items);
    errdefer freeStringList(allocator, lineage_aliases);

    const churn = agg.additions + agg.deletions;
    const breakdown = scoring.score(agg.change_count, churn, agg.last_ts, head_ts, cc_total);
    try out.append(.{
        .path = try allocator.dupe(u8, agg.path),
        .lineage_aliases = lineage_aliases,
        .lineage_partial = agg.lineage_partial,
        .score = breakdown,
        .change_count = agg.change_count,
        .additions = agg.additions,
        .deletions = agg.deletions,
        .churn = churn,
        .last_changed_timestamp = agg.last_ts,
        .last_changed_commit = try allocator.dupe(u8, agg.last_commit),
        .current_size = size,
        .cochanges = try cc_list.toOwnedSlice(),
        .confidence = scoring.confidence(agg.change_count, row_caveats.items.len),
        .caveats = try row_caveats.toOwnedSlice(),
        .evidence = try evs.toOwnedSlice(),
    });
}

fn cochangeLessThan(_: void, a: model.CoChange, b: model.CoChange) bool {
    if (a.count != b.count) return a.count > b.count;
    return std.mem.lessThan(u8, a.path, b.path);
}
