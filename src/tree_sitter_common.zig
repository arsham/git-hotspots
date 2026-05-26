const std = @import("std");

pub const default_max_file_bytes: u64 = 1024 * 1024;

pub fn readBoundedFile(allocator: std.mem.Allocator, io: std.Io, repo_root: []const u8, repo_relative_path: []const u8, max_file_bytes: u64) !?[]u8 {
    const full_path = try std.fs.path.join(allocator, &.{ repo_root, repo_relative_path });
    defer allocator.free(full_path);

    const link_stat = std.Io.Dir.statFile(.cwd(), io, full_path, .{ .follow_symlinks = false }) catch return null;
    if (link_stat.kind != .file) return null;

    const file = std.Io.Dir.openFileAbsolute(io, full_path, .{}) catch return null;
    defer file.close(io);

    const stat = file.stat(io) catch return null;
    if (stat.kind != .file or stat.size > max_file_bytes) return null;

    const source = allocator.alloc(u8, @intCast(stat.size)) catch return null;
    errdefer allocator.free(source);
    const bytes_read = file.readPositionalAll(io, source, 0) catch {
        allocator.free(source);
        return null;
    };
    if (bytes_read != source.len) {
        allocator.free(source);
        return null;
    }

    return source;
}
