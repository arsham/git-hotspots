; Project-owned Tree-sitter Lua symbol candidate query for git-hotspots.
; Query version: lua-symbol-query-v1.
; Contract: docs/tree-sitter-lua-query-contract.md.
;
; Supported capture names:
; - @lua.module
; - @lua.function.definition
; - @lua.method.definition
; - @lua.variable.definition
; - @lua.table.field.definition
; - @lua.definition.name
; - @lua.comment
;
; This query is intentionally narrower than upstream highlight or tags queries.

(chunk) @lua.module

(function_declaration
  name: (identifier) @lua.definition.name) @lua.function.definition

(function_declaration
  name: (dot_index_expression
    field: (identifier) @lua.definition.name)) @lua.function.definition

(function_declaration
  name: (method_index_expression
    method: (identifier) @lua.definition.name)) @lua.method.definition

(variable_declaration
  (assignment_statement
    (variable_list
      name: (identifier) @lua.definition.name))) @lua.variable.definition

(assignment_statement
  (variable_list
    name: (identifier) @lua.definition.name)
  (expression_list
    value: (function_definition))) @lua.variable.definition

(assignment_statement
  (variable_list
    name: (dot_index_expression
      field: (identifier) @lua.definition.name))
  (expression_list
    value: (function_definition))) @lua.table.field.definition

(field
  name: (identifier) @lua.definition.name) @lua.table.field.definition

(comment) @lua.comment
