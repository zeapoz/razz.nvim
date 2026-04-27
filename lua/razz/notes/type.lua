---@class CodeNote
---@field address string
---@field content string
---@field user string
local CodeNote = {}
local constants = require("razz.constants")

--- Creates a new CodeNote instance.
---@param o? table Initial values for the note
---@return CodeNote The new note instance
function CodeNote:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

--- Serializes the note to its string representation.
---@return string The serialized note in format N0:0xADDR:"content"
function CodeNote:serialize()
  local addr_padded = self:format_address()
  local escaped = self.content:gsub("\r", "\\r"):gsub("\n", "\\n")
  return "N0:" .. addr_padded .. ':"' .. escaped .. '"'
end

--- Formats the address as a padded uppercase hex string.
---@return string The formatted address (e.g., "0x00001234")
function CodeNote:format_address()
  local num = tonumber(self.address, 16)
  if not num then
    return self.address
  end
  return string.format(constants.ADDRESS_FORMAT, num)
end

--- Gets the unescaped content for display.
---@return string The unescaped content
function CodeNote:get_display_content()
  return self.content:gsub("\\r", "\r"):gsub("\\n", "\n"):gsub("\r\n", "\n")
end

--- Checks if the note is a local user note.
---@return boolean True if the note is local, false otherwise
function CodeNote:is_local()
  return self.user == nil
end

--- Parses a note from a serialized line.
---@param line string The line to parse
---@return CodeNote|nil The parsed note, or nil if invalid
function CodeNote:from_line(line)
  local addr, content = line:match('^N0:(0x[%x]+):"(.*)"')
  if not addr then
    return nil
  end
  local normalized_addr = string.format("0x%x", tonumber(addr, 16)):lower()
  local unescaped = content:gsub("\\r", "\r"):gsub("\\n", "\n")
  return self:new({
    address = normalized_addr,
    content = unescaped,
    user = nil,
  })
end

--- Creates a note from server JSON data.
---@param json table The JSON object from the server
---@return CodeNote The new note instance
function CodeNote:from_server(json)
  local normalized_addr = string.format("0x%x", tonumber(json.Address, 16)):lower()
  return self:new({
    address = normalized_addr,
    content = json.Note or "",
    user = json.User,
  })
end

--- Creates a new local note at the given address.
---@param address string The memory address (hex or decimal)
---@param content? string The note content
---@return CodeNote The new note instance
function CodeNote:new_note(address, content)
  local normalized_addr = string.format("0x%x", tonumber(address, 16)):lower()
  return self:new({
    address = normalized_addr,
    content = content or "",
    user = nil,
  })
end

--- Creates a note from buffer content.
---@param address string The memory address (hex or decimal)
---@param buffer_content string The content from the buffer
---@return CodeNote The new note instance
function CodeNote:from_buffer_content(address, buffer_content)
  local normalized_addr = string.format("0x%x", tonumber(address, 16)):lower()
  return self:new({
    address = normalized_addr,
    content = buffer_content,
    user = nil,
  })
end

return CodeNote
