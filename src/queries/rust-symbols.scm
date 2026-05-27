; Project-owned Tree-sitter Rust symbol candidate query for git-hotspots.
; Query version: rust-symbol-query-v1.
; Contract: docs/tree-sitter-rust-query-contract.md.
;
; Supported capture names:
; - @rust.file
; - @rust.definition.name
; - @rust.function.definition
; - @rust.trait.method.definition
; - @rust.trait.definition
; - @rust.impl.block
; - @rust.module.definition
; - @rust.struct.definition
; - @rust.enum.definition
; - @rust.enum.variant.definition
; - @rust.const.definition
; - @rust.static.definition
; - @rust.macro.definition
; - @rust.macro.name
; - @rust.macro.invocation
; - @rust.attribute
; - @rust.comment
;
; This query is intentionally narrower than upstream highlight or tags queries.

(source_file) @rust.file

(function_item
  name: (identifier) @rust.definition.name) @rust.function.definition

(function_signature_item
  name: (identifier) @rust.definition.name) @rust.trait.method.definition

(trait_item
  name: (type_identifier) @rust.definition.name) @rust.trait.definition

(impl_item) @rust.impl.block

(mod_item
  name: (identifier) @rust.definition.name) @rust.module.definition

(struct_item
  name: (type_identifier) @rust.definition.name) @rust.struct.definition

(enum_item
  name: (type_identifier) @rust.definition.name) @rust.enum.definition

(enum_variant
  name: (identifier) @rust.definition.name) @rust.enum.variant.definition

(const_item
  name: (identifier) @rust.definition.name) @rust.const.definition

(static_item
  name: (identifier) @rust.definition.name) @rust.static.definition

(macro_definition
  name: (identifier) @rust.definition.name) @rust.macro.definition

(macro_invocation
  macro: (_) @rust.macro.name) @rust.macro.invocation

(attribute_item) @rust.attribute
(line_comment) @rust.comment
(block_comment) @rust.comment
