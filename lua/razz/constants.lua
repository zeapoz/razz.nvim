---@class razz.constants
---@field RACACHE_DATA_DIR string RACache Data directory path
---@field SERVER_NOTES_SUFFIX string Server notes file suffix
---@field USER_NOTES_SUFFIX string User notes file suffix
---@field NOTE_LINE_PATTERN string Regex pattern for note lines
---@field NOTE_LINE_WITH_CONTENT_PATTERN string Regex pattern for note lines with content
---@field HEADER_LINE_COUNT number Number of header lines in notes file
---@field LOCAL_NOTE_LABEL string Label for local notes
---@field ADDRESS_FORMAT string Format string for address formatting
local M = {
  RACACHE_DATA_DIR = "RACache/Data/",
  SERVER_NOTES_SUFFIX = "-Notes.json",
  USER_NOTES_SUFFIX = "-User.txt",
  NOTE_LINE_PATTERN = "^N0:(0x[%x]+):(.*)",
  NOTE_LINE_WITH_CONTENT_PATTERN = '^N0:(0x[%x]+):"(.*)"',
  HEADER_LINE_COUNT = 3,
  LOCAL_NOTE_LABEL = "Local Note",
  ADDRESS_FORMAT = "0x%08x",
  SESSION_FILE = "razz/session.json",
}

return M
