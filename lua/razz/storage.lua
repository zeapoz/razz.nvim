---@module "razz.storage"
local M = {}
local constants = require("razz.constants")
local config = require("razz.config")

--- Gets the first configured emulator directory.
---@return string|nil The first emulator directory
---@return string|nil Error message if not configured
local function get_first_emulator_dir()
  if #config.emulator_dirs == 0 then
    return nil, "no emulator_dirs configured"
  end
  return config.emulator_dirs[1]
end

--- Expands a directory path and appends the RACache Data subdirectory.
---@param dir string The directory to expand
---@return string The expanded path with RACACHE_DATA_DIR appended
function M.expand_data_dir(dir)
  return vim.fn.expand(dir) .. "/" .. constants.RACACHE_DATA_DIR
end

--- Gets the data directory from the first configured emulator.
---@return string|nil The data directory path, or nil if not configured
---@return string|nil Error message if not configured
function M.get_data_dir()
  local dir, err = get_first_emulator_dir()
  if not dir then
    return nil, err
  end
  return M.expand_data_dir(dir)
end

--- Gets the emulation directory (parent of RACache/Data) from the first configured emulator.
---@return string|nil The emulation directory path, or nil if not configured
---@return string|nil Error message if not configured
function M.get_emulation_dir()
  local dir, err = get_first_emulator_dir()
  if not dir then
    return nil, err
  end
  return vim.fn.expand(dir)
end

--- Gets the full data path for a game ID and file suffix.
--- Searches all emulator directories and returns the first file that exists.
---@param game_id string The game ID
---@param suffix string The file suffix (e.g., "-Notes.json")
---@return string|nil The full path if successful, or nil if not configured
---@return string|nil Error message if not configured
function M.get_data_path(game_id, suffix)
  local _, err = get_first_emulator_dir()
  if err then
    return nil, "no emulator_dirs configured"
  end
  for _, dir in ipairs(config.emulator_dirs) do
    local full_path = M.expand_data_dir(dir) .. game_id .. suffix
    if vim.fn.filereadable(full_path) ~= 0 then
      return full_path, nil
    end
  end
  return nil, "file not found in any configured emulator directory"
end

--- Prompts user to choose a directory for a new file.
--- Checks for existing file first - if found, returns that path. Otherwise prompts user.
---@param game_id string The game ID
---@param suffix string The file suffix
---@param callback fun(path: string|nil, err: string|nil)
function M.pick_data_path(game_id, suffix, callback)
  vim.schedule(function()
    local existing_path, _ = M.get_data_path(game_id, suffix)
    if existing_path then
      callback(existing_path, nil)
      return
    end

    local _, err = get_first_emulator_dir()
    if err then
      callback(nil, "no emulator_dirs configured")
      return
    end

    local paths = {}
    for _, dir in ipairs(config.emulator_dirs) do
      local expanded = M.expand_data_dir(dir)
      table.insert(paths, { dir = dir, path = expanded .. game_id .. suffix })
    end

    local choices = {}
    for _, p in ipairs(paths) do
      table.insert(choices, p.dir)
    end

    vim.ui.select(choices, {
      prompt = "Choose directory for new file:",
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if not choice then
        callback(nil, "cancelled")
        return
      end

      for _, p in ipairs(paths) do
        if p.dir == choice then
          local ok_mkdir = pcall(vim.fn.mkdir, vim.fn.fnamemodify(p.path, ":p:h"), "p")
          if not ok_mkdir then
            callback(nil, "failed to create directory")
            return
          end
          callback(p.path, nil)
          return
        end
      end
    end)
  end)
end

--- Gets all expanded data directories from config.
---@return string[] Array of expanded data directory paths
function M.get_data_paths()
  local paths = {}
  for _, dir in ipairs(config.emulator_dirs) do
    table.insert(paths, M.expand_data_dir(dir))
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

  local ok_decode, session = pcall(vim.json.decode, table.concat(lines, ""))
  if not ok_decode then
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
