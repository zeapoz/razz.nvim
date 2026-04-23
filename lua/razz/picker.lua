local M = {}
local constants = require("razz.constants")
local helpers = require("razz.helpers")

local function open_note_buffer(note, game_id, prev_winnr, focus)
  local note_addr = note.Address
  local buf = vim.api.nvim_create_buf(true, false)
  vim.bo[buf].modifiable = true
  vim.bo[buf].fileformat = "dos"
  local note_content = helpers._unescape_content(note.Note)
  local lines = vim.split(note_content, "\r\n", { keepempty = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = false

  local normalized = helpers._normalize_for_display(note.Note)
  local first_line = normalized:match("^[^\n]*")
  vim.api.nvim_buf_set_name(buf, note_addr .. ": " .. first_line)
  vim.bo[buf].filetype = "text"

  local function to_export_content(buf_lines)
    local content = table.concat(buf_lines, "\r\n")
    content = helpers._escape_content(content)
    return content
  end

  if focus ~= false then
    vim.api.nvim_win_set_buf(0, buf)
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local current_content = to_export_content(current_lines)

      local normalized_content = helpers._unescape_content(current_content)

      local razz = require("razz")
      local server_notes = razz.load_server_notes(game_id)
      local server_note = helpers.find_note_by_addr(server_notes, note_addr)
      local server_note_content = server_note and server_note.Note or nil

      local export_note = { Address = note_addr, Note = current_content }

      if server_note_content and normalized_content == server_note_content then
        local ok, err = razz.delete_local_note(game_id, note_addr)
        if ok then
          vim.notify("Note matches server, removed local: " .. note_addr)
        else
          vim.notify("Failed to remove local: " .. err, vim.log.levels.ERROR)
        end
      else
        local ok, err = razz.export_note(game_id, export_note)
        if ok then
          if server_note_content then
            vim.notify("Updated note: " .. note_addr)
          else
            vim.notify("Added new note: " .. note_addr)
          end
        else
          vim.notify("Export failed: " .. err, vim.log.levels.ERROR)
        end
      end

      vim.bo[buf].modified = false
    end,
  })

  vim.bo[buf].buftype = "acwrite"

  vim.api.nvim_create_autocmd("BufUnload", {
    buffer = buf,
    callback = function()
      vim.api.nvim_set_current_win(prev_winnr)
    end,
  })

  return buf
end

function M.show_notes(opts)
  local ok, _ = pcall(require, "telescope")
  if not ok then
    vim.notify("telescope not installed", vim.log.levels.ERROR)
    return
  end

  local razz = opts.razz or require("razz")
  local game_id = opts.game_id
  local on_select = opts.on_select
  local notes = opts.notes

  if not notes then
    if not game_id then
      vim.notify("show_notes requires either notes or game_id", vim.log.levels.ERROR)
      return
    end
    notes = razz.get_notes(game_id)
  end

  if #notes == 0 then
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

  local entry_maker = function(note)
    local normalized = helpers._normalize_for_display(note.Note)
    local first_line = normalized:match("^[^\n]*")
    local prefix = note.User == constants.LOCAL_USER_LABEL and "*" or ""
    local display = note.Address .. ": " .. prefix .. first_line
    local ordinal = note.Address .. " " .. note.User .. " " .. first_line

    return {
      value = note,
      display = display,
      ordinal = ordinal,
    }
  end

  local previewer = previewers.new_buffer_previewer({
    define_preview = function(self, entry, _)
      local note = entry.value
      local normalized = helpers._normalize_for_display(note.Note)
      local lines = {
        "Address: " .. note.Address,
        "User: " .. note.User,
        "",
      }
      vim.list_extend(lines, vim.split(normalized, "\n"))
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    end,
  })

  local picker_opts = {
    prompt_title = "Notes for " .. game_id,
    finder = finders.new_table({
      results = notes,
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
              open_note_buffer(entry.value, game_id, prev_winnr, false)
            end
          end
          open_note_buffer(selection_value, game_id, prev_winnr, true)
        end
      end

      map("i", "<C-x>", function() open_notes("split") end)
      map("i", "<C-v>", function() open_notes("vsplit") end)

      actions.select_default:replace(function()
        open_notes(nil)
      end)
      return true
    end
  end

  pickers.new({}, picker_opts):find()
end

function M.open_note(opts)
  local razz = opts.razz or require("razz")
  local game_id = opts.game_id
  local get_notes_fn = opts.get_notes_fn

  local notes
  if get_notes_fn then
    notes = get_notes_fn(game_id)
  else
    notes = razz.get_notes(game_id)
  end

  opts.notes = notes

  opts.on_select = function() end

  M.show_notes(opts)
end

return M
