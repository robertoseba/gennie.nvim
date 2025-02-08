# Gennie.nvim

Neovim plugin for [Gennie Cli](https://github.com/robertoseba/gennie)

This is a very simple plugin create for my own personal use. It's also my first foray into Neovim plugin and Lua (so don't expect too much from it!)
I use it on my work everyday and it helps me a lot. Especially with the custom profiles.

## Installation

1. Create a `gennie.lua` inside your Lazyvim `plugins` folder
2. Add the following contents (configure it as you wish)

```lua

return {
  dir = "~/Code/personal/gennie.nvim",
  config = true,
  opts = {
    default_model = "gpt-4o",
    default_profile = "default",
  },
  dependencies = {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      spec = {
        { "<leader>a", group = "Gennie", mode = { "n", "v" } },
      },
      icons = {
        rules = {
          { pattern = "gennie", icon = LazyVim.config.icons.kinds.Event, color = "orange" },
        },
      },
    },
  },
  keys = {
    {
      "<leader>aa",
      function()
        return require("gennie").ask_gennie()
      end,
      desc = "Ask Gennie",
      mode = "n",
    },
    {
      "<leader>af",
      function()
        return require("gennie").ask_gennie({ is_followup = true })
      end,
      desc = "Ask Gennie (Follow Up)",
      mode = "n",
    },
    {
      "<leader>aa",
      function()
        return require("gennie").ask_gennie_visual()
      end,
      desc = "Ask Gennie With Selected",
      mode = "v",
    },
    {
      "<leader>af",
      function()
        return require("gennie").ask_gennie_visual({ is_followup = true })
      end,
      desc = "Ask Gennie With Selected (Follow up)",
      mode = "v",
    },
    {
      "<leader>ac",
      function()
        return require("gennie").set_config()
      end,
      desc = "Config Gennie",
      mode = { "n", "v" },
    },
    {
      "<leader>al",
      function()
        return require("gennie").last_answer()
      end,
      desc = "View last answer",
      mode = { "n", "v" },
    },
  },
}

