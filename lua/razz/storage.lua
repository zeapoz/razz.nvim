local M = {}
local constants = require("razz.constants")
local razz = require("razz")

function M.expand_dir(dir)
  return vim.fn.expand(dir) .. "/" .. constants.RACACHE_DATA_DIR
end

function M.get_data_dir()
  if #razz.config.emulator_dirs == 0 then
    return nil, "no emulator_dirs configured"
  end
  return M.expand_dir(razz.config.emulator_dirs[1])
end

function M.get_data_path(game_id, suffix)
  local dir, err = M.get_data_dir()
  if not dir then
    return nil, err
  end
  return dir .. game_id .. suffix
end

function M.get_data_paths()
  local paths = {}
  for _, dir in ipairs(razz.config.emulator_dirs) do
    table.insert(paths, M.expand_dir(dir))
  end
  return paths
end

return M
