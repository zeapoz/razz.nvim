local CodeNote = require("razz.notes.types.base")

--- Notes synced from the server.
---@class ServerNote: CodeNote
---@field user string The username associated with the note
local ServerNote = setmetatable({}, { __index = CodeNote })

---@param address number The memory address
---@param content? string The note content
---@param user string The username associated with the note (required)
---@return ServerNote? The note instance on success
---@return string|nil Error message on failure
function ServerNote:new(address, content, user)
  if not user then
    return nil, "user is required"
  end
  local obj = CodeNote.new(self, address, content) --[[@as ServerNote]]
  obj.user = user
  return obj
end

--- Creates a note from server JSON data.
---@param json table The JSON object from the server
---@return ServerNote? The note instance on success
---@return string|nil Error message on failure
function ServerNote.parse_json(json)
  local addr = tonumber(json.Address, 16)
  if not addr then
    return nil, "invalid address: " .. tostring(json.Address)
  end
  return ServerNote:new(addr, json.Note or "", json.User)
end

--- Serializes the note to JSON format.
---@return table The JSON-serializable table
function ServerNote:serialize_json()
  return {
    Address = self:format_address(),
    Note = self.content,
    User = self.user,
  }
end

return ServerNote
