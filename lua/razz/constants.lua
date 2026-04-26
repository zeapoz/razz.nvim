local M = {
  NOTE_PREFIX = "N0:",
  RACACHE_DATA_DIR = "RACache/Data/",
  SERVER_NOTES_SUFFIX = "-Notes.json",
  USER_NOTES_SUFFIX = "-User.txt",
  NOTE_LINE_PATTERN = "^N0:(0x[%x]+):(.*)",
  NOTE_LINE_WITH_CONTENT_PATTERN = '^N0:(0x[%x]+):"(.*)"',
  HEADER_LINE_COUNT = 3,
  ADDRESS_PADDING = 8,
}

return M
