---@module "razz.rascript"
local M = {}
local cli = require("razz.rascript.cli")

M.export = cli.export
M.export_current_file = cli.export_current_file

--- Tries to infer the game ID from a buffer's content.
--- Scans for "#ID = XXX" pattern in the first two lines.
---@param buf? number Buffer handle, defaults to current buffer
---@return string|nil The inferred game ID, or nil if not found
---@return string|nil Error message if not found
function M.try_infer_from_buffer(buf)
  local target_buf = buf or vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(target_buf, 0, 2, false)
  if #lines < 2 then
    return nil, "buffer has fewer than 2 lines"
  end
  local id = lines[2]:match("#ID%s*=%s*(%d+)")
  if not id then
    return nil, "could not find #ID in buffer"
  end
  return id
end

return M
