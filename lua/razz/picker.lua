---@module "razz.picker"
---@class razz.picker.ShowOpts
---@field game_id string The game ID
---@field notes? CodeNote[] Notes to display (loaded if not provided)
---@field on_select? function Callback when note(s) selected

---@class razz.picker.OpenOpts : razz.picker.ShowOpts
---@field notes CodeNote[] Notes to display (required)
---@field game_id string The game ID

local M = {}
local notes = require("razz.notes")
local notes_buffer = require("razz.notes.buffer")

--- Finds bracket-enclosed text in a string and returns highlight ranges.
---@param text string The text to search
---@param hl_group string The highlight group to apply
---@return table Array of highlight entries
local function get_brackets_highlights(text, hl_group)
  local highlights = {}
  for s, e in text:gmatch("()(%[[^]]*%])") do
    table.insert(highlights, { { s - 1, s - 1 + #e }, hl_group })
  end
  return highlights
end

--- Shows a telescope picker for notes with optional selection callback.
---@param opts razz.picker.ShowOpts Options for the picker
function M.show(opts)
  local ok, _ = pcall(require, "telescope")
  if not ok then
    vim.notify("telescope not installed", vim.log.levels.ERROR)
    return
  end

  local game_id = opts.game_id
  local on_select = opts.on_select
  local opts_notes = opts.notes

  if not opts_notes then
    if not game_id then
      vim.notify("show requires either notes or game_id", vim.log.levels.ERROR)
      return
    end
    opts_notes = notes.get_all(game_id)
  end

  if #opts_notes == 0 then
    if game_id then
      vim.notify("No notes found for game " .. game_id, vim.log.levels.WARN)
    else
      vim.notify("No notes found", vim.log.levels.WARN)
    end
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local previewers = require("telescope.previewers")
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")
  local entry_display = require("telescope.pickers.entry_display")

  local displayer = entry_display.create({
    separator = "",
    items = {
      { remaining = true },
      { remaining = true },
      { remaining = true },
    },
  })

  local entry_maker = function(note)
    local unescaped = note.content:gsub("\\r", "\r"):gsub("\\n", "\n"):gsub("\r\n", "\n")
    local first_line = unescaped:match("^[^\n]*")
    local prefix = note:is_local() and "*" or ""
    local ordinal = note.address .. " " .. note.user .. " " .. first_line

    return {
      value = note,
      display = function()
        return displayer({
          { note.address, "TelescopeResultsNumber" },
          { ": " .. prefix },
          {
            first_line,
            function()
              return get_brackets_highlights(first_line, "Keyword")
            end,
          },
        })
      end,
      ordinal = ordinal,
    }
  end

  local previewer = previewers.new_buffer_previewer({
    define_preview = function(self, entry, _)
      local note = entry.value
      local unescaped = note.content:gsub("\\r", "\r"):gsub("\\n", "\n"):gsub("\r\n", "\n")
      local lines = {
        "Address: " .. note.address,
        "User: " .. note.user,
        "",
      }
      vim.list_extend(lines, vim.split(unescaped, "\n"))
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      vim.bo[self.state.bufnr].filetype = "ranote"
    end,
  })

  local picker_opts = {
    prompt_title = "Notes for " .. game_id,
    finder = finders.new_table({
      results = opts_notes,
      entry_maker = entry_maker,
    }),
    previewer = previewer,
    sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
    sorting_strategy = "ascending",
  }

  if on_select then
    picker_opts.attach_mappings = function(prompt_bufnr, map)
      local function open_notes(split_cmd)
        local picker = action_state.get_current_picker(prompt_bufnr)
        local multiselect = picker:get_multi_selection()
        local selection = action_state.get_selected_entry()
        if selection then
          actions.close(prompt_bufnr)
          local selections = #multiselect > 0 and multiselect or { selection }
          local prev_winnr = vim.api.nvim_get_current_win()
          if split_cmd then
            vim.cmd(split_cmd)
          end
          local selection_value = selection.value
          for _, entry in ipairs(selections) do
            if entry.value ~= selection_value then
              notes_buffer.open_buffer(entry.value, game_id, prev_winnr, false)
            end
          end
          notes_buffer.open_buffer(selection_value, game_id, prev_winnr, true)
        end
      end

      map("i", "<C-x>", function()
        open_notes("split")
      end)
      map("i", "<C-v>", function()
        open_notes("vsplit")
      end)

      actions.select_default:replace(function()
        open_notes(nil)
      end)
      return true
    end
  end

  pickers.new({}, picker_opts):find()
end

--- Opens the notes picker with pre-loaded notes.
--- Shorthand for M.show with notes already loaded.
---@param opts razz.picker.OpenOpts Options for the picker
function M.open(opts)
  local opts_notes = opts.notes

  if not opts_notes then
    vim.notify("open requires notes", vim.log.levels.ERROR)
    return
  end

  opts.on_select = function() end

  M.show(opts)
end

return M
