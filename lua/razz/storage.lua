---@module "razz.storage"
local M = {}
local constants = require("razz.constants")
local config = require("razz.config")

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
  if #config.emulator_dirs == 0 then
    return nil, "no emulator_dirs configured"
  end
  return M.expand_dir(config.emulator_dirs[1])
end

--- Gets the full data path for a game ID and file suffix.
--- Searches all emulator directories and returns the first file that exists.
---@param game_id string The game ID
---@param suffix string The file suffix (e.g., "-Notes.json")
---@return string|nil The full path if successful, or nil if not configured
---@return string|nil Error message if not configured
function M.get_data_path(game_id, suffix)
  if #config.emulator_dirs == 0 then
    return nil, "no emulator_dirs configured"
  end
  for _, dir in ipairs(config.emulator_dirs) do
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
  for _, dir in ipairs(config.emulator_dirs) do
    table.insert(paths, M.expand_dir(dir))
  end
  return paths
end

local _session_token = nil
local _cached_username = nil

--- Gets the path to the session file.
---@return string The path to the session.json file
function M.get_session_path()
  return vim.fn.stdpath("data") .. "/" .. constants.SESSION_FILE
end

--- Loads session data from disk into memory.
function M.load_session()
  local path = M.get_session_path()
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return
  end

  local ok, session = pcall(vim.json.decode, table.concat(lines, ""))
  if not ok then
    return
  end

  if session then
    _session_token = session.token
    _cached_username = session.username
  end
end

--- Saves session data to disk.
---@param username string The username
---@param token string The session token
function M.save_session(username, token)
  _session_token = token
  _cached_username = username

  vim.schedule(function()
    local path = M.get_session_path()
    local dir = vim.fn.fnamemodify(path, ":p:h")
    local ok_dir = pcall(function()
      if vim.fn.isdirectory(dir) == 0 then
        vim.fn.mkdir(dir, "p")
      end
    end)
    if not ok_dir then
      return
    end
    local ok_data, data = pcall(vim.json.encode, { username = username, token = token })
    if not ok_data then
      return
    end

    pcall(vim.fn.writefile, vim.split(data, "\n"), path)
  end)
end

--- Clears session data from memory and disk.
function M.clear_session()
  _session_token = nil
  _cached_username = nil

  vim.schedule(function()
    local path = M.get_session_path()
    pcall(function()
      if vim.fn.filereadable(path) == 1 then
        vim.fn.delete(path)
      end
    end)
  end)
end

--- Gets the cached username.
---@return string|nil The username, or nil if not cached
function M.get_username()
  return _cached_username
end

--- Gets the cached session token.
---@return string|nil The session token, or nil if not cached
function M.get_session_token()
  return _session_token
end

--- Checks if a session is cached in memory.
---@return boolean True if both username and token are present
function M.is_session_cached()
  return _session_token ~= nil and _cached_username ~= nil
end

--- Checks if user is logged in, displays error message if not.
---@return boolean True if logged in, false otherwise
function M.is_logged_in()
  if not M.is_session_cached() then
    vim.notify('Not logged in, call require("razz").login() first', vim.log.levels.ERROR)
    return false
  end
  return true
end

return M
