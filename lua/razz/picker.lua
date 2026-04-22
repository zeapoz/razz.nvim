local M = {}

function M.show_notes(opts)
  local ok, telescope = pcall(require, "telescope")
  if not ok then
    vim.notify("telescope not installed", vim.log.levels.ERROR)
    return
  end

  local razz = require("razz")
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
    local normalized = note.Note:gsub("\r\n", "\n")
    local first_line = normalized:match("^[^\n]*")
    local prefix = note.User == "Local Note" and "*" or ""
    local display = note.Address .. ": " .. prefix .. first_line
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
    picker_opts.attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if selection then
          actions.close(prompt_bufnr)
          on_select(selection.value)
        end
      end)
      return true
    end
  end

  pickers.new({}, picker_opts):find()
end

function M.open_note(opts)
  local razz = require("razz")
  local game_id = opts.game_id
  local get_notes_fn = opts.get_notes_fn

  local notes
  if get_notes_fn then
    notes = get_notes_fn(game_id)
  else
    notes = razz.get_notes(game_id)
  end

  opts.notes = notes

  opts.on_select = function(note)
    local prev_winnr = vim.api.nvim_get_current_win()
    local note_addr = note.Address
    local buf = vim.api.nvim_create_buf(true, "")
    vim.bo[buf].fileformat = "dos"
    local lines = vim.split(note.Note, "\r\n", false, { keepempty = true })
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_name(buf, "Note: " .. note_addr)
    vim.bo[buf].filetype = "text"
    vim.bo[buf].modifiable = true

    local function to_export_content(buf_lines)
      local content = table.concat(buf_lines, "\r\n")
      content = content:gsub("\r", "\\r"):gsub("\n", "\\n")
      return content
    end

    local original_content = to_export_content(lines)

    vim.cmd("buffer " .. buf)

    vim.api.nvim_create_autocmd("BufWriteCmd", {
      buffer = buf,
      callback = function()
        local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
        local current_content = to_export_content(current_lines)

        if current_content == original_content then
          vim.notify("No changes to note: " .. note_addr)
          vim.bo[buf].modified = false
        end

        local export_note = { Address = note_addr, Note = current_content }
        local ok, err = razz.export_note(game_id, export_note)
        if ok then
          vim.notify("Exported note: " .. note_addr)
          original_content = current_content
          vim.bo[buf].modified = false
        else
          vim.notify("Export failed: " .. err, vim.log.levels.ERROR)
        end
      end,
    })

    vim.bo[buf].buftype = "acwrite"

    vim.api.nvim_create_autocmd("BufUnload", {
      buffer = buf,
      callback = function()
        vim.api.nvim_set_current_win(prev_winnr)
      end,
    })
  end

  M.show_notes(opts)
end

return M