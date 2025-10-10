-- Language-Specific Autocmds - Per-language configuration and behavior
-- These autocmds provide language-specific settings and enhancements

local M = {}

local function augroup(name)
  return vim.api.nvim_create_augroup("languages_" .. name, { clear = true })
end

function M.setup()
  -- ============================================================================
  -- DevOps & Cloud Formatting
  -- ============================================================================

  -- Enforce 2-space indentation for YAML/JSON (cloud config standard)
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("yaml_json_indent"),
    pattern = { "yaml", "yml", "json", "jsonc", "yaml.ansible", "yaml.docker-compose" },
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
      vim.opt_local.softtabstop = 2
      vim.opt_local.expandtab = true
    end,
  })

  -- CRITICAL: Makefiles REQUIRE tabs (spaces will break make)
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("makefile_tabs"),
    pattern = "make",
    callback = function()
      vim.opt_local.expandtab = false
      vim.opt_local.tabstop = 4
      vim.opt_local.shiftwidth = 4
    end,
  })

  -- ============================================================================
  -- Python
  -- ============================================================================

  -- Python: Auto-activate virtual environment and set specific settings
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter" }, {
    group = augroup("python_venv"),
    pattern = "*.py",
    callback = function()
      -- Look for venv in project root
      local venv_path = vim.fn.getcwd() .. "/venv"
      local venv_bin = venv_path .. "/bin/activate"
      if vim.fn.filereadable(venv_bin) == 1 then
        vim.env.VIRTUAL_ENV = venv_path
        vim.env.PATH = venv_path .. "/bin:" .. vim.env.PATH
        vim.notify("Python venv activated: " .. venv_path, vim.log.levels.INFO)
      end

      -- Python-specific settings
      vim.opt_local.colorcolumn = "88" -- Black's default line length
      vim.opt_local.textwidth = 88
    end,
  })

  -- ============================================================================
  -- Go
  -- ============================================================================

  -- Go: Format imports and code on save
  vim.api.nvim_create_autocmd("BufWritePre", {
    group = augroup("go_format"),
    pattern = "*.go",
    callback = function()
      -- Organize imports first
      local params = vim.lsp.util.make_range_params()
      params.context = { only = { "source.organizeImports" } }
      local result = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 1000)
      for _, res in pairs(result or {}) do
        for _, action in pairs(res.result or {}) do
          if action.edit then
            vim.lsp.util.apply_workspace_edit(action.edit, "utf-8")
          end
        end
      end
      -- Then format
      vim.lsp.buf.format({ async = false })
    end,
  })

  -- Go specific settings
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("go_settings"),
    pattern = "go",
    callback = function()
      vim.opt_local.expandtab = false
      vim.opt_local.tabstop = 4
      vim.opt_local.shiftwidth = 4
      vim.opt_local.colorcolumn = "100"

      -- Go-specific keymaps
      vim.keymap.set("n", "<leader>gr", "<cmd>!go run %<cr>", { buffer = true, desc = "Go Run" })
      vim.keymap.set("n", "<leader>gb", "<cmd>!go build %:p:h<cr>", { buffer = true, desc = "Go Build" })
      vim.keymap.set("n", "<leader>gt", "<cmd>!go test ./...<cr>", { buffer = true, desc = "Go Test All" })
      vim.keymap.set("n", "<leader>gT", "<cmd>!go test -v ./...<cr>", { buffer = true, desc = "Go Test Verbose" })
      vim.keymap.set("n", "<leader>gc", "<cmd>!go mod tidy<cr>", { buffer = true, desc = "Go Mod Tidy" })
    end,
  })

  -- ============================================================================
  -- Rust
  -- ============================================================================

  -- Rust: Auto-reload when Cargo.toml changes
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup("cargo_reload"),
    pattern = "Cargo.toml",
    callback = function()
      vim.notify("Cargo.toml updated, reloading workspace...", vim.log.levels.INFO)
      vim.cmd("LspRestart rust_analyzer")
    end,
  })

  -- Rust specific settings
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("rust_settings"),
    pattern = "rust",
    callback = function()
      vim.opt_local.colorcolumn = "100"

      -- Rust-specific keymaps
      vim.keymap.set("n", "<leader>rc", "<cmd>!cargo check<cr>", { buffer = true, desc = "Cargo Check" })
      vim.keymap.set("n", "<leader>rb", "<cmd>!cargo build<cr>", { buffer = true, desc = "Cargo Build" })
      vim.keymap.set("n", "<leader>rr", "<cmd>!cargo run<cr>", { buffer = true, desc = "Cargo Run" })
      vim.keymap.set("n", "<leader>rt", "<cmd>!cargo test<cr>", { buffer = true, desc = "Cargo Test" })
      vim.keymap.set("n", "<leader>rf", "<cmd>!cargo fmt<cr>", { buffer = true, desc = "Cargo Format" })
      vim.keymap.set("n", "<leader>rd", "<cmd>!cargo doc --open<cr>", { buffer = true, desc = "Cargo Docs" })
    end,
  })

  -- ============================================================================
  -- JavaScript/TypeScript
  -- ============================================================================

  -- JavaScript/TypeScript specific settings
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("javascript_typescript"),
    pattern = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
      vim.opt_local.softtabstop = 2
      vim.opt_local.colorcolumn = "100"

      -- JS/TS specific keymaps
      vim.keymap.set("n", "<leader>jn", "<cmd>!npm run<cr>", { buffer = true, desc = "NPM Run" })
      vim.keymap.set("n", "<leader>jt", "<cmd>!npm test<cr>", { buffer = true, desc = "NPM Test" })
      vim.keymap.set("n", "<leader>jb", "<cmd>!npm run build<cr>", { buffer = true, desc = "NPM Build" })
      vim.keymap.set("n", "<leader>jd", "<cmd>!npm run dev<cr>", { buffer = true, desc = "NPM Dev" })
    end,
  })

  -- Auto-reload when package.json changes
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = augroup("package_json_reload"),
    pattern = "package.json",
    callback = function()
      vim.notify("package.json updated, consider running npm install", vim.log.levels.INFO)
    end,
  })

  -- ============================================================================
  -- Lua
  -- ============================================================================

  -- Lua specific settings (especially for Neovim config)
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("lua_settings"),
    pattern = "lua",
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
      vim.opt_local.softtabstop = 2

      -- Lua-specific keymaps for Neovim config
      if vim.fn.expand("%:p"):match("nvim") then
        vim.keymap.set("n", "<leader>lr", "<cmd>source %<cr>", { buffer = true, desc = "Reload Lua File" })
        vim.keymap.set("n", "<leader>lR", "<cmd>Lazy reload<cr>", { buffer = true, desc = "Reload Plugins" })
      end
    end,
  })

  -- ============================================================================
  -- Shell Scripts
  -- ============================================================================

  -- Shell script specific settings
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("shell_settings"),
    pattern = { "sh", "bash", "zsh", "fish" },
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2

      -- Shell-specific keymaps
      vim.keymap.set("n", "<leader>sx", "<cmd>!chmod +x %<cr>", { buffer = true, desc = "Make Executable" })
      vim.keymap.set("n", "<leader>sr", "<cmd>!bash %<cr>", { buffer = true, desc = "Run Script" })
      vim.keymap.set("n", "<leader>sc", "<cmd>!shellcheck %<cr>", { buffer = true, desc = "ShellCheck" })
    end,
  })

  -- ============================================================================
  -- Docker
  -- ============================================================================

  -- Docker-specific settings
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("docker_settings"),
    pattern = { "dockerfile", "Dockerfile" },
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2

      -- Docker-specific keymaps
      vim.keymap.set("n", "<leader>db", "<cmd>!docker build -t temp .<cr>", { buffer = true, desc = "Docker Build" })
      vim.keymap.set("n", "<leader>dr", "<cmd>!docker run temp<cr>", { buffer = true, desc = "Docker Run" })
    end,
  })

  -- ============================================================================
  -- Terraform
  -- ============================================================================

  -- Terraform specific settings
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("terraform_settings"),
    pattern = { "terraform", "tf", "hcl" },
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
      vim.opt_local.commentstring = "# %s"

      -- Terraform-specific keymaps
      vim.keymap.set("n", "<leader>ti", "<cmd>!terraform init<cr>", { buffer = true, desc = "Terraform Init" })
      vim.keymap.set("n", "<leader>tp", "<cmd>!terraform plan<cr>", { buffer = true, desc = "Terraform Plan" })
      vim.keymap.set("n", "<leader>ta", "<cmd>!terraform apply<cr>", { buffer = true, desc = "Terraform Apply" })
      vim.keymap.set("n", "<leader>tf", "<cmd>!terraform fmt<cr>", { buffer = true, desc = "Terraform Format" })
      vim.keymap.set("n", "<leader>tv", "<cmd>!terraform validate<cr>", { buffer = true, desc = "Terraform Validate" })
    end,
  })

  -- ============================================================================
  -- Ansible
  -- ============================================================================

  -- Ansible specific settings
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("ansible_settings"),
    pattern = { "yaml.ansible", "ansible" },
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2

      -- Ansible-specific keymaps
      vim.keymap.set("n", "<leader>ap", "<cmd>!ansible-playbook %<cr>", { buffer = true, desc = "Run Playbook" })
      vim.keymap.set("n", "<leader>al", "<cmd>!ansible-lint %<cr>", { buffer = true, desc = "Ansible Lint" })
      vim.keymap.set("n", "<leader>av", "<cmd>!ansible-vault encrypt %<cr>", { buffer = true, desc = "Vault Encrypt" })
    end,
  })

  -- ============================================================================
  -- Markdown
  -- ============================================================================

  -- Markdown specific settings
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("markdown_settings"),
    pattern = "markdown",
    callback = function()
      vim.opt_local.wrap = true
      vim.opt_local.spell = true
      vim.opt_local.conceallevel = 2
      vim.opt_local.textwidth = 80

      -- Markdown-specific keymaps
      vim.keymap.set("n", "<leader>mp", "<cmd>MarkdownPreview<cr>", { buffer = true, desc = "Markdown Preview" })
      vim.keymap.set("n", "<leader>mt", "<cmd>TableFormat<cr>", { buffer = true, desc = "Format Table" })
    end,
  })

  -- ============================================================================
  -- SQL
  -- ============================================================================

  -- SQL specific settings
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("sql_settings"),
    pattern = "sql",
    callback = function()
      vim.opt_local.shiftwidth = 4
      vim.opt_local.tabstop = 4
      vim.opt_local.commentstring = "-- %s"
    end,
  })

  -- ============================================================================
  -- Code Quality Standards
  -- ============================================================================

  -- Visual indicator for long lines in code files
  vim.api.nvim_create_autocmd("FileType", {
    group = augroup("long_line_indicator"),
    pattern = { "python", "go", "typescript", "javascript", "lua", "rust", "c", "cpp", "java" },
    callback = function()
      -- Show columns at 80, 100, 120 characters
      vim.opt_local.colorcolumn = "80,100,120"
    end,
  })
end

return M