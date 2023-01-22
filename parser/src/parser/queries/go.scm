(method_declaration
  receiver: (parameter_list) @receiver
  name: (field_identifier) @func_name)

(method_declaration name: (field_identifier) @func_name)

(function_declaration name: (identifier) @func_name)

(function_declaration
  body: (block
          (short_var_declaration
            left: (expression_list) @func_name
            right: (expression_list (func_literal)))))

(method_declaration
  body: (block
          (short_var_declaration
            left: (expression_list) @func_name
            right: (expression_list (func_literal)))))
