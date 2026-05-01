local constants = require("razz.constants")
local storage = require("razz.storage")
local LocalNote = require("razz.notes.types.local")

---@class LocalNotes
---@field game_id string
---@field path string
---@field notes LocalNote[]
local LocalNotes = {}

--- Loads local notes for a game.
---@param game_id string The game ID
---@return LocalNotes|nil The local notes instance
---@return string|nil Error message on failure
function LocalNotes.load(game_id)
  local user_file, path_err = storage.get_data_path(game_id, constants.USER_NOTES_SUFFIX)
  if not user_file then
    return nil, path_err
  end

  local readable = vim.fn.filereadable(user_file)
  if readable == 0 then
    return nil, "file not found: " .. user_file
  end

  local ok, lines = pcall(vim.fn.readfile, user_file)
  if not ok then
    return nil, "failed to read file: " .. user_file
  end

  local notes = {}
  for i = constants.HEADER_LINE_COUNT, #lines do
    local note = LocalNote.parse_line(lines[i])
    if note then
      table.insert(notes, note)
    end
  end

  local self = setmetatable({
    game_id = game_id,
    path = user_file,
    notes = notes,
  }, { __index = LocalNotes })

  return self, nil
end

--- Ensures the user notes file exists.
---@param game_id string The game ID
---@return string|nil The file path, or nil on error
---@return string|nil Error message on failure
function LocalNotes._ensure_file_exists(game_id)
  local user_file, path_err = storage.get_data_path(game_id, constants.USER_NOTES_SUFFIX)
  if not user_file then
    return nil, path_err
  end

  local readable = vim.fn.filereadable(user_file)
  if readable == 0 then
    return nil, "file not found: " .. user_file
  end

  return user_file, nil
end

--- Finds a note by address.
---@param address number The address to find
---@return LocalNote|nil The note, or nil if not found
function LocalNotes:find_by_addr(address)
  for _, note in ipairs(self.notes) do
    if note.address == address then
      return note
    end
  end
  return nil
end

--- Finds the line index for a given address in the notes file.
---@param address number The address to find
---@param find_insert_pos? boolean If true, returns insert position instead of exact match
---@return number|nil The line index, or nil if not found
function LocalNotes:find_line_idx_by_addr(address, find_insert_pos)
  local lines = vim.fn.readfile(self.path)
  local insert_pos = #lines + 1

  for i = constants.HEADER_LINE_COUNT, #lines do
    local line = lines[i]
    local addr = tonumber(line:match("N0:(0x[%x]+)"))
    if addr then
      if addr == address then
        if find_insert_pos then
          return i
        end
        return i
      end
      if insert_pos == #lines + 1 and addr > address then
        insert_pos = i
      end
    end
  end

  return find_insert_pos and insert_pos or nil
end

--- Updates an existing note or adds a new one.
---@param note LocalNote The note to update or add
function LocalNotes:update_or_add(note)
  local existing = self:find_by_addr(note.address)
  if existing then
    existing.content = note.content
  else
    table.insert(self.notes, note)
  end
end

--- Saves notes to file.
---@return boolean True on success
---@return string|nil Error message on failure
function LocalNotes:save()
  local lines = vim.fn.readfile(self.path)

  for i = #lines, constants.HEADER_LINE_COUNT, -1 do
    table.remove(lines, i)
  end

  for _, note in ipairs(self.notes) do
    table.insert(lines, note:serialize())
  end

  local ok = pcall(vim.fn.writefile, lines, self.path)
  if not ok then
    return false, "failed to write file: " .. self.path
  end

  return true, nil
end

--- Deletes a note by address.
---@param address number The note address to delete
---@return boolean True on success
---@return string|nil Error message on failure
function LocalNotes:delete(address)
  local idx = self:find_line_idx_by_addr(address)
  if not idx then
    return false, "note not found at address: 0x" .. string.format("%08x", address)
  end

  for i = #self.notes, 1, -1 do
    if self.notes[i].address == address then
      table.remove(self.notes, i)
    end
  end

  local lines = vim.fn.readfile(self.path)
  table.remove(lines, idx)
  vim.fn.writefile(lines, self.path)

  return true, nil
end

return LocalNotes
