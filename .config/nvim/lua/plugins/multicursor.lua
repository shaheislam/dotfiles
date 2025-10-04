-- ~/.config/nvim/lua/plugins/multicursor.lua
-- Multi-cursor editing with VSCode-like workflow

return {
  {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    event = "VeryLazy",
    config = function()
      local mc = require("multicursor-nvim")
      mc.setup()

      local set = vim.keymap.set

      -- VSCode-style multi-cursor keybindings
      -- Add cursor at next match (like Ctrl+D in VSCode)
      set({ "n", "v" }, "<C-n>", function()
        mc.matchAddCursor(1)
      end, { desc = "Add cursor at next match" })

      -- Add cursor at previous match
      set({ "n", "v" }, "<C-p>", function()
        mc.matchAddCursor(-1)
      end, { desc = "Add cursor at prev match" })

      -- Skip current match and add cursor at next
      set({ "n", "v" }, "<C-x>", function()
        mc.matchSkipCursor(1)
      end, { desc = "Skip and add cursor at next" })

      -- Add cursors above/below current line
      set({ "n", "v" }, "<C-Up>", function()
        mc.lineAddCursor(-1)
      end, { desc = "Add cursor above" })

      set({ "n", "v" }, "<C-Down>", function()
        mc.lineAddCursor(1)
      end, { desc = "Add cursor below" })

      -- Toggle cursor at current position
      set({ "n", "v" }, "<leader>mt", mc.toggleCursor, { desc = "Toggle cursor" })

      -- Add all matches in the buffer
      set({ "n", "v" }, "<leader>ma", mc.matchAllAddCursors, { desc = "Add all matches" })

      -- Rotate to next/prev cursor
      set({ "n", "v" }, "<leader>mn", mc.nextCursor, { desc = "Next cursor" })
      set({ "n", "v" }, "<leader>mp", mc.prevCursor, { desc = "Previous cursor" })

      -- Delete/disable the main cursor
      set({ "n", "v" }, "<leader>mx", mc.deleteCursor, { desc = "Delete main cursor" })

      -- Clear all cursors
      set("n", "<Esc>", function()
        if not mc.cursorsEnabled() then
          mc.enableCursors()
        elseif mc.hasCursors() then
          mc.clearCursors()
        else
          -- Default <Esc> behavior
          vim.cmd("nohlsearch")
        end
      end, { desc = "Clear cursors or search highlight" })

      -- Align cursor columns
      set("v", "<leader>ma", mc.alignCursors, { desc = "Align cursors" })

      -- Split visual selections by regex
      set("v", "S", mc.splitCursors, { desc = "Split cursors by regex" })

      -- Match new cursors within visual selections by regex
      set("v", "M", mc.matchCursors, { desc = "Match cursors by regex" })

      -- Transpose contents at cursors
      set("v", "<leader>mt", function()
        mc.transposeCursors(1)
      end, { desc = "Transpose forwards" })

      set("v", "<leader>mT", function()
        mc.transposeCursors(-1)
      end, { desc = "Transpose backwards" })

      -- Append/insert for each line of visual selections
      set("v", "I", mc.insertVisual, { desc = "Insert at each line" })
      set("v", "A", mc.appendVisual, { desc = "Append at each line" })

      -- Advanced layer for multi-cursor mode navigation
      mc.addKeymapLayer(function(layerSet)
        -- Navigate between cursors with arrow keys in multi-cursor mode
        layerSet({ "n", "v" }, "<left>", mc.prevCursor, { desc = "Previous cursor" })
        layerSet({ "n", "v" }, "<right>", mc.nextCursor, { desc = "Next cursor" })

        -- Enable/disable cursors with Escape
        layerSet("n", "<esc>", function()
          if not mc.cursorsEnabled() then
            mc.enableCursors()
          else
            mc.clearCursors()
          end
        end, { desc = "Toggle/clear cursors" })
      end)
    end,
  },

  -- Add which-key integration for multi-cursor menu
  {
    "folke/which-key.nvim",
    optional = true,
    opts = function(_, opts)
      if opts.spec then
        vim.list_extend(opts.spec, {
          { "<leader>m", group = "multicursor", icon = "󰬳" },
          { "<leader>ma", desc = "Add all matches / Align" },
          { "<leader>mt", desc = "Toggle cursor / Transpose fwd" },
          { "<leader>mT", desc = "Transpose back" },
          { "<leader>mn", desc = "Next cursor" },
          { "<leader>mp", desc = "Previous cursor" },
          { "<leader>mx", desc = "Delete main cursor" },
        })
      end
    end,
  },
}
