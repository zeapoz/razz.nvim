local CodeNote = require("razz.notes.types.base")
local constants = require("razz.constants")

--- Local user notes.
---@class LocalNote: CodeNote
local LocalNote = setmetatable({}, { __index = CodeNote })

---@param address number The memory address
---@param content? string The note content
---@return LocalNote
function LocalNote:new(address, content)
  local obj = CodeNote.new(self, address, content) --[[@as LocalNote]]
  return obj
end

--- Parses a note from a serialized line.
---@param line string The line to parse
---@return LocalNote? The parsed note, or nil if invalid
function LocalNote.parse_line(line)
  local addr_str, content = line:match(constants.NOTE_LINE_WITH_CONTENT_PATTERN)
  if not addr_str then
    return nil
  end
  local addr = tonumber(addr_str, 16)
  local unescaped = CodeNote.unescaped(content)
  return LocalNote:new(addr, unescaped)
end

--- Serializes the note to its string representation.
---@return string The serialized note in format N0:0xADDR:"content"
function LocalNote:serialize()
  local addr_padded = self:format_address()
  local escaped = CodeNote.escaped(self.content)
  return "N0:" .. addr_padded .. ':"' .. escaped .. '"'
end

return LocalNote
