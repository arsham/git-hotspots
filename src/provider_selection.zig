const std = @import("std");
const model = @import("model.zig");
const tree_sitter_zig = @import("tree_sitter_zig.zig");
const tree_sitter_go = @import("tree_sitter_go.zig");
const tree_sitter_python = @import("tree_sitter_python.zig");
const tree_sitter_javascript = @import("tree_sitter_javascript.zig");
const tree_sitter_lua = @import("tree_sitter_lua.zig");
const tree_sitter_rust = @import("tree_sitter_rust.zig");
const tree_sitter_typescript = @import("tree_sitter_typescript.zig");

const Extraction = tree_sitter_zig.Extraction;

fn isSupportedPath(path: []const u8) bool {
    return std.mem.endsWith(u8, path, ".zig") or
        std.mem.endsWith(u8, path, ".go") or
        std.mem.endsWith(u8, path, ".py") or
        tree_sitter_lua.isSupportedPath(path) or
        tree_sitter_rust.isSupportedPath(path) or
        tree_sitter_javascript.isSupportedJavaScriptPath(path) or
        tree_sitter_typescript.isSupportedPath(path);
}

fn extractPath(allocator: std.mem.Allocator, io: std.Io, repo_root: []const u8, path: []const u8) !Extraction {
    if (std.mem.endsWith(u8, path, ".go")) return tree_sitter_go.extractPath(allocator, io, repo_root, path);
    if (std.mem.endsWith(u8, path, ".py")) return tree_sitter_python.extractPath(allocator, io, repo_root, path);
    if (tree_sitter_lua.isSupportedPath(path)) return tree_sitter_lua.extractPath(allocator, io, repo_root, path);
    if (tree_sitter_rust.isSupportedPath(path)) return tree_sitter_rust.extractPath(allocator, io, repo_root, path);
    if (tree_sitter_javascript.isSupportedJavaScriptPath(path)) return tree_sitter_javascript.extractPath(allocator, io, repo_root, path);
    if (tree_sitter_typescript.isSupportedPath(path)) return tree_sitter_typescript.extractPath(allocator, io, repo_root, path);
    return tree_sitter_zig.extractPath(allocator, io, repo_root, path);
}

pub fn attachInspectSymbols(allocator: std.mem.Allocator, io: std.Io, analysis: *model.Analysis) !void {
    const matched_path = analysis.inspect.?.matched_path;
    const symbol_report = try extractPath(allocator, io, analysis.repo_root, matched_path);
    analysis.symbol_report = .{ .provider = symbol_report.provider, .symbols = symbol_report.symbols };
}

pub fn attachProjectSymbols(allocator: std.mem.Allocator, io: std.Io, analysis: *model.Analysis) !void {
    var files: std.array_list.Managed(model.ProjectSymbolFile) = .init(allocator);
    errdefer {
        for (files.items) |file| {
            allocator.free(file.file_path);
            allocator.free(file.provider.input.identity);
            for (file.symbols) |symbol| {
                allocator.free(symbol.path);
                allocator.free(symbol.name);
                if (symbol.current_line_history) |line_history| {
                    for (line_history.sample_commits) |commit| allocator.free(commit);
                    allocator.free(line_history.sample_commits);
                    for (line_history.caveats) |caveat| allocator.free(caveat);
                    allocator.free(line_history.caveats);
                }
            }
            allocator.free(file.symbols);
        }
        files.deinit();
    }

    var unsupported_count: usize = 0;
    var unavailable_count: usize = 0;
    var failed_count: usize = 0;
    var skipped_count: usize = 0;

    for (analysis.results, 0..) |row, index| {
        if (!isSupportedPath(row.path)) {
            unsupported_count += 1;
            continue;
        }
        const extraction = try extractPath(allocator, io, analysis.repo_root, row.path);
        switch (extraction.provider.failure) {
            .unsupported => unsupported_count += 1,
            .unavailable => unavailable_count += 1,
            .failed, .timed_out => failed_count += 1,
            .skipped => skipped_count += 1,
            .ok => {},
        }
        try files.append(.{
            .file_path = try allocator.dupe(u8, row.path),
            .parent_rank = index + 1,
            .parent_score = row.score.total,
            .provider = extraction.provider,
            .symbols = extraction.symbols,
        });
    }

    analysis.project_symbol_report = .{
        .files = try files.toOwnedSlice(),
        .unsupported_count = unsupported_count,
        .unavailable_count = unavailable_count,
        .failed_count = failed_count,
        .skipped_count = skipped_count,
    };
}
