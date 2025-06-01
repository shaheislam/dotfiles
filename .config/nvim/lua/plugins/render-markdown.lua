return {
  "MeanderingProgrammer/render-markdown.nvim",
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "echasnovski/mini.nvim"
  },
  ft = "markdown",
  opts = {
    -- File types to render
    file_types = { "markdown" },

    -- Render modes - when to show rendered view
    render_modes = { "n", "c", "t" },

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
