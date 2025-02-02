# Gennie.nvim

Nvim plugin for [Gennie Cli](https://github.com/robertoseba/gennie)

## Installation

Add this to your Lazyvim `plugin` folder

```lua
return {
  dir = "~/Code/personal/gennie.nvim",
  config = true,
  keys = {
    { "<leader>a", "<cmd>Gennie<cr>", desc = "Ask Gennie" },
  },
}


