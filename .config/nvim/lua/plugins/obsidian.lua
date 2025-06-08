-- ~/.config/nvim/lua/plugins/obsidian.lua
local function get_device_name()
  local handle = io.popen("hostname")
  if handle then
    local device = handle:read("*a"):gsub("%s+$", "")
    handle:close()
    return device
  end
  return "unknown"
end

local device = get_device_name()
local workspaces = {
  -- DFE vault
  {
    name = "dfe",
    path = "/Users/shaheislam/Library/Mobile Documents/iCloud~md~obsidian/Documents/Engineering",
  },
  -- PetLab vault
  {
    name = "petlab",
    path = "~/Documents/Obsidian Vault",
  },
}

-- Filter workspaces based on device name
local function get_workspaces_for_device()
  local device_workspaces = {}
  for _, workspace in ipairs(workspaces) do
    if workspace.name == device then
      table.insert(device_workspaces, workspace)
    end
  end
  -- If no device-specific workspace is found, use all workspaces
  if #device_workspaces == 0 then
    return workspaces
  end
  return device_workspaces
end

return {
  "epwalsh/obsidian.nvim",
  version = "*",
  lazy = true,
  ft = "markdown",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  opts = {
    workspaces = get_workspaces_for_device(),

    -- Disable obsidian.nvim UI since we're using render-markdown.nvim
    ui = {
      enable = false,
    },

    completion = {
      nvim_cmp = false,
      mappings = {},
    },

    templates = {
      folder = "Templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
    },

    mappings = {
      ["gf"] = {
        action = function()
          return require("obsidian").util.gf_passthrough()
        end,
        opts = { noremap = false, expr = true, buffer = true },
      },
      ["<leader>ch"] = {
        action = function()
          return require("obsidian").util.toggle_checkbox()
        end,
        opts = { buffer = true },
      },
      ["<cr>"] = {
        action = function()
          return require("obsidian").util.smart_action()
        end,
        opts = { buffer = true, expr = true },
      },
    },

    new_notes_location = "current_dir",

    note_id_func = function(title)
      local suffix = ""
      if title ~= nil then
        suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
      else
        for _ = 1, 4 do
          suffix = suffix .. string.char(math.random(65, 90))
        end
      end
      return tostring(os.time()) .. "-" .. suffix
    end,

    wiki_link_func = "use_alias_only",

    image_name_func = function()
      return string.format("%s-", os.time())
    end,

    attachments = {
      img_folder = "assets/imgs",
    },
  },

  keys = {
    -- Note Management
    { "<leader>on", "<cmd>ObsidianNew<cr>", desc = "New note" },
    { "<leader>oo", "<cmd>ObsidianOpen<cr>", desc = "Open in Obsidian app" },
    { "<leader>ob", "<cmd>ObsidianBacklinks<cr>", desc = "Show backlinks" },
    { "<leader>ot", "<cmd>ObsidianTemplate<cr>", desc = "Insert template" },
    { "<leader>or", "<cmd>ObsidianRename<cr>", desc = "Rename note" },

    -- Search and Navigation
    { "<leader>os", "<cmd>ObsidianSearch<cr>", desc = "Search notes" },
    { "<leader>oq", "<cmd>ObsidianQuickSwitch<cr>", desc = "Quick switch" },
    { "<leader>ol", "<cmd>ObsidianLinks<cr>", desc = "Show links" },
    { "<leader>of", "<cmd>ObsidianFollowLink<cr>", desc = "Follow link" },

    -- Media
    { "<leader>op", "<cmd>ObsidianPasteImg<cr>", desc = "Paste image" },
  },
}
