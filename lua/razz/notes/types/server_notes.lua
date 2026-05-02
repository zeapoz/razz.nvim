local constants = require("razz.constants")
local storage = require("razz.storage")
local ServerNote = require("razz.notes.types.server")
local util = require("razz.util")

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
    local note, err = ServerNote.parse_json(json_note, game_id)
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
  return util.find_by_address(self.notes, address)
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
    local new_note = ServerNote:new(address, content, user, self.game_id)
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

--- Saves notes to file asynchronously.
---@param callback fun(success: boolean, err: string|nil)
function ServerNotes:save_async(callback)
  storage.pick_data_path(self.game_id, constants.SERVER_NOTES_SUFFIX, function(data_path, path_err)
    if not data_path then
      callback(false, path_err)
      return
    end

    local json_notes = self:serialize_json()
    local ok_json, json_str = pcall(vim.json.encode, json_notes)
    if not ok_json then
      callback(false, "failed to encode JSON")
      return
    end

    local ok_write = pcall(vim.fn.writefile, vim.split(json_str, "\n"), data_path)
    if not ok_write then
      callback(false, "failed to write server notes")
      return
    end

    callback(true, nil)
  end)
end

--- Saves notes to file (synchronous, for existing files).
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

--- Downloads server notes from the server.
---@param game_id string
function ServerNotes.fetch_from_server(game_id)
  local ra_client = require("razz.ra_client")

  ra_client.fetch_notes(game_id, function(json_notes, err)
    if err or not json_notes then
      vim.notify(err or "invalid response", vim.log.levels.ERROR)
      return
    end

    local notes = {}
    for _, json_note in ipairs(json_notes) do
      local note, note_err = ServerNote.parse_json(json_note, game_id)
      if not note then
        vim.notify("Failed to parse note: " .. note_err, vim.log.levels.WARN)
      else
        table.insert(notes, note)
      end
    end

    local self = setmetatable({ game_id = game_id, notes = notes }, { __index = ServerNotes })

    self:save_async(function(ok, save_err)
      if not ok then
        vim.notify("Failed to save: " .. save_err, vim.log.levels.WARN)
      end
      vim.notify("Fetched " .. #notes .. " notes", vim.log.levels.INFO)
    end)
  end)
end

return ServerNotes
