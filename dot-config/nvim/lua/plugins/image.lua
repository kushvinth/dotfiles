-- NOTE: Inline image rendering is NOT supported in Neovide.
-- Neovide is a standalone GUI frontend (OpenGL/Skia), not a terminal emulator, so
-- it never parses the Kitty Graphics Protocol / Sixel / Überzug++ escape sequences
-- that image.nvim relies on. Images will not render inside Neovide buffers.
--
-- Workaround: open the image under the cursor in the system viewer with `<leader>o`
-- (see lua/config/keymaps.lua), or run terminal nvim in a kitty-protocol terminal
-- (Kitty, Ghostty, WezTerm) where this plugin renders inline as expected.
return {
  {
    "3rd/image.nvim",
    dependencies = { "luarocks.nvim" },
    config = function()
      require("image").setup({
        backend = "kitty", -- or "ueberzug"
        max_height_window_percentage = 50,
        hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.svg" },
      })
    end,
  },
}
