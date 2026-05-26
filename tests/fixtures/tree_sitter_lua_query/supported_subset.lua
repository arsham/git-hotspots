-- Module comment: table-like words are not exposed.
local CONFIG = "markdown | value"
local mutable_value = 2
local exports = {
  answer = 42,
  build = function(input)
    local ignored_inner = input
    return ignored_inner
  end,
  Nested = {
    skipped = function()
      return "not module-level"
    end,
  },
}

local function local_worker()
  local inside = function()
    return "inside"
  end
  return inside()
end

function exports.make_thing()
  return exports.answer
end

function exports:run()
  return local_worker()
end

return exports
