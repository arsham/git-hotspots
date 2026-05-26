; Project-owned Rust symbol query for the test-only query contract proof.
; This is not an upstream highlight/tags query and is not wired into runtime output.

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
