---@module "razz.notes.buffer"
local M = {}
local notes = require("razz.notes")
local CodeNote = require("razz.notes.type")
local constants = require("razz.constants")

local function compute_buf_name(note, first_line)
  if first_line == "" then
    first_line = "Empty Note"
  end
  return note:format_address() .. ": " .. first_line
end

local function update_buf_name(buf, note)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, 1, false)
  local first_line = (lines[1] or ""):gsub("\r+$", "")
  local buf_name = compute_buf_name(note, first_line)
  vim.api.nvim_buf_set_name(buf, buf_name)
end

--- Opens a buffer for editing a note.
--- Creates a new buffer or focuses an existing one for the given note.
---@param note CodeNote The note to edit
---@param game_id string The game ID
---@param prev_winnr? number Previous window number to return to
---@param focus? boolean Whether to focus the buffer (default: true)
---@return number The buffer handle
function M.open_buffer(note, game_id, prev_winnr, focus)
  local note_addr = note.address
  local note_content = note:get_display_content()
  local first_line = note_content:match("^[^\n]*"):gsub("\r+$", "")
  local buf_name = compute_buf_name(note, first_line)

  local existing_buf = vim.fn.bufnr(buf_name)
  if existing_buf ~= -1 then
    if focus then
      vim.api.nvim_win_set_buf(0, existing_buf)
    end
    return 0
  end

  local buf = vim.api.nvim_create_buf(true, false)
  vim.bo[buf].modifiable = true
  vim.bo[buf].fileformat = "dos"
  local lines = vim.split(note_content, "\n", { keepempty = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modified = false

  vim.api.nvim_buf_set_name(buf, buf_name)
  vim.bo[buf].filetype = "ranote"

  if focus ~= false then
    vim.api.nvim_win_set_buf(0, buf)
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local current_content = table.concat(current_lines, "\r\n")

      local server_notes = notes.load_from_server(game_id)
      local server_note = nil
      for _, n in ipairs(server_notes) do
        if n.address == note_addr then
          server_note = n
          break
        end
      end
      local server_note_content = server_note and server_note.content or nil

      if not server_note and current_content == "" then
        notes.delete_local(game_id, note_addr)
        vim.notify("Empty note discarded: " .. note:format_address())
        update_buf_name(buf, note)
      elseif server_note_content and current_content == server_note_content then
        local ok, err = notes.delete_local(game_id, note_addr)
        if ok then
          vim.notify("Note matches server, removed local: " .. note:format_address())
          update_buf_name(buf, note)
        else
          vim.notify("Failed to remove local: " .. err, vim.log.levels.ERROR)
        end
      else
        local export_note = CodeNote:from_buffer_content(note_addr, current_content)
        local ok, err = notes.export(game_id, export_note)
        if ok then
          update_buf_name(buf, note)
          if server_note_content then
            vim.notify("Updated note: " .. note:format_address())
          else
            vim.notify("Added new note: " .. note:format_address())
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
      if prev_winnr then
        vim.api.nvim_set_current_win(prev_winnr)
      end
    end,
  })

  return buf
end

return M
