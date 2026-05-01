local constants = require("razz.constants")
local storage = require("razz.storage")
local ServerNote = require("razz.notes.types.server")

---@class ServerNotes
---@field game_id string
---@field notes ServerNote[]
local ServerNotes = {}

--- Loads server notes for a game.
---@param game_id string The game ID
---@return ServerNotes|nil The server notes instance
---@return string|nil Error message on failure
function ServerNotes.load(game_id)
  local data_path, path_err = storage.get_data_path(game_id, constants.SERVER_NOTES_SUFFIX)
  if not data_path then
    return nil, path_err
  end

  local ok, lines = pcall(vim.fn.readfile, data_path)
  if not ok then
    return nil, "failed to read file: " .. data_path
  end

  local content = table.concat(lines, "\n")
  local ok_decode, json_notes = pcall(vim.json.decode, content)
  if not ok_decode then
    return nil, "failed to decode JSON"
  end

  local notes = {}
  for _, json_note in ipairs(json_notes) do
    local note, err = ServerNote.parse_json(json_note)
    if not note then
      vim.notify("Failed to parse note: " .. err, vim.log.levels.WARN)
    else
      table.insert(notes, note)
    end
  end

  local self = setmetatable({
    game_id = game_id,
    notes = notes,
  }, { __index = ServerNotes })

  return self, nil
end

--- Finds a note by address.
---@param address number The address to find
---@return ServerNote|nil The note, or nil if not found
function ServerNotes:find_by_addr(address)
  for _, note in ipairs(self.notes) do
    if note.address == address then
      return note
    end
  end
  return nil
end

--- Updates an existing note or adds a new one.
---@param address number The note address
---@param content string The note content
---@param user string The username
function ServerNotes:update_or_add(address, content, user)
  local note = self:find_by_addr(address)
  if note then
    note.content = content
    note.user = user
  else
    local new_note = ServerNote:new(address, content, user)
    table.insert(self.notes, new_note)
  end
end

--- Serializes all notes to JSON format.
---@return table[] Array of JSON-serializable tables
function ServerNotes:serialize_json()
  local json_notes = {}
  for _, note in ipairs(self.notes) do
    table.insert(json_notes, note:serialize_json())
  end
  return json_notes
end

--- Saves notes to file.
---@return boolean True on success
---@return string|nil Error message on failure
function ServerNotes:save()
  local data_path, path_err = storage.get_data_path(self.game_id, constants.SERVER_NOTES_SUFFIX)
  if not data_path then
    return false, path_err
  end

  local json_notes = self:serialize_json()
  local ok_json, json_str = pcall(vim.json.encode, json_notes)
  if not ok_json then
    return false, "failed to encode JSON"
  end

  local ok_write = pcall(vim.fn.writefile, vim.split(json_str, "\n"), data_path)
  if not ok_write then
    return false, "failed to write server notes"
  end

  return true, nil
end

return ServerNotes
