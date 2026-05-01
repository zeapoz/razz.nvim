---@module "razz.notes.buffer"
local M = {}
local notes = require("razz.notes")
local LocalNote = require("razz.notes.types.local")
local LocalNotes = require("razz.notes.types.local_notes")
local ServerNotes = require("razz.notes.types.server_notes")
local config = require("razz.config")
local util = require("razz.util")

--- Computes the buffer name from note data.
---@param note_addr number The note address
---@param first_line string First line of the note content
---@param game_id string The game ID
---@return string The buffer name
local function _compute_buf_name(note_addr, first_line, game_id)
  if first_line == "" then
    first_line = "Empty Note"
  end
  return string.format("[%s] %s: %s", game_id, util.format_hex_address(note_addr), first_line)
end

--- Updates the buffer name based on current content.
---@param buf number Buffer handle
---@param game_id string The game ID
local function _update_buf_name(buf, game_id)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, 1, false)
  local first_line = (lines[1] or ""):gsub("\r+$", "")
  local note_addr = vim.api.nvim_buf_get_var(buf, "note_addr")
  local buf_name = _compute_buf_name(note_addr, first_line, game_id)
  vim.api.nvim_buf_set_name(buf, buf_name)
end

--- Handles buffer save: compares with server notes and syncs local notes.
---@param buf number Buffer handle
---@param note CodeNote The note
---@param game_id string The game ID
---@param note_addr number Note address
local function _save_callback(buf, note, game_id, note_addr)
  local current_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local current_content = table.concat(current_lines, "\r\n")

  local server_notes, load_err = ServerNotes.load(game_id)
  if not server_notes then
    vim.notify("Failed to load server notes: " .. load_err, vim.log.levels.ERROR)
    return
  end

  local server_note = server_notes:find_by_addr(note_addr)
  local server_note_content = server_note and server_note.content or nil

  if not server_note and current_content == "" then
    local local_notes = LocalNotes.load(game_id)
    if local_notes then
      local_notes:delete(note_addr)
    end
    vim.notify("Empty note discarded: " .. note:format_address())
    _update_buf_name(buf, game_id)
  elseif server_note_content and current_content == server_note_content then
    local local_notes = LocalNotes.load(game_id)
    if local_notes then
      local ok, err = local_notes:delete(note_addr)
      if ok then
        vim.notify("Note matches server, removed local: " .. note:format_address())
        _update_buf_name(buf, game_id)
      else
        vim.notify("Failed to remove local: " .. err, vim.log.levels.ERROR)
      end
    end
  else
    local export_note = LocalNote:new(note_addr, current_content)
    local ok, err = notes.export(game_id, export_note)
    if ok then
      _update_buf_name(buf, game_id)
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
end

--- Binds local keymaps for the note buffer.
---@param buf number Buffer handle
---@param game_id string The game ID
---@param note_addr number Note address
local function _bind_local_keys(buf, game_id, note_addr)
  vim.keymap.set("n", config.keys.publish, function()
    require("razz.notes.buffer").publish()
  end, { buffer = buf, noremap = true, silent = true, desc = "Publish current code note" })

  vim.keymap.set("n", config.keys.revert, function()
    require("razz.notes.buffer").revert(buf, game_id, note_addr)
  end, { buffer = buf, noremap = true, silent = true, desc = "Revert local note to server" })
end

--- Gets the game ID from a buffer's local variable.
---@param buf? number Buffer handle, defaults to current buffer
---@return string|nil The game ID, or nil if not set
---@return string|nil Error message if not set
function M.get_buffer_game_id(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local ok, game_id = pcall(vim.api.nvim_buf_get_var, target_buf, "game_id")
  if ok and game_id then
    return game_id
  end
  return nil, "game_id not set on buffer"
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
  local buf_name = _compute_buf_name(note_addr, first_line, game_id)

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
  vim.api.nvim_buf_set_var(buf, "game_id", game_id)
  vim.api.nvim_buf_set_var(buf, "note_addr", note_addr)

  _bind_local_keys(buf, game_id, note_addr)

  if focus ~= false then
    vim.api.nvim_win_set_buf(0, buf)
  end

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      _save_callback(buf, note, game_id, note_addr)
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

--- Publishes the current note buffer to the server.
--- Reads buffer content and sends it via LocalNote:publish().
---@return nil
function M.publish()
  local note, err = LocalNote.from_buffer()
  if not note then
    if err then
      vim.notify(err, vim.log.levels.ERROR)
    end
    return
  end

  note:publish()
end

--- Reverts local note to server version or clears if unavailable.
---@param buf number Buffer handle
---@param game_id string The game ID
---@param note_addr number Note address
function M.revert(buf, game_id, note_addr)
  local server_notes, load_err = ServerNotes.load(game_id)
  if not server_notes then
    vim.notify("Failed to load server notes: " .. load_err, vim.log.levels.ERROR)
    return
  end

  local server_note = server_notes:find_by_addr(note_addr)
  local local_notes = LocalNotes.load(game_id)

  if local_notes then
    local_notes:delete(note_addr)
  end

  if server_note then
    local content = server_note.content
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n", { keepempty = true }))
    _update_buf_name(buf, game_id)
    vim.notify("Reverted to server note: " .. server_note:format_address())
  else
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
    _update_buf_name(buf, game_id)
    vim.notify("Discarded local note: " .. util.format_hex_address(note_addr))
  end

  vim.bo[buf].modified = false
end

return M
