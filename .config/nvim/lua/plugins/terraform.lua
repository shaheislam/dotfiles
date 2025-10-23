-- ~/.config/nvim/lua/plugins/terraform.lua
-- Terraform support and configuration
-- Extracted from misc.lua for better organization

return {
  -- Terraform support (autocmd for .tf files)
  {
    "hashivim/vim-terraform",
    ft = "terraform",
    config = function()
      vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
        pattern = '*.tf',
        callback = function()
          vim.bo.filetype = 'terraform'
        end,
      })
    end,
  },
}
