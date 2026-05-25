; Project-owned Tree-sitter JavaScript symbol candidate query for git-hotspots.
; Query version: javascript-symbol-query-v1.
; Contract: inspect-only JavaScript current-symbol evidence.
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
; Runtime output is inspect-only current-symbol evidence, not symbol history.

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
