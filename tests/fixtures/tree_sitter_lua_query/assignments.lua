function bare_global()
  return 1
end

local local_assigned = function(value)
  return value
end

global_assigned = function()
  return local_assigned(1)
end
