const std = @import("std");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_zig() *const c.TSLanguage;

pub fn main() !void {
    const parser = c.ts_parser_new() orelse return error.ParserCreateFailed;
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_zig())) return error.LanguageAssignmentFailed;

    const source = "const x = 1;";
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source.len) orelse return error.ParseFailed;
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    const root_kind = std.mem.span(c.ts_node_type(root));
    if (!std.mem.eql(u8, root_kind, "source_file")) return error.UnexpectedRootKind;
}
