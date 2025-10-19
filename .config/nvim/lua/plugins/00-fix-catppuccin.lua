-- Fix for catppuccin.special.bufferline error
-- This file loads BEFORE other plugins due to the 00- prefix
-- It patches the require function to handle the missing module gracefully

local original_require = require
_G.require = function(module)
  if module == "catppuccin.special.bufferline" then
    -- Return a dummy module that provides the expected get_theme function
    return {
      get_theme = function()
        return {} -- Return empty highlights to avoid errors
      end
    }
  end
  return original_require(module)
end

return {}