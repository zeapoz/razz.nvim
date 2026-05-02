local CodeNote = require("razz.notes.types.base")
local constants = require("razz.constants")
local ra_client = require("razz.ra_client")

--- Local user notes.
---@class LocalNote: CodeNote
local LocalNote = setmetatable({}, { __index = CodeNote })

---@param address number The memory address
---@param content? string The note content
---@param game_id string The game ID
---@return LocalNote
function LocalNote:new(address, content, game_id)
  local obj = CodeNote.new(self, address, content, game_id) --[[@as LocalNote]]
  return obj
end

--- Creates a LocalNote from a buffer.
---@param buf? number Buffer handle, defaults to current buffer
---@return LocalNote?, string?
function LocalNote.from_buffer(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local game_id = vim.api.nvim_buf_get_var(target_buf, "game_id")
  local note_addr = vim.api.nvim_buf_get_var(target_buf, "note_addr")

  if not game_id or not note_addr then
    return nil, "game_id or note_addr not set"
  end

  local lines = vim.api.nvim_buf_get_lines(target_buf, 0, -1, false)
  local content = table.concat(lines, "\r\n")

  return LocalNote:new(note_addr, content, game_id)
end

--- Parses a note from a serialized line.
---@param line string The line to parse
---@param game_id string The game ID
---@return LocalNote? The parsed note, or nil if invalid
function LocalNote.parse_line(line, game_id)
  local addr_str, content = line:match(constants.NOTE_LINE_WITH_CONTENT_PATTERN)
  if not addr_str then
    return nil
  end
  local addr = tonumber(addr_str, 16)
  local unescaped = CodeNote.unescaped(content)
  return LocalNote:new(addr, unescaped, game_id)
end

--- Serializes the note to its string representation.
---@return string The serialized note in format N0:0xADDR:"content"
function LocalNote:serialize()
  local addr_padded = self:format_address()
  local escaped = CodeNote.escaped(self.content)
  return "N0:" .. addr_padded .. ':"' .. escaped .. '"'
end

--- Publishes the note to the server.
---@return nil
function LocalNote:publish()
  ra_client.publish_note(self.game_id, self.address, self.content, function()
    vim.schedule(function()
      local notes = require("razz.notes")
      local ok, err = notes.mark_synced(self.game_id, self.address, self.content)
      if not ok then
        vim.notify("Failed to update synced note: " .. err, vim.log.levels.ERROR)
      end
    end)
  end)
end

return LocalNote
