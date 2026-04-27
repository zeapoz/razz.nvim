---@module "razz.storage"
local M = {}
local constants = require("razz.constants")
local razz = require("razz")

--- Expands a directory path and appends the RACache Data subdirectory.
---@param dir string The directory to expand
---@return string The expanded path with RACACHE_DATA_DIR appended
function M.expand_dir(dir)
  return vim.fn.expand(dir) .. "/" .. constants.RACACHE_DATA_DIR
end

--- Gets the data directory from the first configured emulator.
---@return string|nil The data directory path, or nil if not configured
---@return string|nil Error message if not configured
function M.get_data_dir()
  if #razz.config.emulator_dirs == 0 then
    return nil, "no emulator_dirs configured"
  end
  return M.expand_dir(razz.config.emulator_dirs[1])
end

--- Gets the full data path for a game ID and file suffix.
--- Searches all emulator directories and returns the first file that exists.
---@param game_id string The game ID
---@param suffix string The file suffix (e.g., "-Notes.json")
---@return string|nil The full path if successful, or nil if not configured
---@return string|nil Error message if not configured
function M.get_data_path(game_id, suffix)
  if #razz.config.emulator_dirs == 0 then
    return nil, "no emulator_dirs configured"
  end
  for _, dir in ipairs(razz.config.emulator_dirs) do
    local full_path = M.expand_dir(dir) .. game_id .. suffix
    if vim.fn.filereadable(full_path) ~= 0 then
      return full_path, nil
    end
  end
  return nil, "file not found in any configured emulator directory"
end

--- Gets all expanded data directories from config.
---@return string[] Array of expanded data directory paths
function M.get_data_paths()
  local paths = {}
  for _, dir in ipairs(razz.config.emulator_dirs) do
    table.insert(paths, M.expand_dir(dir))
  end
  return paths
end

return M
