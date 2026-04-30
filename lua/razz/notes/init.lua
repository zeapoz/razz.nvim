---@module "razz.notes"
---@class razz.notes._FindLineOpts
---@field find_insert_pos? boolean If true, returns insert position instead of exact match

local M = {}
local _server_notes_cache = {}
local constants = require("razz.constants")
local storage = require("razz.storage")
local razz = require("razz")
local LocalNote = require("razz.notes.types.local")
local ServerNote = require("razz.notes.types.server")

--- Loads notes from the server for a given game.
---@param game_id string The game ID
---@return CodeNote[] Array of notes from the server
---@return string|nil Error message if failed
function M.load_from_server(game_id)
  if _server_notes_cache[game_id] then
    return _server_notes_cache[game_id], nil
  end

  local data_path, path_err = storage.get_data_path(game_id, constants.SERVER_NOTES_SUFFIX)
  if not data_path then
    return {}, path_err
  end
  local ok, lines = pcall(vim.fn.readfile, data_path)
  if not ok then
    return {}, "failed to read file: " .. data_path
  end

  local content = table.concat(lines, "\n")
  local ok_decode, json_notes = pcall(vim.json.decode, content)
  if not ok_decode then
    return {}, "failed to decode JSON"
  end

  local notes = {}
  for _, json_note in ipairs(json_notes) do
    local note, err = ServerNote.parse_json(json_note)
    if not note then
      vim.notify("failed to parse note: " .. err, vim.log.levels.WARN)
    else
      table.insert(notes, note)
    end
  end

  _server_notes_cache[game_id] = notes
  return notes, nil
end

--- Clears the server notes cache.
---@param game_id? string Optional game ID to clear specific cache
function M.clear_server_cache(game_id)
  if game_id then
    _server_notes_cache[game_id] = nil
  else
    _server_notes_cache = {}
  end
end

--- Loads local notes from the user notes file.
---@param game_id string The game ID
---@return CodeNote[] Array of local notes
---@return string|nil Error message if failed
function M.load_from_local(game_id)
  local user_file, path_err = storage.get_data_path(game_id, constants.USER_NOTES_SUFFIX)
  if not user_file then
    return {}, path_err
  end

  local readable = vim.fn.filereadable(user_file)
  if readable == 0 then
    return {}, "file not found: " .. user_file
  end

  local ok, lines = pcall(vim.fn.readfile, user_file)
  if not ok then
    return {}, "failed to read file: " .. user_file
  end

  local notes = {}

  for i = constants.HEADER_LINE_COUNT, #lines do
    local note = LocalNote.parse_line(lines[i])
    if note then
      table.insert(notes, note)
    end
  end

  return notes, nil
end

--- Gets all notes (server and local) for a game, merging them.
--- Local notes override server notes at the same address.
---@param game_id string The game ID
---@return CodeNote[] Array of all merged notes
function M.get_all(game_id)
  local server_notes, _ = M.load_from_server(game_id)
  local local_notes, _ = M.load_from_local(game_id)

  local local_by_addr = {}
  for _, note in ipairs(local_notes) do
    local_by_addr[note.address] = note
  end

  local results = {}
  local used_local = {}

  for _, note in ipairs(server_notes) do
    local addr = note.address
    if local_by_addr[addr] then
      table.insert(results, local_by_addr[addr])
      used_local[addr] = true
    else
      table.insert(results, note)
    end
  end

  for _, note in ipairs(local_notes) do
    local addr = note.address
    if not used_local[addr] then
      table.insert(results, note)
    end
  end

  return results
end

--- Checks if the user notes file exists for a game.
---@param game_id string The game ID
---@return boolean True if the file exists
---@return string|nil The file path if true, or error message if false
function M._ensure_user_file_exists(game_id)
  local user_file, path_err = storage.get_data_path(game_id, constants.USER_NOTES_SUFFIX)
  if not user_file then
    return false, path_err
  end
  local readable = vim.fn.filereadable(user_file)
  if readable == 0 then
    return false, "file not found: " .. user_file
  end
  return true, user_file
end

--- Finds the line index for a given address in the notes file.
---@param lines string[] The lines from the notes file
---@param addr number The address to find
---@param opts? razz.notes._FindLineOpts Optional settings
---@return number|nil The line index, or nil if not found
function M._find_line_idx_by_addr(lines, addr, opts)
  local find_insert_pos = opts and opts.find_insert_pos
  local insert_pos = #lines + 1

  for i = constants.HEADER_LINE_COUNT, #lines do
    local line_addr = lines[i]:match(constants.NOTE_LINE_PATTERN)
    if line_addr then
      local line_addr_num = tonumber(line_addr, 16)
      if line_addr_num == addr then
        return i
      end
      if find_insert_pos and line_addr_num > addr and i < insert_pos then
        insert_pos = i
      end
    end
  end

  if find_insert_pos then
    return insert_pos
  end
  return nil
end

--- Writes a local note to the user notes file.
---@param game_id string The game ID
---@param note CodeNote The note to write
---@return boolean True if successful
---@return string|nil Error message if failed
function M._write_local_note(game_id, note)
  local ok, err_or_path = M._ensure_user_file_exists(game_id)
  if not ok then
    return false, err_or_path
  end

  local path = err_or_path or ""
  local lines = vim.fn.readfile(path)
  local new_line = note:serialize()

  local idx = M._find_line_idx_by_addr(lines, note.address)
  if idx then
    lines[idx] = new_line
  else
    local insert_pos = M._find_line_idx_by_addr(lines, note.address, { find_insert_pos = true }) or #lines + 1
    table.insert(lines, insert_pos, new_line)
  end

  vim.fn.writefile(lines, path)
  return true
end

--- Deletes a local note by address.
---@param game_id string The game ID
---@param address number The note address to delete
---@return boolean True if successful
---@return string|nil Error message if failed
function M.delete_local(game_id, address)
  local ok, err_or_path = M._ensure_user_file_exists(game_id)
  if not ok then
    return false, err_or_path
  end

  local path = err_or_path or ""
  local lines = vim.fn.readfile(path)
  local idx = M._find_line_idx_by_addr(lines, address)
  if idx then
    table.remove(lines, idx)
  end

  vim.fn.writefile(lines, path)
  return true
end

--- Exports a note to the local notes file.
---@param game_id string The game ID
---@param note CodeNote The note to export
---@return boolean True if successful
---@return string|nil Error message if failed
function M.export(game_id, note)
  return M._write_local_note(game_id, note)
end

--- Opens the notes picker with all notes (server and local).
---@param game_id? string|number The game ID (or nil to infer)
function M.open(game_id)
  local resolved_game_id, err = razz.get_game_id_or_error(game_id)
  if not resolved_game_id or err then
    if err then
      vim.notify(err, vim.log.levels.ERROR)
    end
    return
  end

  local notes_list = M.get_all(resolved_game_id)
  require("razz.picker").open({ game_id = resolved_game_id, notes = notes_list })
end

--- Opens the notes picker with local notes only.
---@param game_id? string|number The game ID (or nil to infer)
function M.open_local(game_id)
  local resolved_game_id, err = razz.get_game_id_or_error(game_id)
  if not resolved_game_id or err then
    if err then
      vim.notify(err, vim.log.levels.ERROR)
    end
    return
  end

  local notes_list = M.load_from_local(resolved_game_id)
  require("razz.picker").open({ game_id = resolved_game_id, notes = notes_list })
end

--- Opens the notes picker with server notes only.
---@param game_id? string|number The game ID (or nil to infer)
function M.open_server(game_id)
  local resolved_game_id, err = razz.get_game_id_or_error(game_id)
  if not resolved_game_id or err then
    if err then
      vim.notify(err, vim.log.levels.ERROR)
    end
    return
  end

  local notes_list = M.load_from_server(resolved_game_id)
  require("razz.picker").open({ game_id = resolved_game_id, notes = notes_list })
end

--- Creates a new note at the given address or prompts for one.
---@param address? number Optional address to create note at
---@param game_id? string|number The game ID (or nil to infer)
function M.create_new(address, game_id)
  local resolved_game_id, err = razz.get_game_id_or_error(game_id)
  if not resolved_game_id or err then
    if err then
      vim.notify(err, vim.log.levels.ERROR)
    end
    return
  end

  local function do_create(addr)
    local note = LocalNote:new(addr, "")
    require("razz.notes.buffer").open_buffer(note, resolved_game_id, nil, true)
  end

  if address then
    do_create(address)
  else
    vim.ui.input({ prompt = "Address: " }, function(input)
      if input and input ~= "" then
        do_create(tonumber(input, 16))
      end
    end)
  end
end

--- Creates and exports a note to the local notes file.
---@param address number The memory address
---@param lines string[] Array of lines
---@param game_id? string|number The game ID (or nil to infer)
---@return boolean True if successful
---@return string|nil Error message if failed
function M.create_new_with_content(address, lines, game_id)
  if not lines or #lines == 0 then
    return false, "no content provided"
  end

  local resolved_game_id, err = razz.get_game_id_or_error(game_id)
  if not resolved_game_id or err then
    return false, err or "invalid game_id"
  end

  local content = table.concat(lines, "\r\n")
  local note = LocalNote:new(address, content)
  return M._write_local_note(resolved_game_id, note)
end

return M
