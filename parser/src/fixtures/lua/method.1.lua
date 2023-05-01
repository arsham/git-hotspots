local M = {}

M.method_one = function() end

function M.method_two() end

function M:method_three()
  M.nested = function() end
end
