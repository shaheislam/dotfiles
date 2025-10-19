-- Compatibility patch for Telescope with newer nvim-treesitter versions
-- Provides missing functions that Telescope expects from older nvim-treesitter API

return {
  {
    "nvim-telescope/telescope.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    init = function()
      -- Patch nvim-treesitter modules for Telescope compatibility
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          -- Patch parsers module with ft_to_lang and get_parser
          local has_parsers, parsers = pcall(require, "nvim-treesitter.parsers")
          if has_parsers then
            -- Add ft_to_lang if missing
            if not parsers.ft_to_lang then
              parsers.ft_to_lang = function(ft)
                -- Use vim.treesitter.language.get_lang with fallback
                local ok, lang = pcall(vim.treesitter.language.get_lang, ft)
                if ok and lang then
                  return lang
                end

                -- Custom mappings for special cases
                local ft_map = {
                  javascriptreact = "tsx",
                  typescriptreact = "tsx",
                  sh = "bash",
                  zsh = "bash",
                }

                return ft_map[ft] or ft
              end
            end

            -- Add get_parser if missing
            if not parsers.get_parser then
              parsers.get_parser = function(bufnr, lang)
                -- Try different methods to get or create a parser

                -- Method 1: Try vim.treesitter.get_parser (newer API)
                local ok1, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
                if ok1 and parser then
                  return parser
                end

                -- Method 2: Try to get the language tree directly
                local ok2, parser2 = pcall(vim.treesitter.get_string_parser, "", lang)
                if ok2 and parser2 then
                  -- Create a proper parser for the buffer
                  local ok3, real_parser = pcall(vim.treesitter.get_parser, bufnr)
                  if ok3 then
                    return real_parser
                  end
                end

                -- Method 3: Start treesitter highlighting which creates a parser
                pcall(vim.treesitter.start, bufnr, lang)

                -- Try to get the parser again after starting
                local ok4, final_parser = pcall(vim.treesitter.get_parser, bufnr)
                if ok4 and final_parser then
                  return final_parser
                end

                -- Last resort: return a mock parser object that won't crash
                return {
                  parse = function() return {} end,
                  trees = function() return {} end,
                }
              end
            end
          end

          -- Create/patch configs module with is_enabled and get_module
          -- This fixes the "attempt to call field 'is_enabled' (a nil value)" error
          local configs_module = {
            -- Always return true for highlight checking since we want highlighting
            is_enabled = function(_, _, _)
              return true
            end,
            -- Return a simple config object for get_module
            get_module = function(module_name)
              if module_name == "highlight" then
                return {
                  enable = true,
                  additional_vim_regex_highlighting = false,
                }
              end
              return {}
            end,
          }

          -- Make configs module available
          package.loaded["nvim-treesitter.configs"] = configs_module
        end,
        desc = "Patch nvim-treesitter for Telescope compatibility",
      })
    end,
  },
}