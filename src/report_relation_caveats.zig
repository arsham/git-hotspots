const std = @import("std");
const model = @import("model.zig");
const fmt = @import("report_format.zig");

pub fn hasShownRecordCaveats(records: []const model.RelationRecord) bool {
    for (records) |record| {
        if (record.caveats.len > 0) return true;
    }
    return false;
}

pub fn renderTableRefs(writer: anytype, records: []const model.RelationRecord, row_index: usize) !void {
    const caveats = records[row_index].caveats;
    if (caveats.len == 0) {
        try writer.writeAll("none");
        return;
    }
    var emitted = false;
    for (caveats, 0..) |_, caveat_index| {
        if (isDuplicateInRow(records, row_index, caveat_index)) continue;
        if (emitted) try writer.writeByte(',');
        try writer.print("C{d}", .{markerNumberFor(records, row_index, caveat_index)});
        emitted = true;
    }
    if (!emitted) try writer.writeAll("none");
}

pub fn renderMarkdownRefs(writer: anytype, records: []const model.RelationRecord, row_index: usize) !void {
    const caveats = records[row_index].caveats;
    if (caveats.len == 0) {
        try writer.writeAll("none");
        return;
    }
    var emitted = false;
    for (caveats, 0..) |_, caveat_index| {
        if (isDuplicateInRow(records, row_index, caveat_index)) continue;
        if (emitted) try writer.writeAll(", ");
        try writer.print("C{d}", .{markerNumberFor(records, row_index, caveat_index)});
        emitted = true;
    }
    if (!emitted) try writer.writeAll("none");
}

pub fn renderTableSummary(writer: anytype, records: []const model.RelationRecord) !void {
    if (!hasShownRecordCaveats(records)) return;
    try writer.writeAll("  row caveats:\n");
    var marker: usize = 1;
    for (records, 0..) |record, row_index| {
        for (record.caveats, 0..) |caveat, caveat_index| {
            if (isDuplicateThrough(records, row_index, caveat_index)) continue;
            try writer.print("    C{d}: {s}\n", .{ marker, caveat });
            marker += 1;
        }
    }
}

pub fn renderMarkdownSummary(writer: anytype, records: []const model.RelationRecord) !void {
    if (!hasShownRecordCaveats(records)) return;
    try writer.writeAll("\n- Row caveat references:\n");
    var marker: usize = 1;
    for (records, 0..) |record, row_index| {
        for (record.caveats, 0..) |caveat, caveat_index| {
            if (isDuplicateThrough(records, row_index, caveat_index)) continue;
            try writer.print("  - C{d}: ", .{marker});
            try fmt.markdownText(writer, caveat);
            try writer.writeByte('\n');
            marker += 1;
        }
    }
}

fn markerNumberFor(records: []const model.RelationRecord, row_index: usize, caveat_index: usize) usize {
    const caveat = records[row_index].caveats[caveat_index];
    var marker: usize = 0;
    for (records[0 .. row_index + 1], 0..) |record, current_row| {
        const limit = if (current_row == row_index) caveat_index + 1 else record.caveats.len;
        for (record.caveats[0..limit], 0..) |candidate, current_caveat| {
            if (isDuplicateThrough(records, current_row, current_caveat)) continue;
            marker += 1;
            if (std.mem.eql(u8, candidate, caveat)) return marker;
        }
    }
    unreachable;
}

fn isDuplicateInRow(records: []const model.RelationRecord, row_index: usize, caveat_index: usize) bool {
    const caveat = records[row_index].caveats[caveat_index];
    for (records[row_index].caveats[0..caveat_index]) |previous| {
        if (std.mem.eql(u8, previous, caveat)) return true;
    }
    return false;
}

fn isDuplicateThrough(records: []const model.RelationRecord, row_index: usize, caveat_index: usize) bool {
    const caveat = records[row_index].caveats[caveat_index];
    for (records[0..row_index]) |record| {
        for (record.caveats) |previous| {
            if (std.mem.eql(u8, previous, caveat)) return true;
        }
    }
    for (records[row_index].caveats[0..caveat_index]) |previous| {
        if (std.mem.eql(u8, previous, caveat)) return true;
    }
    return false;
}

fn testRecord(caveats: [][]const u8) model.RelationRecord {
    return .{
        .kind = .contains,
        .direction = .source_to_target,
        .source_key = "source",
        .target_key = "target",
        .evidence_basis = "basis",
        .provider_name = "provider",
        .provider_input_identity = "input",
        .freshness = .fresh,
        .failure = .ok,
        .confidence = .high,
        .caveats = caveats,
        .sort_key = "sort",
    };
}

test "relationship caveat references are first-seen and compact" {
    var row_one_caveats = [_][]const u8{ "shared caveat", "extra caveat" };
    var row_two_caveats = [_][]const u8{"shared caveat"};
    var row_three_caveats = [_][]const u8{};
    const records = [_]model.RelationRecord{
        testRecord(row_one_caveats[0..]),
        testRecord(row_two_caveats[0..]),
        testRecord(row_three_caveats[0..]),
    };

    var row_one: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer row_one.deinit();
    try renderTableRefs(&row_one.writer, &records, 0);
    try std.testing.expectEqualStrings("C1,C2", row_one.written());

    var row_two: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer row_two.deinit();
    try renderTableRefs(&row_two.writer, &records, 1);
    try std.testing.expectEqualStrings("C1", row_two.written());

    var row_three: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer row_three.deinit();
    try renderTableRefs(&row_three.writer, &records, 2);
    try std.testing.expectEqualStrings("none", row_three.written());

    var summary: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer summary.deinit();
    try renderTableSummary(&summary.writer, &records);
    try std.testing.expectEqualStrings("  row caveats:\n    C1: shared caveat\n    C2: extra caveat\n", summary.written());
}
