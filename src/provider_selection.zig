const std = @import("std");
const model = @import("model.zig");
const tree_sitter_zig = @import("tree_sitter_zig.zig");
const tree_sitter_go = @import("tree_sitter_go.zig");
const tree_sitter_python = @import("tree_sitter_python.zig");
const tree_sitter_javascript = @import("tree_sitter_javascript.zig");
const tree_sitter_lua = @import("tree_sitter_lua.zig");
const tree_sitter_rust = @import("tree_sitter_rust.zig");
const tree_sitter_typescript = @import("tree_sitter_typescript.zig");

pub fn attachInspectSymbols(allocator: std.mem.Allocator, io: std.Io, analysis: *model.Analysis) !void {
    const matched_path = analysis.inspect.?.matched_path;
    if (std.mem.endsWith(u8, matched_path, ".go")) {
        const symbol_report = try tree_sitter_go.extractPath(allocator, io, analysis.repo_root, matched_path);
        analysis.symbol_report = .{ .provider = symbol_report.provider, .symbols = symbol_report.symbols };
    } else if (std.mem.endsWith(u8, matched_path, ".py")) {
        const symbol_report = try tree_sitter_python.extractPath(allocator, io, analysis.repo_root, matched_path);
        analysis.symbol_report = .{ .provider = symbol_report.provider, .symbols = symbol_report.symbols };
    } else if (tree_sitter_lua.isSupportedPath(matched_path)) {
        const symbol_report = try tree_sitter_lua.extractPath(allocator, io, analysis.repo_root, matched_path);
        analysis.symbol_report = .{ .provider = symbol_report.provider, .symbols = symbol_report.symbols };
    } else if (tree_sitter_rust.isSupportedPath(matched_path)) {
        const symbol_report = try tree_sitter_rust.extractPath(allocator, io, analysis.repo_root, matched_path);
        analysis.symbol_report = .{ .provider = symbol_report.provider, .symbols = symbol_report.symbols };
    } else if (tree_sitter_javascript.isSupportedJavaScriptPath(matched_path)) {
        const symbol_report = try tree_sitter_javascript.extractPath(allocator, io, analysis.repo_root, matched_path);
        analysis.symbol_report = .{ .provider = symbol_report.provider, .symbols = symbol_report.symbols };
    } else if (tree_sitter_typescript.isSupportedPath(matched_path)) {
        const symbol_report = try tree_sitter_typescript.extractPath(allocator, io, analysis.repo_root, matched_path);
        analysis.symbol_report = .{ .provider = symbol_report.provider, .symbols = symbol_report.symbols };
    } else {
        const symbol_report = try tree_sitter_zig.extractPath(allocator, io, analysis.repo_root, matched_path);
        analysis.symbol_report = .{ .provider = symbol_report.provider, .symbols = symbol_report.symbols };
    }
}
