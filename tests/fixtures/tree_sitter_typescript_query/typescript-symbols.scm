; Project-owned Tree-sitter TypeScript symbol candidate query for git-hotspots.
; Query version: typescript-symbol-query-v1.
; Contract: docs/tree-sitter-typescript-query-contract.md.
;
; Supported capture names:
; - @typescript.module
; - @typescript.class.definition
; - @typescript.function.definition
; - @typescript.method.definition
; - @typescript.interface.definition
; - @typescript.type.definition
; - @typescript.enum.definition
; - @typescript.namespace.definition
; - @typescript.variable.definition
; - @typescript.import.statement
; - @typescript.export.statement
; - @typescript.definition.name
;
; This query is intentionally narrower than upstream highlight or tags queries.
; Runtime TypeScript provider output is not implemented by this asset.

(program) @typescript.module

(class_declaration
  name: (type_identifier) @typescript.definition.name) @typescript.class.definition

(abstract_class_declaration
  name: (type_identifier) @typescript.definition.name) @typescript.class.definition

(function_declaration
  name: (identifier) @typescript.definition.name) @typescript.function.definition

(method_definition
  name: (property_identifier) @typescript.definition.name) @typescript.method.definition

(interface_declaration
  name: (type_identifier) @typescript.definition.name) @typescript.interface.definition

(type_alias_declaration
  name: (type_identifier) @typescript.definition.name) @typescript.type.definition

(enum_declaration
  name: (identifier) @typescript.definition.name) @typescript.enum.definition

(internal_module
  name: (identifier) @typescript.definition.name) @typescript.namespace.definition

(internal_module
  name: (nested_identifier) @typescript.definition.name) @typescript.namespace.definition

(variable_declarator
  name: (identifier) @typescript.definition.name) @typescript.variable.definition

(import_statement) @typescript.import.statement

(export_statement) @typescript.export.statement
