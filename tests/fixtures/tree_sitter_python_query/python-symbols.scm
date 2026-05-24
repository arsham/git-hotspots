; Project-owned Tree-sitter Python symbol candidate query for git-hotspots.
; Query version: python-symbol-query-v1.
; Contract: docs/tree-sitter-python-query-contract.md.
;
; Supported capture names:
; - @python.module
; - @python.class.definition
; - @python.function.definition
; - @python.assignment.definition
; - @python.definition.name
; - @python.decorator
;
; This query is intentionally narrower than upstream highlight or tags queries.
; Runtime Python provider output is not implemented by this asset.

(module) @python.module

(class_definition
  name: (identifier) @python.definition.name) @python.class.definition

(function_definition
  name: (identifier) @python.definition.name) @python.function.definition

(assignment
  left: (identifier) @python.definition.name) @python.assignment.definition

(decorator) @python.decorator
