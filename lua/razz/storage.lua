local M = {}
local constants = require("razz.constants")
local razz = require("razz")

function M._get_data_dir()
  return vim.fn.expand(razz.config.emulator_dirs[1]) .. "/" .. constants.RACACHE_DATA_DIR
end

function M._get_data_path(game_id, suffix)
  return M._get_data_dir() .. game_id .. suffix
end

function M.get_data_paths()
  local paths = {}
  for _, dir in ipairs(razz.config.emulator_dirs) do
    table.insert(paths, vim.fn.expand(dir) .. "/" .. constants.RACACHE_DATA_DIR)
  end
  return paths
end

return M
