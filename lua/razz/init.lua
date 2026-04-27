---@class razz
---@field config table Configuration options
---@field config.emulator_dirs string[] List of emulator directories
local M = {
  config = {
    emulator_dirs = {},
  },
}

--- Ensures the plugin is configured with emulator directories.
---@return boolean True if configured, false otherwise
---@return string|nil Error message if not configured
function M.ensure_configured()
  if #M.config.emulator_dirs == 0 then
    return false, "no emulator_dirs configured"
  end
  return true, nil
end

--- Gets the game ID from options or infers from the current buffer.
---@param opts? string|table Either a game ID string or { game_id = "..." }
---@return string|nil The game ID, or nil if not found
---@return string|nil Error message if not found
function M.get_game_id_or_error(opts)
  if type(opts) == "string" then
    return opts, nil
  end
  if opts and opts.game_id then
    return opts.game_id, nil
  end
  local game_id = M._infer_current_game_id()
  if not game_id then
    return nil, "Could not detect game ID from current buffer"
  end
  return game_id, nil
end

--- Infers the game ID from the current buffer's header.
---@return string|nil The inferred game ID, or nil if not found
function M._infer_current_game_id()
  local lines = vim.api.nvim_buf_get_lines(0, 0, 2, false)
  if #lines < 2 then
    return nil
  end
  local id = lines[2]:match("#ID%s*=%s*(%d+)")
  return id
end

--- Configures the plugin with options.
---@param opts? table Configuration options
---@return razz The module for chaining
function M.setup(opts)
  opts = opts or {}
  M.config.emulator_dirs = opts.emulator_dirs or {}
  return M
end

return M
