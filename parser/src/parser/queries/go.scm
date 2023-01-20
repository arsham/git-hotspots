(method_declaration name: (field_identifier) @func_name)
(function_declaration name: (identifier) @func_name)
(function_declaration
  body: (block
          (short_var_declaration
            left: (_) @func_name
            right: (expression_list (func_literal)))))
(method_declaration
  body: (block
          (short_var_declaration
            left: (_) @func_name
            right: (expression_list (func_literal)))))
