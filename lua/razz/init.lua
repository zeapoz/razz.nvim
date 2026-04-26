local M = {
  config = {
    emulator_dirs = {},
  },
}

function M.ensure_configured()
  if #M.config.emulator_dirs == 0 then
    return false, "no emulator_dirs configured"
  end
  return true
end

function M.get_game_id_or_error(opts)
  if type(opts) == "string" then
    return opts
  end
  if opts and opts.game_id then
    return opts.game_id
  end
  local game_id = M._infer_current_game_id()
  if not game_id then
    return nil, "Could not detect game ID from current buffer"
  end
  return game_id
end

function M._infer_current_game_id()
  local lines = vim.api.nvim_buf_get_lines(0, 0, 2, false)
  if #lines < 2 then
    return nil
  end
  local id = lines[2]:match("#ID%s*=%s*(%d+)")
  return id
end

function M.setup(opts)
  opts = opts or {}
  M.config.emulator_dirs = opts.emulator_dirs or {}
  return M
end

return M
