; Project-owned Tree-sitter TSX symbol candidate query for git-hotspots.
; Query version: tsx-symbol-query-v1.
; Contract: docs/tree-sitter-typescript-query-contract.md.
;
; Supported capture names:
; - @tsx.module
; - @tsx.class.definition
; - @tsx.function.definition
; - @tsx.method.definition
; - @tsx.interface.definition
; - @tsx.type.definition
; - @tsx.enum.definition
; - @tsx.namespace.definition
; - @tsx.variable.definition
; - @tsx.import.statement
; - @tsx.export.statement
; - @tsx.jsx.syntax
; - @tsx.definition.name
;
; This query is intentionally narrower than upstream highlight or tags queries.
; Runtime TSX provider output is not implemented by this asset.

(program) @tsx.module

(class_declaration
  name: (type_identifier) @tsx.definition.name) @tsx.class.definition

(abstract_class_declaration
  name: (type_identifier) @tsx.definition.name) @tsx.class.definition

(function_declaration
  name: (identifier) @tsx.definition.name) @tsx.function.definition

(method_definition
  name: (property_identifier) @tsx.definition.name) @tsx.method.definition

(interface_declaration
  name: (type_identifier) @tsx.definition.name) @tsx.interface.definition

(type_alias_declaration
  name: (type_identifier) @tsx.definition.name) @tsx.type.definition

(enum_declaration
  name: (identifier) @tsx.definition.name) @tsx.enum.definition

(internal_module
  name: (identifier) @tsx.definition.name) @tsx.namespace.definition

(internal_module
  name: (nested_identifier) @tsx.definition.name) @tsx.namespace.definition

(variable_declarator
  name: (identifier) @tsx.definition.name) @tsx.variable.definition

(import_statement) @tsx.import.statement

(export_statement) @tsx.export.statement

(jsx_element) @tsx.jsx.syntax

(jsx_self_closing_element) @tsx.jsx.syntax
