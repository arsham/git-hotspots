local exports = {}
local dynamic_name = "run"
exports[dynamic_name] = function()
  return true
end
exports.static = function()
  return false
end
return exports
