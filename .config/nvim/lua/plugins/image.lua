return {
  "3rd/image.nvim",
  lazy = false,
  build = false, -- so that it doesn't build the rock https://github.com/3rd/image.nvim/issues/91#issuecomment-2453430239
  opts = {
    backend = "kitty", -- "kitty" or "ueberzug"
    processor = "magick_cli", -- or "magick_rock"
    integrations = {
      markdown = {
        enabled = true,
        clear_in_insert_mode = false,
        download_remote_images = true,
        only_render_image_at_cursor = false,
        only_render_image_at_cursor_mode = "popup", -- "popup" or "inline"
        filetypes = { "markdown", "vimwiki" },
      },
      neorg = {
        enabled = false,
      },
      typst = {
        enabled = false,
      },
      html = {
        enabled = false,
      },
      css = {
        enabled = false,
      },
    },
    max_width = nil,
    max_height = nil,
    max_width_window_percentage = nil,
    max_height_window_percentage = 50,
    window_overlap_clear_enabled = false, -- toggles images when windows are overlapped
    window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "scrollview" },
    editor_only_render_when_focused = false,
    tmux_show_only_in_active_window = false,
    hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif" },
  },
  keys = {
    { "<leader>io", "<cmd>lua require('image').toggle()<cr>", desc = "Toggle images" },
    { "<leader>ic", "<cmd>lua require('image').clear()<cr>", desc = "Clear images" },
  },
}
