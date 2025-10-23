-- ~/.config/nvim/lua/plugins/themes.lua
-- Colorscheme configurations consolidated from misc.lua and colorscheme.lua
-- All themes have consistent styling applied via autocmds/styling.lua

return {
  -- Catppuccin Mocha theme (available for toggling)
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 999,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      show_end_of_buffer = false,
      term_colors = true,
      dim_inactive = {
        enabled = false,
        shade = "dark",
        percentage = 0.15,
      },
      no_italic = false,
      no_bold = false,
      no_underline = false,
      -- Note: Individual styles are overridden by autocmds/styling.lua for consistency
      styles = {
        comments = { "italic" },
        conditionals = { "italic" },
        loops = { "italic" },
        functions = { "italic" },
        keywords = { "bold", "italic" },
        strings = {},
        variables = {},
        numbers = {},
        booleans = { "bold" },
        properties = {},
        types = { "bold", "italic" },
        operators = {},
      },
      integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = false,
        treesitter = true,
        notify = true,
        mini = {
          enabled = true,
          indentscope_color = "",
        },
        telescope = {
          enabled = true,
        },
        which_key = true,
        indent_blankline = {
          enabled = true,
          scope_color = "",
          colored_indent_levels = false,
        },
        dashboard = true,
        neotree = true,
        noice = true,
        hop = false,
        markdown = true,
        mason = true,
        native_lsp = {
          enabled = true,
          underlines = {
            errors = { "underline" },
            hints = { "underline" },
            warnings = { "underline" },
            information = { "underline" },
          },
        },
        bufferline = false, -- Explicitly disable bufferline integration
      },
    },
    config = function(_, opts)
      require("catppuccin").setup(opts)
    end,
  },

  -- OneDark theme (default theme)
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000, -- Highest priority to load as default
    opts = {
      style = 'dark',
      transparent = true, -- Match catppuccin transparency
      term_colors = true,
      ending_tildes = false,
      cmp_itemkind_reverse = false,
      -- Note: Individual styles are overridden by autocmds/styling.lua for consistency
      code_style = {
        comments = 'italic',
        keywords = 'bold,italic',
        functions = 'italic',
        strings = 'none',
        variables = 'none'
      },
      highlights = {
        -- Enhanced styling for specific syntax groups
        ["@type"] = { fmt = "bold,italic" },
        ["@type.builtin"] = { fmt = "bold,italic" },
        ["@keyword"] = { fmt = "bold,italic" },
        ["@keyword.function"] = { fmt = "bold,italic" },
        ["@boolean"] = { fmt = "bold" },
        ["@conditional"] = { fmt = "italic" },
        ["@repeat"] = { fmt = "italic" },
      },
    },
    config = function(_, opts)
      require("onedark").setup(opts)
      vim.cmd([[colorscheme onedark]])
    end,
  },

  -- Tokyo Night Storm theme (third theme for cycling)
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 998,
    opts = {
      style = "storm",
      transparent = true,
      terminal_colors = true,
      -- Note: Individual styles are overridden by autocmds/styling.lua for consistency
      styles = {
        comments = { italic = true },
        keywords = { italic = true }, -- Changed from false to match our standard
      },
    },
  },

  -- Kanagawa theme - Japanese art inspired
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    priority = 997,
    opts = {
      transparent = true,
      terminal_colors = true,
      colors = {
        theme = {
          all = {
            ui = {
              bg_gutter = "none"
            }
          }
        }
      },
    },
  },

  -- Rose Pine theme - Elegant warm palette
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 996,
    opts = {
      variant = "main", -- main, moon, or dawn
      dark_variant = "main",
      dim_inactive_windows = false,
      extend_background_behind_borders = true,
      styles = {
        bold = true,
        italic = true,
        transparency = true,
      },
    },
  },

  -- Nightfox theme - Multiple variants
  {
    "EdenEast/nightfox.nvim",
    lazy = false,
    priority = 995,
    opts = {
      options = {
        transparent = true,
        terminal_colors = true,
        dim_inactive = false,
        -- Note: Individual styles are overridden by autocmds/styling.lua for consistency
        styles = {
          comments = "italic",
          keywords = "bold,italic", -- Changed from just "bold" to match our standard
          types = "italic,bold",
        },
      },
    },
  },

  -- Gruvbox Material theme - Modern Gruvbox
  {
    "sainnhe/gruvbox-material",
    lazy = false,
    priority = 994,
    config = function()
      vim.g.gruvbox_material_background = "medium" -- soft, medium, hard
      vim.g.gruvbox_material_transparent_background = 1
      vim.g.gruvbox_material_enable_italic = 1
      vim.g.gruvbox_material_enable_bold = 1
    end,
  },

  -- Everforest theme - Comfortable green forest
  {
    "sainnhe/everforest",
    lazy = false,
    priority = 993,
    config = function()
      vim.g.everforest_background = "medium" -- hard, medium, soft
      vim.g.everforest_transparent_background = 1
      vim.g.everforest_enable_italic = 1
      vim.g.everforest_better_performance = 1
    end,
  },

  -- GitHub theme - GitHub's color schemes
  {
    "projekt0n/github-nvim-theme",
    lazy = false,
    priority = 992,
    config = function()
      require("github-theme").setup({
        options = {
          transparent = true,
          terminal_colors = true,
          dim_inactive = false,
          -- Note: Individual styles are overridden by autocmds/styling.lua for consistency
          styles = {
            comments = "italic",
            keywords = "bold,italic", -- Changed from just "bold" to match our standard
            types = "italic,bold",
          },
        },
      })
    end,
  },

  -- Cyberdream theme - Modern cyberpunk aesthetic
  {
    "scottmckendry/cyberdream.nvim",
    lazy = false,
    priority = 991,
    opts = {
      transparent = true,
      italic_comments = true,
      hide_fillchars = true,
      borderless_telescope = true,
    },
  },

  -- Nord theme - Arctic bluish theme
  {
    "shaunsingh/nord.nvim",
    lazy = false,
    priority = 990,
    config = function()
      vim.g.nord_contrast = true
      vim.g.nord_borders = false
      vim.g.nord_disable_background = true -- Transparent background
      vim.g.nord_italic = true
      vim.g.nord_bold = false
    end,
  },
}
