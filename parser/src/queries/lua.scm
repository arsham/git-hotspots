(function_declaration name: (identifier) @func_name)
(variable_declaration
  (assignment_statement
    (variable_list
      name: (identifier) @func_name)
    (expression_list
      value: (function_definition))))

(assignment_statement
  (variable_list
    name: (dot_index_expression
      table: (identifier)
      field: (identifier) @func_name))
  (expression_list
    value: (function_definition
      parameters: (parameters))))

(function_declaration
  name: (dot_index_expression
    table: (identifier)
    field: (identifier) @func_name)
  parameters: (parameters))

(function_declaration
  name: (method_index_expression
    table: (identifier)
    method: (identifier) @func_name)
  parameters: (parameters))
