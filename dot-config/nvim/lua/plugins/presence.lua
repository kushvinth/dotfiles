-- New ENGLIZ CONFIG
return {
    "vyfor/cord.nvim",
    event = "VeryLazy", -- Load when needed to improve startup time
    build = ":Cord update"
}

-- -- Discord Rich Presence for Neovim
-- return {
--   "andweeb/presence.nvim",
--   event = "VeryLazy", -- Load when needed to improve startup time
--   opts = {
--     -- General options
--     auto_update = true, -- Update activity based on autocmd events
--     neovim_image_text = "The Superior Text Editor", -- Text displayed when hovered over the Neovim image
--     main_image = "file", -- Main image display (either "neovim" or "file")
--     client_id = "793271441293967371", -- Use your own Discord application client id (not recommended)
--     log_level = nil, -- Log messages at or above this level (one of the following: "debug", "info", "warn", "error")
--     debounce_timeout = 10, -- Number of seconds to debounce events (or calls to `:lua package.loaded.presence:update(<filename>, true)`)
--     blacklist = {}, -- A list of strings or Lua patterns that disable Rich Presence if the current file name, path, or workspace matches
--     buttons = true, -- Configure Rich Presence button(s), either a boolean to enable/disable, a static table ({...}), or a function(buffer: string, repo_url: string|nil): table

--     -- Rich Presence text options
--     file_assets = {}, -- Custom file asset definitions keyed by file names and extensions
--     show_time = true, -- Show the timer

--     -- Rich Presence text templates
--     -- These templates use format string interpolation to display information about the current editor state
--     -- Available variables:
--     -- {file} - The name of the file being edited
--     -- {project} - The name of the project/repository
--     -- {workspace} - The name of the current workspace
--     -- {line} - The current line number
--     -- {total_lines} - The total number of lines in the file

--     editing_text = "Editing %s", -- Format string rendered when an editable file is loaded in the buffer (either string or function(filename: string): string)
--     file_explorer_text = "Browsing %s", -- Format string rendered when browsing a file explorer (either string or function(file_explorer_name: string): string)
--     git_commit_text = "Committing changes", -- Format string rendered when committing changes in git (either string or function(filename: string): string)
--     plugin_manager_text = "Managing plugins", -- Format string rendered when managing plugins (either string or function(plugin_manager_name: string): string)
--     reading_text = "Reading %s", -- Format string rendered when a read-only or unmodifiable file is loaded in the buffer (either string or function(filename: string): string)
--     workspace_text = "Working on %s", -- Format string rendered when in a git repository (either string or function(project_name: string|nil, filename: string): string)
--     line_number_text = "Line %s out of %s", -- Format string rendered when `enable_line_number` is set to true (either string or function(line_number: number, line_count: number): string)

--     -- Additional options
--     enable_line_number = false, -- Displays the current line number instead of the current project
--   },
--   config = function(_, opts)
--     require("presence").setup(opts)
--   end,
-- }
