local Thing = {}
local mt = {
  __index = function(_, key)
    return Thing[key]
  end,
  __call = function()
    return "called"
  end,
}
setmetatable(Thing, mt)

function Thing:new()
  return setmetatable({}, mt)
end

return Thing
