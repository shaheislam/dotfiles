-- ~/.config/nvim/lua/plugins/git-conflict.lua
return {
	-- Git conflict resolution with visual markers and quick commands
	{
		"akinsho/git-conflict.nvim",
		version = "*",
		event = "VeryLazy",
		config = function()
			require("git-conflict").setup({
				default_mappings = {
					ours = "co", -- Choose ours
					theirs = "ct", -- Choose theirs
					none = "c0", -- Choose none (delete conflict)
					both = "cb", -- Choose both
					next = "]x", -- Next conflict
					prev = "[x", -- Previous conflict
				},
				default_commands = true, -- Enable :GitConflictChooseOurs, etc.
				disable_diagnostics = false, -- Keep diagnostics enabled
				list_opener = "copen", -- Open conflicts in quickfix
				highlights = {
					incoming = "DiffAdd",
					current = "DiffText",
				},
			})

			-- Additional keybinding for listing all conflicts
			vim.keymap.set("n", "<leader>gx", "<cmd>GitConflictListQf<cr>", { desc = "List git conflicts" })
		end,
	},
}
