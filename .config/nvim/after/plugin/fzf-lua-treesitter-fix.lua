-- Permanent fix for fzf-lua treesitter-context compatibility issues
-- This file patches fzf-lua to work with older versions of nvim-treesitter-context
-- and handles race conditions with window validation

local function patch_fzf_lua()
  local ok, builtin = pcall(require, "fzf-lua.previewer.builtin")
  if not ok then
    return
  end

  -- Get the TSContext table
  local TSContext = builtin.TSContext
  if not TSContext then
    return
  end

  -- Store original update function
  local original_update = TSContext.update

  -- Override TSContext.update with our patched version
  TSContext.update = function(winid, bufnr, opts)
    -- Early return if TSContext.setup fails
    if not TSContext.setup or not TSContext.setup(opts) then
      return
    end

    -- Check if window and buffer are still valid before proceeding
    if not vim.api.nvim_win_is_valid(winid) or not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    -- Safely check if buffer is still associated with window
    local ok_win, win_buf = pcall(vim.api.nvim_win_get_buf, winid)
    if not ok_win or win_buf ~= bufnr then
      return
    end

    -- Safely call close_leaked_contexts (may not exist in older versions)
    local render = require("treesitter-context.render")
    if render.close_leaked_contexts then
      pcall(render.close_leaked_contexts)
    elseif render.close_contexts then
      pcall(render.close_contexts, {})
    end

    -- Safely get context with window validation
    local context_ranges, context_lines
    local ok_context = pcall(function()
      -- Double-check window is still valid right before calling
      if not vim.api.nvim_win_is_valid(winid) then
        return false
      end
      -- IMPORTANT: context.get only takes winid, not bufnr!
      local ctx = require("treesitter-context.context")
      context_ranges, context_lines = ctx.get(winid)
      return true
    end)

    if not ok_context then
      return
    end

    -- Handle the rest of the update logic
    if not context_ranges or #context_ranges == 0 then
      if TSContext.close then
        TSContext.close(winid)
      end
    else
      if not context_lines then
        return
      end

      -- Open the context
      local function open()
        if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_win_is_valid(winid) then
          local ok_open = pcall(function()
            vim.api.nvim_win_call(winid, function()
              require("treesitter-context.render").open(bufnr, winid, context_ranges, context_lines)
            end)
          end)
          if ok_open then
            TSContext._winids[tostring(winid)] = bufnr
          end
        end
      end
      open()
    end
  end

  -- Also patch the Previewer.base:update_ts_context to add window validation
  local Previewer = builtin.Previewer
  if Previewer and Previewer.base then
    local original_update_ts_context = Previewer.base.update_ts_context

    Previewer.base.update_ts_context = function(self)
      -- Call original validation logic
      if original_update_ts_context then
        -- Wrap in pcall to handle any errors gracefully
        pcall(function()
          -- Extra validation before calling original
          if self.win and self.win.preview_winid and vim.api.nvim_win_is_valid(self.win.preview_winid) then
            original_update_ts_context(self)
          end
        end)
      end
    end
  end
end

-- Apply the patch when this file loads
patch_fzf_lua()

-- Also apply after lazy.nvim finishes loading plugins
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyLoad",
  callback = function(event)
    if event.data == "fzf-lua" then
      vim.defer_fn(patch_fzf_lua, 100)
    end
  end,
})

-- Apply patch on VimEnter as a fallback
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(patch_fzf_lua, 500)
  end,
})