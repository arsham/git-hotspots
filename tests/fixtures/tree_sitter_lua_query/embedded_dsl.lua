-- embedded DSL fixture
local query = [[
SELECT function_not_lua FROM widgets
WHERE name = "function fake()"
]]

local template = [[
{% function also_not_lua() %}
]]

return query .. template
