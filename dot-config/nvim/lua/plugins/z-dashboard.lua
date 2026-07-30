local function capture(cmd, raw)
  local f = assert(io.popen(cmd, "r"))
  local s = assert(f:read("*a"))
  f:close()
  if raw then
    return s
  end
  s = string.gsub(s, "^%s+", "")
  s = string.gsub(s, "%s+$", "")
  s = string.gsub(s, "[\n\r]+", " ")
  return s
end

local function split(source, sep)
  local result, i = {}, 1
  while true do
    local a, b = source:find(sep)
    if not a then
      break
    end
    local candidat = source:sub(1, a - 1)
    if candidat ~= "" then
      result[i] = candidat
    end
    i = i + 1
    source = source:sub(b + 1)
  end
  if source ~= "" then
    result[i] = source
  end
  return result
end

local function rpad(s, w)
  return s .. string.rep(" ", w - #s)
end

local W = 12

local frames = {
  { -- big
    rpad(" _  __", W), rpad("| |/ /", W), rpad("| ' / ", W),
    rpad("|  <  ", W), rpad("| . \\ ", W), rpad("|_|\\_\\", W),
    rpad("", W), rpad("", W),
  },
  { -- banner
    rpad("#    # ", W), rpad("#   #  ", W), rpad("#  #   ", W),
    rpad("###    ", W), rpad("#  #   ", W), rpad("#   #  ", W),
    rpad("#    # ", W), rpad("", W),
  },
  { -- script
    rpad(" ,     ", W), rpad("/|   / ", W), rpad(" |__/  ", W),
    rpad(" | \\   ", W), rpad(" |  \\_/", W), rpad("", W),
    rpad("", W), rpad("", W),
  },
  { -- starwars
    rpad(" __  ___ ", W), rpad("|  |/  / ", W), rpad("|  '  /  ", W),
    rpad("|    <   ", W), rpad("|  .  \\ ", W), rpad("|__|\\__\\", W),
    rpad("", W), rpad("", W),
  },
  { -- standard
    rpad(" _  __", W), rpad("| |/ /", W), rpad("| ' / ", W),
    rpad("| . \\ ", W), rpad("|_|\\_\\", W), rpad("", W),
    rpad("", W), rpad("", W),
  },
  { -- slant
    rpad("    __ __", W), rpad("   / //_/", W), rpad("  / ,<   ", W),
    rpad(" / /| |  ", W), rpad("/_/ |_|  ", W), rpad("", W),
    rpad("", W), rpad("", W),
  },
  { -- rectangles
    rpad("", W), rpad(" _____ ", W), rpad("|  |  |", W),
    rpad("|    -|", W), rpad("|__|__|", W), rpad("", W),
    rpad("", W), rpad("", W),
  },
  { -- chunky
    rpad(" __  __ ", W), rpad("|  |/  |", W), rpad("|     < ", W),
    rpad("|__|\\__|", W), rpad("", W), rpad("", W),
    rpad("", W), rpad("", W),
  },
  { -- shadow
    rpad(" |  / ", W), rpad(" ' /  ", W), rpad(" . \\  ", W),
    rpad("_|\\_\\", W), rpad("", W), rpad("", W),
    rpad("", W), rpad("", W),
  },
  { -- smshadow
    rpad("  _/ ", W), rpad(" / / ", W), rpad("/_  \\", W),
    rpad("  /  ", W), rpad(" /_  ", W), rpad("", W),
    rpad("", W), rpad("", W),
  },
}

local quotes = {
  { "write code that writes code",                          "  — you" },
  { "there is no place like ~",                             "  — home" },
  { "git commit -m \"yolo\"",                               "  — production" },
  { "it works on my machine",                               "  — famous last words" },
  { "sudo !!",                                              "  — the magic words" },
  { "the cake is a lie",                                    "  — portal" },
  { "hello, world",                                         "  — day one" },
  { "42",                                                   "  — deep thought" },
  { "trust the process",                                    "  — the pipeline" },
  { "exit, pursued by a bear",                              "  — shakespeare" },
  { "this is fine",                                         "  — doge" },
  { "to be determined...",                                  "  — every sprint" },
  { "it's not a bug, it's a feature",                       "  — every dev ever" },
  { "./configure && make && make install",                  "  — the good old days" },
  { "all your base are belong to us",                       "  — zero wing" },
  { ":wq",                                                  "  — later" },
  { "just one more line...",                                "  — famous last words" },
  { "the quick brown fox jumps over the lazy dog",          "  — pangram" },
  { "kill -9",                                              "  — the nuclear option" },
  { "have you tried turning it off and on again?",          "  — IT crowd" },
  { "there is no place like 127.0.0.1",                     "  — localhost" },
  { "#define true false",                                   "  — oops" },
  { "01001010 01011010",                                    "  — Z in binary" },
  { "rm -rf /",                                             "  — the last resort" },
  { "pwd && ls && cd ~ && pwd && ls",                       "  — me lost" },
}

local colors = {
  "#ff0000", "#ff5f00", "#ffaf00", "#ffff00",
  "#00ff00", "#00afff", "#005fff", "#ff00ff",
}
for i, c in ipairs(colors) do
  vim.api.nvim_set_hl(0, "ZDash" .. i, { fg = c, bold = true })
end

return {
  { "folke/snacks.nvim", opts = { dashboard = { enabled = false } } },

  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function(_, dashboard)
      math.randomseed(os.time())

      local quote = quotes[math.random(#quotes)]

      local header_lines = {}
      for _ = 1, 6 do table.insert(header_lines, "") end
      for _, l in ipairs(frames[1]) do table.insert(header_lines, l) end
      table.insert(header_lines, quote[1] .. quote[2])
      table.insert(header_lines, "")
      table.insert(header_lines, "")

      dashboard.section.header.val = header_lines
      dashboard.section.header.opts.hl = "ZDash1"

      dashboard.section.buttons.val = {
        dashboard.button("f", " " .. " Find File",       "<cmd> lua LazyVim.pick()() <cr>"),
        dashboard.button("n", " " .. " New File",        [[<cmd> ene <BAR> startinsert <cr>]]),
        dashboard.button("r", " " .. " Recent Files",    [[<cmd> lua LazyVim.pick("oldfiles")() <cr>]]),
        dashboard.button("g", " " .. " Find Text",       [[<cmd> lua LazyVim.pick("live_grep")() <cr>]]),
        dashboard.button("s", " " .. " Restore Session", [[<cmd> lua require("persistence").load() <cr>]]),
        dashboard.button("c", " " .. " Config",          "<cmd> lua LazyVim.pick.config_files()() <cr>"),
        dashboard.button("l", "󰒲 " .. " Lazy",            "<cmd> Lazy <cr>"),
        dashboard.button("x", " " .. " Lazy Extras",     "<cmd> LazyExtras <cr>"),
        dashboard.button("q", " " .. " Quit",            "<cmd> qa <cr>"),
      }
      for _, button in ipairs(dashboard.section.buttons.val) do
        button.opts.hl = "AlphaButtons"
        button.opts.hl_shortcut = "AlphaShortcut"
      end
      dashboard.section.buttons.opts.hl = "AlphaButtons"
      dashboard.section.footer.opts.hl = "AlphaFooter"

      dashboard.section.footer.val = "⚡ " .. capture("whoami") .. "@" .. capture("hostname -s")

      dashboard.opts.layout[1].val = 8

      return dashboard
    end,
    config = function(_, dashboard)
      local function redraw()
        pcall(vim.cmd.AlphaRedraw)
      end

      if vim.o.filetype == "lazy" then
        vim.cmd.close()
        vim.api.nvim_create_autocmd("User", {
          once = true,
          pattern = "AlphaReady",
          callback = function()
            require("lazy").show()
          end,
        })
      end

      require("alpha").setup(dashboard.opts)

      local nf, nc = #frames, #colors
      local fi, ci, tick = 1, 1, 0
      local max_ticks = 25
      local quote_line = dashboard.section.header.val[#dashboard.section.header.val - 2]

      vim.api.nvim_create_autocmd("User", {
        pattern = "AlphaReady",
        callback = function()
          vim.defer_fn(function()
            local timer = vim.uv.new_timer()
            timer:start(150, 150, vim.schedule_wrap(function()
              if tick >= max_ticks then
                dashboard.section.header.val = frames[1]
                dashboard.section.header.opts.hl = "AlphaHeader"
                redraw()
                if timer and not timer:is_closing() then
                  timer:stop()
                  timer:close()
                end
                return
              end
              tick = tick + 1
              fi = fi % nf + 1
              ci = ci % nc + 1

              local h = {}
              for _ = 1, 6 do table.insert(h, "") end
              for _, l in ipairs(frames[fi]) do table.insert(h, l) end
              table.insert(h, quote_line)
              table.insert(h, "")
              table.insert(h, "")

              dashboard.section.header.val = h
              dashboard.section.header.opts.hl = "ZDash" .. ci
              redraw()
            end))
          end, 300)
        end,
        once = true,
      })

      vim.api.nvim_create_autocmd("User", {
        once = true,
        pattern = "LazyVimStarted",
        callback = function()
          local stats = require("lazy").stats()
          local ms = (math.floor(stats.startuptime * 100 + 0.5) / 100)
          dashboard.section.footer.val = "⚡ Neovim loaded "
            .. stats.loaded
            .. "/"
            .. stats.count
            .. " plugins in "
            .. ms
            .. "ms"
          redraw()
        end,
      })
    end,
  },
}
