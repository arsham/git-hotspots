const std = @import("std");

const c = @cImport({
    @cInclude("tree_sitter/api.h");
});

extern fn tree_sitter_python() *const c.TSLanguage;

pub fn main() !void {
    const parser = c.ts_parser_new() orelse return error.ParserCreateFailed;
    defer c.ts_parser_delete(parser);

    if (!c.ts_parser_set_language(parser, tree_sitter_python())) return error.LanguageAssignmentFailed;

    const source =
        \\def proof():
        \\    return 1
        \\
    ;
    const source_len = std.math.cast(u32, source.len) orelse return error.SourceTooLarge;
    const tree = c.ts_parser_parse_string(parser, null, source.ptr, source_len) orelse return error.ParseFailed;
    defer c.ts_tree_delete(tree);

    const root = c.ts_tree_root_node(tree);
    if (c.ts_node_has_error(root)) return error.ParseHasError;

    const root_kind = std.mem.span(c.ts_node_type(root));
    if (!std.mem.eql(u8, root_kind, "module")) return error.UnexpectedRootKind;

    const child_count = c.ts_node_named_child_count(root);
    if (child_count != 1) return error.UnexpectedNamedChildCount;

    const child = c.ts_node_named_child(root, 0);
    const child_kind = std.mem.span(c.ts_node_type(child));
    if (!std.mem.eql(u8, child_kind, "function_definition")) return error.UnexpectedChildKind;
}
