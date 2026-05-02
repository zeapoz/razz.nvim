local M = {}
local config = require("razz.config")
local ra_client = require("razz.client")
local storage = require("razz.storage")

--- Ensures the plugin is properly configured.
---@return boolean success Whether configuration is valid
---@return string|nil err Error message if not configured
function M.ensure_configured()
  if #config.emulator_dirs == 0 then
    return false, "no emulator_dirs configured"
  end
  return true, nil
end

--- Gets the game ID from options or infers from the current buffer.
---@param game_id? string|number The game ID (string, number, or nil to infer)
---@return string|nil The game ID, or nil if not found
---@return string|nil Error message if not found
function M.get_game_id_or_error(game_id)
  if game_id then
    if type(game_id) == "number" then
      return tostring(game_id)
    end
    return game_id
  end
  local notes_buffer = require("razz.notes.buffer")
  local buffer_game_id = notes_buffer.get_buffer_game_id()
  if buffer_game_id then
    return buffer_game_id
  end
  local tools = require("razz.rascript")
  return tools.try_infer_from_buffer()
end

--- Sets up the plugin with user configuration.
---@param opts? table Configuration options
---@return table The module for chaining
function M.setup(opts)
  opts = opts or {}
  for key, value in pairs(opts) do
    if key == "keys" and type(value) == "table" then
      config.keys = vim.tbl_extend("force", config.keys, value)
    else
      config[key] = value
    end
  end
  return M
end

--- Prompts the user to log in.
---@return nil
function M.login()
  local function prompt_for_credentials()
    vim.ui.input({ prompt = "Username: " }, function(username)
      if not username or username == "" then
        vim.notify("Cancelled")
        return
      end

      vim.ui.input({ prompt = "Password: ", secret = true }, function(password)
        if not password or password == "" then
          vim.notify("Cancelled")
          return
        end

        ra_client.login_with_password(username, password)
      end)
    end)
  end

  storage.load_session()
  if storage.is_session_cached() then
    local username = storage.get_username()
    local token = storage.get_session_token()

    if username and token then
      vim.notify("Checking cached session...", vim.log.levels.INFO)
      ra_client.login_with_token(username, token, function(success)
        if success then
          vim.notify("Logged in as " .. username)
        else
          prompt_for_credentials()
        end
      end)
      return
    end
  end

  prompt_for_credentials()
end

return M
