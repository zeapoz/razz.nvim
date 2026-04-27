---@class razz.constants
---@field NOTE_PREFIX string Note prefix for serialization
---@field RACACHE_DATA_DIR string RACache Data directory path
---@field SERVER_NOTES_SUFFIX string Server notes file suffix
---@field USER_NOTES_SUFFIX string User notes file suffix
---@field NOTE_LINE_PATTERN string Regex pattern for note lines
---@field NOTE_LINE_WITH_CONTENT_PATTERN string Regex pattern for note lines with content
---@field HEADER_LINE_COUNT number Number of header lines in notes file
---@field ADDRESS_PADDING number Padding length for addresses
---@field LOCAL_USER_LABEL string Label for local user notes
---@field ADDRESS_FORMAT string Format string for address formatting
local M = {
  NOTE_PREFIX = "N0:",
  RACACHE_DATA_DIR = "RACache/Data/",
  SERVER_NOTES_SUFFIX = "-Notes.json",
  USER_NOTES_SUFFIX = "-User.txt",
  NOTE_LINE_PATTERN = "^N0:(0x[%x]+):(.*)",
  NOTE_LINE_WITH_CONTENT_PATTERN = '^N0:(0x[%x]+):"(.*)"',
  HEADER_LINE_COUNT = 3,
  ADDRESS_PADDING = 8,
  LOCAL_USER_LABEL = "Local Note",
  ADDRESS_FORMAT = "0x%08x",
}

return M
