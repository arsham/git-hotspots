; Project-owned Tree-sitter JavaScript symbol candidate query for git-hotspots.
; Query version: javascript-symbol-query-v1.
; Contract: docs/tree-sitter-javascript-query-contract.md.
;
; Supported capture names:
; - @javascript.module
; - @javascript.class.definition
; - @javascript.function.definition
; - @javascript.method.definition
; - @javascript.variable.definition
; - @javascript.commonjs.definition
; - @javascript.definition.name
;
; This query is intentionally narrower than upstream highlight or tags queries.
; Runtime JavaScript provider output is not implemented by this asset.

(program) @javascript.module

(class_declaration
  name: (identifier) @javascript.definition.name) @javascript.class.definition

(function_declaration
  name: (identifier) @javascript.definition.name) @javascript.function.definition

(method_definition
  name: (property_identifier) @javascript.definition.name) @javascript.method.definition

(variable_declarator
  name: (identifier) @javascript.definition.name) @javascript.variable.definition

(assignment_expression
  left: (member_expression
    property: (property_identifier) @javascript.definition.name)) @javascript.commonjs.definition
