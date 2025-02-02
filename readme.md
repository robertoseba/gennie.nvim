# Gennie.nvim

Nvim plugin for [Gennie Cli](https://github.com/robertoseba/gennie)

## Installation

Add this to your Lazyvim `plugin` folder

```lua

return {
  dir = "~/Code/personal/gennie.nvim",
  config = true,
  dependencies = {
    "folke/which-key.nvim",
    optional = true,
    opts = {
      defaults = {
        ["<leader>a"] = { name = "+gennie" },
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
      "<leader>aa",
      function()
        return require("gennie").ask_gennie_visual()
      end,
      desc = "Ask Gennie With Selected",
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

