# 🍓 razz.nvim

A Neovim plugin for managing [RetroAchievements](https://retroachievements.org) code notes.

![Screenshot](assets/screenshot.png)

## Features

- Browse local and server code notes
- Publish local notes to the RetroAchievements server
- Telescope picker integration

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
  config = function(_, opts)
    local razz = require("razz")
    razz.setup(opts)
    razz.login() -- Required to push notes to the server
  end,
  keys = function()
    local notes = require("razz.notes")
    return {
      { "<leader>co", function() notes.open() end, desc = "Open code note" },
      { "<leader>cl", function() notes.open_local() end, desc = "Open local note" },
      { "<leader>cs", function() notes.open_server() end, desc = "Open server note" },
      { "<leader>cf", function() notes.fetch_server() end, desc = "Fetch server notes" },
      { "<leader>cn", function() notes.create_new() end, desc = "Create new note" },
    }
  end,
}
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `emulator_dirs` | table | `{}` | Required. List of paths to emulator directories (containing `RACache/Data/`) |

### Buffer Local Keymaps

| Keymap | Default | Description |
|--------|---------|-------------|
| `keys.publish` | `<localleader>p` | Publish current local note to the RetroAchievements server |

## Usage

| Function | Options | Description |
|----------|---------|-------------|
| `notes.open()` | `game_id?` | Open all notes (server + local) |
| `notes.open_local()` | `game_id?` | Open local notes only |
| `notes.open_server()` | `game_id?` | Open server notes only |
| `notes.fetch_server()` | `game_id?` | Fetch server notes from RA and save to disk |
| `notes.create_new()` | `address?`, `game_id?` | Create a new note |
| `notes.create_new_with_content()` | `address`, `lines`, `game_id?` | Create note with content |
| `notes.publish()` | - | Publish local note to server |

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
