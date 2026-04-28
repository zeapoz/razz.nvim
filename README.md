# 🍓 razz.nvim

A Neovim plugin for managing [RetroAchievements](https://retroachievements.org) code notes.

![Screenshot](assets/screenshot.png)

## Prerequisites

- Neovim 0.9+
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

## Installation (lazy.nvim)

```lua
{
  "zeapoz/razz.nvim",
  opts = {
    emulator_dirs = { "/path/to/emulator_dir" },
  },
}
```

`emulator_dirs` should point to your emulator directories. The plugin reads note data from `emulator_dir/RACache/Data/`.

## Example Configuration

```lua
{
  "zeapoz/razz.nvim",
  opts = {
    emulator_dirs = { "/path/to/emulator_dir" },
  },
  keys = function()
    local notes = require("razz.notes")
    return {
      { "<leader>co", function() notes.open() end, desc = "Open code note" },
      { "<leader>cl", function() notes.open_local() end, desc = "Open local note" },
      { "<leader>cs", function() notes.open_server() end, desc = "Open server note" },
      { "<leader>cn", function() notes.create_new() end, desc = "Create new note" },
    }
  end,
}
```

## Usage

| Keybinding | Function |
|------------|-----------|
| `<leader>co` | Open all notes (server + local) |
| `<leader>cl` | Open local notes only |
| `<leader>cs` | Open server notes only |
| `<leader>cn` | Create a new note |

`<Enter>` opens the selected note. `<C-x>`/`<C-v>` opens in a split. Select multiple notes with `<Tab>`.

## Game ID

If the current buffer is a `rascript` file, the game ID will be auto-detected from the current buffer's header line (e.g., `#ID = 14426`).

To explicitly specify a game ID:

```lua
notes.open(14426)
notes.create_new(0x00001234, 14426)
```

## License

MIT
