; Project-owned Tree-sitter Python symbol candidate query for git-hotspots.
; Query version: python-symbol-query-v1.
; Runtime contract: inspect-only current-symbol enrichment.

(module) @python.module

(class_definition
  name: (identifier) @python.definition.name) @python.class.definition

(function_definition
  name: (identifier) @python.definition.name) @python.function.definition

(assignment
  left: (identifier) @python.definition.name) @python.assignment.definition

(decorator) @python.decorator
