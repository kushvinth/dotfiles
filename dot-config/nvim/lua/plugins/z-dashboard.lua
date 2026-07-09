return {
  -- disable alpha/snacks dashboard
  { "folke/snacks.nvim", opts = { dashboard = { enabled = false } } },

  -- enable mini.starter with custom header
  {
    "nvim-mini/mini.starter",
    version = false,
    event = "VimEnter",
    opts = function()
      local logo = table.concat({
        [[    ██╗     █████╗ ██████╗ ██████╗      ██╗██████╗ ███████╗ ]],
        [[    ██║    ██╔══██╗██╔══██╗██╔══██╗     ██║██╔══██╗██╔════╝ ]],
        [[    ██║    ███████║██████╔╝██████╔╝     ██║██║  ██║█████╗   ]],
        [[    ██║    ██╔══██║██╔══██╗██╔══██╗     ██║██║  ██║██╔══╝   ]],
        [[    ███████╗██║  ██║██║  ██║██████╔╝     ██║██████╔╝███████╗ ]],
        [[    ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝      ╚═╝╚═════╝ ╚══════╝ ]],
      }, "\n")

      local pad = string.rep(" ", 22)
      local new_section = function(name, action, section)
        return { name = name, action = action, section = pad .. section }
      end

      local starter = require("mini.starter")
      return {
        evaluate_single = true,
        header = logo,
        items = {
          new_section("Find file",       LazyVim.pick(),                        "Telescope"),
          new_section("New file",        "ene | startinsert",                   "Built-in"),
          new_section("Recent files",    LazyVim.pick("oldfiles"),              "Telescope"),
          new_section("Find text",       LazyVim.pick("live_grep"),             "Telescope"),
          new_section("Config",          LazyVim.pick.config_files(),           "Config"),
          new_section("Restore session", [[lua require("persistence").load()]], "Session"),
          new_section("Lazy Extras",     "LazyExtras",                          "Config"),
          new_section("Lazy",            "Lazy",                                "Config"),
          new_section("Quit",            "qa",                                  "Built-in"),
        },
        content_hooks = {
          starter.gen_hook.adding_bullet(pad .. "░ ", false),
          starter.gen_hook.aligning("center", "center"),
        },
      }
    end,
    config = function(_, config)
      if vim.o.filetype == "lazy" then
        vim.cmd.close()
        vim.api.nvim_create_autocmd("User", {
          pattern = "MiniStarterOpened",
          callback = function()
            require("lazy").show()
          end,
        })
      end

      local starter = require("mini.starter")
      starter.setup(config)

      vim.api.nvim_create_autocmd("User", {
        pattern = "LazyVimStarted",
        callback = function(ev)
          local stats = require("lazy").stats()
          local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
          local pad_footer = string.rep(" ", 8)
          starter.config.footer = pad_footer .. "⚡ Neovim loaded " .. stats.count .. " plugins in " .. ms .. "ms"
          if vim.bo[ev.buf].filetype == "ministarter" then
            pcall(starter.refresh)
          end
        end,
      })
    end,
  },
}
