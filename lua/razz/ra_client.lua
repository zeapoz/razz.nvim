local M = {}
local storage = require("razz.storage")

--- Executes a POST request to RA API.
---@param post_data string URL-encoded POST data
---@param callback fun(response: table|nil, err: string|nil)
local function _request(post_data, callback)
  vim.system({
    "curl",
    "-s",
    "-X",
    "POST",
    "--data",
    post_data,
    "https://retroachievements.org/dorequest.php",
  }, { text = true }, function(result)
    if result.code ~= 0 then
      local err_msg = result.stdout or "curl error"
      vim.notify(err_msg, vim.log.levels.ERROR)
      callback(nil, err_msg)
      return
    end

    local ok, response = pcall(vim.json.decode, result.stdout)
    if not ok then
      vim.notify("Failed to parse response", vim.log.levels.ERROR)
      callback(nil, "failed to parse response")
      return
    end

    callback(response, nil)
  end)
end

--- Logs in to RA with password and caches session token.
---@param username string
---@param password string RA password
---@param callback? fun(success: boolean, err: string|nil)
function M.login_with_password(username, password, callback)
  local post_data = string.format("r=login2&u=%s&p=%s", username, password)

  _request(post_data, function(response, err)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      if callback then
        callback(false, err)
      end
      return
    end

    if not response or not response.Token then
      local login_err = (response and response.Error) or "login failed"
      vim.notify(login_err, vim.log.levels.ERROR)
      if callback then
        callback(false, login_err)
      end
      return
    end

    storage.save_session(username, response.Token)
    vim.notify("Logged in as " .. username, vim.log.levels.INFO)
    if callback then
      callback(true, nil)
    end
  end)
end

--- Logs in to RA with web API token and caches session token.
---@param username string
---@param api_token string RA web API token
---@param callback? fun(success: boolean, err: string|nil)
function M.login_with_token(username, api_token, callback)
  local post_data = string.format("r=login2&u=%s&t=%s", username, api_token)

  _request(post_data, function(response, err)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      if callback then
        callback(false, err)
      end
      return
    end

    if not response or not response.Token then
      local login_err = (response and response.Error) or "login failed"
      vim.notify(login_err, vim.log.levels.ERROR)
      if callback then
        callback(false, login_err)
      end
      return
    end

    storage.save_session(username, response.Token)
    if callback then
      callback(true, nil)
    end
  end)
end

--- Logs out and clears session token.
function M.logout()
  storage.clear_session()
end

--- Internal publish function.
---@param game_id number|string
---@param address number
---@param note string
---@param on_success? fun() Callback called on successful publish
local function _do_publish(game_id, address, note, on_success)
  local username = storage.get_username()
  local token = storage.get_session_token()
  local post_data =
    string.format("r=submitcodenote&u=%s&t=%s&g=%s&m=%s&n=%s", username, token, tostring(game_id), address, note)

  _request(post_data, function(response, err)
    if err then
      vim.notify(err, vim.log.levels.ERROR)
      return
    end

    if not response or not response.Success then
      local err_msg = (response and response.Error) or "unknown error"
      local status = (response and response.Status) or ""
      vim.notify(status .. ": " .. err_msg, vim.log.levels.ERROR)
      return
    end

    vim.notify("Note published", vim.log.levels.INFO)
    if on_success then
      on_success()
    end
  end)
end

--- Submits a note to RetroAchievements asynchronously.
---@param game_id number|string
---@param address number
---@param note string
---@param on_success? fun() Callback called on successful publish
function M.publish_note(game_id, address, note, on_success)
  if not storage.is_logged_in() then
    return
  end

  _do_publish(game_id, address, note, on_success)
end

return M
