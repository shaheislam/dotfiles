return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-mini/mini.nvim"
  },
  ft = "markdown",
  -- Disable for large markdown files to prevent lag
  enabled = function()
    local line_count = vim.api.nvim_buf_line_count(0)
    return line_count < 5000
  end,
  opts = {
    -- File types to render
    file_types = { "markdown" },

    -- Render modes - only in normal mode for performance
    -- Removed "c" and "t" modes to reduce lag during scrolling
    render_modes = { "n" },

    -- Headings with beautiful styling
    heading = {
      enabled = true,
      sign = true,
      position = "overlay",
      icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
      backgrounds = {
        "RenderMarkdownH1Bg",
        "RenderMarkdownH2Bg",
        "RenderMarkdownH3Bg",
        "RenderMarkdownH4Bg",
        "RenderMarkdownH5Bg",
        "RenderMarkdownH6Bg",
      },
      foregrounds = {
        "RenderMarkdownH1",
        "RenderMarkdownH2",
        "RenderMarkdownH3",
        "RenderMarkdownH4",
        "RenderMarkdownH5",
        "RenderMarkdownH6",
      },
    },

    -- Code blocks with syntax highlighting
    code = {
      enabled = true,
      sign = true,
      style = "full",
      position = "left",
      language_icon = true,
      language_name = true,
      border = "hide",
      highlight = "RenderMarkdownCode",
    },

    -- Beautiful bullet points
    bullet = {
      enabled = true,
      icons = { "●", "○", "◆", "◇" },
      right_pad = 0,
      highlight = "RenderMarkdownBullet",
    },

    -- Checkboxes with custom states
    checkbox = {
      enabled = true,
      unchecked = {
        icon = "󰄱 ",
        highlight = "RenderMarkdownUnchecked",
      },
      checked = {
        icon = "󰱒 ",
        highlight = "RenderMarkdownChecked",
      },
      custom = {
        todo = { raw = "[-]", rendered = "󰥔 ", highlight = "RenderMarkdownTodo" },
      },
    },

    -- Quote blocks
    quote = {
      enabled = true,
      icon = "▋",
      highlight = "RenderMarkdownQuote",
    },

    -- Tables with borders
    pipe_table = {
      enabled = true,
      preset = "none",
      style = "full",
      cell = "padded",
      border = {
        "┌", "┬", "┐",
        "├", "┼", "┤",
        "└", "┴", "┘",
        "│", "─",
      },
      head = "RenderMarkdownTableHead",
      row = "RenderMarkdownTableRow",
    },

    -- Links with icons
    link = {
      enabled = true,
      image = "󰥶 ",
      email = "󰀓 ",
      hyperlink = "󰌹 ",
      highlight = "RenderMarkdownLink",
      custom = {
        web = { pattern = "^http", icon = "󰖟 " },
        github = { pattern = "github%.com", icon = "󰊤 " },
      },
    },

    -- Callouts (like Obsidian)
    callout = {
      note = { raw = "[!NOTE]", rendered = "󰋽 Note", highlight = "RenderMarkdownInfo" },
      tip = { raw = "[!TIP]", rendered = "󰌶 Tip", highlight = "RenderMarkdownSuccess" },
      important = { raw = "[!IMPORTANT]", rendered = "󰅾 Important", highlight = "RenderMarkdownHint" },
      warning = { raw = "[!WARNING]", rendered = "󰀪 Warning", highlight = "RenderMarkdownWarn" },
      caution = { raw = "[!CAUTION]", rendered = "󰳦 Caution", highlight = "RenderMarkdownError" },
    },

    -- Window options for concealing
    win_options = {
      conceallevel = {
        default = vim.o.conceallevel,
        rendered = 2,
      },
      concealcursor = {
        default = vim.o.concealcursor,
        rendered = "",
      },
    },
  },
}
