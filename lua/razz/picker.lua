local M = {}

function M.show_notes_picker(game_id)
  local ok, telescope = pcall(require, "telescope")
  if not ok then
    vim.notify("telescope not installed", vim.log.levels.ERROR)
    return
  end

  local razz = require("razz")
  local notes = razz.get_notes(game_id)

  if #notes == 0 then
    vim.notify("No notes found for game " .. game_id, vim.log.levels.WARN)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local previewers = require("telescope.previewers")

  local entry_maker = function(note)
    local normalized = note.Note:gsub("\r\n", "\n")
    local first_line = normalized:match("^[^\n]*")
    local display = note.Address .. ": " .. first_line
    local ordinal = note.Address .. " " .. note.User .. " " .. first_line
    return {
      value = note,
      display = display,
      ordinal = ordinal,
    }
  end

  local previewer = previewers.new_buffer_previewer({
    define_preview = function(self, entry, status)
      local note = entry.value
      local normalized = note.Note:gsub("\r\n", "\n")
      local note_lines = vim.split(normalized, "\n", false, { keepempty = true })
      local lines = {
        "Address: " .. note.Address,
        "User: " .. note.User,
        "",
      }
      vim.list_extend(lines, note_lines)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    end,
  })

  pickers
    .new({}, {
      prompt_title = "Notes for " .. game_id,
      finder = finders.new_table({
        results = notes,
        entry_maker = entry_maker,
      }),
      previewer = previewer,
      sorter = require("telescope.sorters").get_generic_fuzzy_sorter(),
      sorting_strategy = "ascending",
    })
    :find()
end

return M