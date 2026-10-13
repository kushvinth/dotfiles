-- Local completion from the Ollama model FreeFlow already keeps loaded
-- (gemma3:4b, services.local-dictation), so no second model in memory.
-- It's a chat model, not FIM, so completions are on demand: Alt-. asks.
-- Keys avoid Alt-[ / Alt-] (zellij swap layouts) and Alt-hjkl (skhd, zellij).
return {
  {
    "milanglacier/minuet-ai.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    event = "InsertEnter",
    opts = {
      provider = "openai_compatible",
      n_completions = 1,
      context_window = 2048,
      request_timeout = 5,
      provider_options = {
        openai_compatible = {
          api_key = "TERM", -- Ollama needs no key; minuet wants a set env var name
          name = "Ollama",
          end_point = "http://localhost:11434/v1/chat/completions",
          model = "gemma3:4b",
          optional = { max_tokens = 96, top_p = 0.9 },
        },
      },
      virtualtext = {
        auto_trigger_ft = {}, -- manual only: don't compete with dictation for the GPU
        keymap = {
          accept = "<A-a>",
          accept_line = "<A-s>",
          prev = "<A-,>",
          next = "<A-.>", -- also requests a completion
          dismiss = "<A-e>",
        },
      },
    },
  },
}
