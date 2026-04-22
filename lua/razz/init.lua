local M = {
  config = {
    emulator_dirs = {},
  },
  picker = require("razz.picker"),
}

function M.setup(opts)
  opts = opts or {}
  M.config.emulator_dirs = opts.emulator_dirs or {}
  return M
end

function M.get_data_paths()
  local paths = {}
  for _, dir in ipairs(M.config.emulator_dirs) do
    table.insert(paths, vim.fn.expand(dir) .. "/RACache/Data")
  end
  return paths
end

function M.get_notes(game_id)
  if #M.config.emulator_dirs == 0 then
    return {}
  end

  local expanded_dir = vim.fn.expand(M.config.emulator_dirs[1])
  local data_path = expanded_dir .. "/RACache/Data/" .. game_id .. "-Notes.json"
  local ok, lines = pcall(vim.fn.readfile, data_path)
  if not ok then
    return {}
  end

  local content = table.concat(lines, "\n")
  local ok_decode, notes = pcall(vim.json.decode, content)
  if not ok_decode then
    return {}
  end

  return notes or {}
end

function M.get_current_game_id()
  local lines = vim.api.nvim_buf_get_lines(0, 0, 2, false)
  if #lines < 2 then
    return nil
  end
  local id = lines[2]:match("#ID%s*=%s*(%d+)")
  return id
end

function M.show_notes(game_id)
  if not game_id then
    game_id = M.get_current_game_id()
    if not game_id then
      vim.notify("Could not detect game ID from current buffer", vim.log.levels.ERROR)
      return
    end
  end
  M.picker.show_notes(game_id)
end

return M