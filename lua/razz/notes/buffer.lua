local M = {}
local helpers = require("razz.helpers")
local notes = require("razz.notes")

function M.open_buffer(note, game_id, prev_winnr, focus)
  local note_addr = note.Address
  local normalized = helpers.normalize_for_display(note.Note)
  local first_line = normalized:match("^[^\n]*")
  local buf_name = note_addr .. ": " .. first_line

  local existing_buf = vim.fn.bufnr(buf_name)
  if existing_buf ~= -1 then
    if focus then
      vim.api.nvim_win_set_buf(0, existing_buf)
    end
    return
  end

  local buf = vim.api.nvim_create_buf(true, false)
  vim.bo[buf].modifiable = true
  vim.bo[buf].fileformat = "dos"
  local note_content = helpers.unescape_content(note.Note)
  local lines = vim.split(note_content, "\r\n", { keepempty = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = false

  vim.api.nvim_buf_set_name(buf, buf_name)
  vim.bo[buf].filetype = "ranote"

  local function to_export_content(buf_lines)
    local content = table.concat(buf_lines, "\r\n")
    content = helpers.escape_content(content)
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

      local normalized_content = helpers.unescape_content(current_content)

      local server_notes = notes.load_from_server(game_id)
      local server_note = helpers.find_note_by_addr(server_notes, note_addr)
      local server_note_content = server_note and server_note.Note or nil

      local export_note = { Address = note_addr, Note = current_content }

      if not server_note and current_content == "" then
        notes.delete_local(game_id, note_addr)
        vim.notify("Empty note discarded: " .. note_addr)
      elseif server_note_content and normalized_content == server_note_content then
        local ok, err = notes.delete_local(game_id, note_addr)
        if ok then
          vim.notify("Note matches server, removed local: " .. note_addr)
        else
          vim.notify("Failed to remove local: " .. err, vim.log.levels.ERROR)
        end
      else
        local ok, err = notes.export(game_id, export_note)
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

return M
