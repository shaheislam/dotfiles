-- Auto-install treesitter parsers on startup
local function ensure_treesitter_parsers()
  local parsers = {
    "bash",
    "c",
    "css",
    "diff",
    "html",
    "javascript",
    "json",
    "lua",
    "markdown",
    "markdown_inline",
    "python",
    "query",
    "regex",
    "toml",
    "typescript",
    "vim",
    "vimdoc",
    "yaml",
  }

  -- Defer installation to avoid blocking startup
  vim.defer_fn(function()
    local ok, ts_install = pcall(require, "nvim-treesitter.install")
    if not ok then
      return
    end

    for _, parser in ipairs(parsers) do
      if not ts_install.installed_parsers()[parser] then
        vim.cmd("TSInstall " .. parser)
      end
    end
  end, 100)
end

-- Run on startup
vim.api.nvim_create_autocmd("VimEnter", {
  callback = ensure_treesitter_parsers,
  once = true,
})

return {}