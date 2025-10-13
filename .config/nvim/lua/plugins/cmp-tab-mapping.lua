-- Enhanced nvim-cmp configuration with Tab key mapping
-- This makes Tab work exactly like Ctrl-Y to confirm completion

return {
  -- Override nvim-cmp configuration to add Tab key mapping
  {
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      -- Override BOTH <tab> (lowercase) and <Tab> (uppercase) to ensure it works
      -- LazyVim uses lowercase <tab> by default for snippets, we're overriding it
      opts.mapping = vim.tbl_extend("force", opts.mapping or {}, {
        -- Override the lowercase <tab> that LazyVim uses
        ["<tab>"] = LazyVim.cmp.confirm({ select = true }),
        -- Also set uppercase <Tab> for consistency
        ["<Tab>"] = LazyVim.cmp.confirm({ select = true }),
      })

      return opts
    end,
  },
}