-- ~/.config/nvim/lua/plugins/diffview.lua
return {
	-- Comprehensive git diff and merge tool
	{
		"sindrets/diffview.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		cmd = {
			"DiffviewOpen",
			"DiffviewClose",
			"DiffviewToggleFiles",
			"DiffviewFocusFiles",
			"DiffviewRefresh",
			"DiffviewFileHistory",
		},
		keys = {
			-- Main diffview commands
			{
				"<leader>gv",
				"<cmd>DiffviewOpen<cr>",
				desc = "Open diffview",
			},
			{
				"<leader>gV",
				"<cmd>DiffviewClose<cr>",
				desc = "Close diffview",
			},

			-- File history
			{
				"<leader>gvh",
				"<cmd>DiffviewFileHistory %<cr>",
				desc = "Current file history",
			},
			{
				"<leader>gvH",
				"<cmd>DiffviewFileHistory<cr>",
				desc = "All files history",
			},

			-- Branch comparison
			{
				"<leader>gvm",
				"<cmd>DiffviewOpen HEAD...main<cr>",
				desc = "Compare with main",
			},
			{
				"<leader>gvM",
				"<cmd>DiffviewOpen HEAD...master<cr>",
				desc = "Compare with master",
			},

			-- Merge conflict resolution
			{
				"<leader>gvc",
				"<cmd>DiffviewOpen --merge-tool<cr>",
				desc = "Open merge tool",
			},
		},
		config = function()
			local actions = require("diffview.actions")

			require("diffview").setup({
				diff_binaries = false,
				enhanced_diff_hl = true,
				git_cmd = { "git" },
				hg_cmd = { "hg" },
				use_icons = true,
				show_help_hints = true,
				watch_index = true,

				-- Icon settings
				icons = {
					folder_closed = "",
					folder_open = "",
				},
				signs = {
					fold_closed = "",
					fold_open = "",
					done = "✓",
				},

				-- View settings
				view = {
					default = {
						layout = "diff2_horizontal",
						winbar_info = true,
					},
					merge_tool = {
						layout = "diff3_horizontal",
						disable_diagnostics = true,
						winbar_info = true,
					},
					file_history = {
						layout = "diff2_horizontal",
						winbar_info = true,
					},
				},

				-- File panel settings
				file_panel = {
					listing_style = "tree",
					tree_options = {
						flatten_dirs = true,
						folder_statuses = "only_folded",
					},
					win_config = {
						position = "left",
						width = 35,
						win_opts = {},
					},
				},

				-- Commit log panel
				file_history_panel = {
					log_options = {
						git = {
							single_file = {
								diff_merges = "combined",
							},
							multi_file = {
								diff_merges = "first-parent",
							},
						},
					},
					win_config = {
						position = "bottom",
						height = 16,
						win_opts = {},
					},
				},

				-- Keymaps inside diffview
				keymaps = {
					disable_defaults = false,
					view = {
						-- Navigation
						{ "n", "<tab>", actions.select_next_entry, { desc = "Next entry" } },
						{ "n", "<s-tab>", actions.select_prev_entry, { desc = "Previous entry" } },
						{ "n", "gf", actions.goto_file_edit, { desc = "Go to file" } },
						{ "n", "<C-w><C-f>", actions.goto_file_split, { desc = "Go to file (split)" } },
						{ "n", "<C-w>gf", actions.goto_file_tab, { desc = "Go to file (tab)" } },

						-- Focus
						{ "n", "<leader>e", actions.focus_files, { desc = "Focus file panel" } },
						{ "n", "<leader>b", actions.toggle_files, { desc = "Toggle file panel" } },

						-- Diff controls
						{ "n", "[x", actions.prev_conflict, { desc = "Previous conflict" } },
						{ "n", "]x", actions.next_conflict, { desc = "Next conflict" } },

						-- Stage/unstage in diffview
						{ "n", "<leader>hs", actions.stage_all, { desc = "Stage all" } },
						{ "n", "<leader>hr", actions.unstage_all, { desc = "Unstage all" } },
					},
					file_panel = {
						-- Navigation
						{ "n", "j", actions.next_entry, { desc = "Next entry" } },
						{ "n", "k", actions.prev_entry, { desc = "Previous entry" } },
						{ "n", "<cr>", actions.select_entry, { desc = "Select entry" } },
						{ "n", "-", actions.toggle_stage_entry, { desc = "Toggle stage" } },
						{ "n", "S", actions.stage_all, { desc = "Stage all" } },
						{ "n", "U", actions.unstage_all, { desc = "Unstage all" } },

						-- File operations
						{ "n", "gf", actions.goto_file_edit, { desc = "Go to file" } },
						{ "n", "i", actions.listing_style, { desc = "Toggle listing style" } },
						{ "n", "f", actions.toggle_flatten_dirs, { desc = "Toggle flatten dirs" } },
						{ "n", "R", actions.refresh_files, { desc = "Refresh files" } },

						-- Focus
						{ "n", "<tab>", actions.select_next_entry, { desc = "Next entry" } },
						{ "n", "<s-tab>", actions.select_prev_entry, { desc = "Previous entry" } },
						{ "n", "<leader>e", actions.focus_files, { desc = "Focus files" } },
						{ "n", "<leader>b", actions.toggle_files, { desc = "Toggle files" } },
					},
					file_history_panel = {
						-- Navigation
						{ "n", "g!", actions.options, { desc = "Options" } },
						{ "n", "<C-A-d>", actions.open_in_diffview, { desc = "Open in diffview" } },
						{ "n", "y", actions.copy_hash, { desc = "Copy commit hash" } },

						-- File operations
						{ "n", "gf", actions.goto_file_edit, { desc = "Go to file" } },
						{ "n", "<cr>", actions.select_entry, { desc = "Select entry" } },

						-- Focus
						{ "n", "<tab>", actions.select_next_entry, { desc = "Next entry" } },
						{ "n", "<s-tab>", actions.select_prev_entry, { desc = "Previous entry" } },
						{ "n", "<leader>e", actions.focus_files, { desc = "Focus files" } },
						{ "n", "<leader>b", actions.toggle_files, { desc = "Toggle files" } },
					},
					option_panel = {
						{ "n", "<tab>", actions.select_entry, { desc = "Select entry" } },
						{ "n", "q", actions.close, { desc = "Close" } },
					},
				},
			})
		end,
	},
}
