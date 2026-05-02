local util = require("razz.util")

--- Base class for all note types.
---@class CodeNote
---@field address number
---@field content string
---@field game_id string
local CodeNote = {}

---@param address number The memory address
---@param content? string The note content
---@param game_id string The game ID
---@return CodeNote
function CodeNote:new(address, content, game_id)
  local obj = setmetatable({}, self)
  obj.address = address
  obj.content = content or ""
  obj.game_id = game_id
  self.__index = self
  return obj
end

--- Formats the address as a padded lowercase hex string.
---@return string The formatted address (e.g., "0x00001234")
function CodeNote:format_address()
  return util.format_hex_address(self.address)
end

--- Unescapes note content for display.
---@param content string The content to unescape
---@return string, nil The unescaped content, count is discarded
function CodeNote.unescaped(content)
  return content:gsub("\\r", "\r"):gsub("\\n", "\n"):gsub("\r\n", "\n")
end

--- Escapes note content for serialization.
---@param content string The content to escape
---@return string, nil The escaped content, count is discarded
function CodeNote.escaped(content)
  return content:gsub("\r", "\\r"):gsub("\n", "\\n")
end

--- Gets the unescaped content for display.
---@return string The unescaped content
function CodeNote:get_display_content()
  return CodeNote.unescaped(self.content)
end

return CodeNote
