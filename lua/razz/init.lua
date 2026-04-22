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

function M.show_notes(opts)
  if type(opts) == "string" then
    opts = { game_id = opts }
  end
  opts = opts or {}

  if not opts.game_id then
    opts.game_id = M.get_current_game_id()
    if not opts.game_id then
      vim.notify("Could not detect game ID from current buffer", vim.log.levels.ERROR)
      return
    end
  end
  M.picker.show_notes(opts)
end

function M.open_note(opts)
  if type(opts) == "string" then
    opts = { game_id = opts }
  end
  opts = opts or {}

  if not opts.game_id then
    opts.game_id = M.get_current_game_id()
    if not opts.game_id then
      vim.notify("Could not detect game ID from current buffer", vim.log.levels.ERROR)
      return
    end
  end
  M.picker.open_note(opts)
end

function M.export_note(game_id, note)
  if #M.config.emulator_dirs == 0 then
    return false, "no emulator_dirs configured"
  end

  local expanded_dir = vim.fn.expand(M.config.emulator_dirs[1])
  local user_file = expanded_dir .. "/RACache/Data/" .. game_id .. "-User.txt"

  local ok, _ = vim.fn.filereadable(user_file)
  if ok == 0 then
    return false, "file not found: " .. user_file
  end

  local lines = vim.fn.readfile(user_file)
  local new_addr_num = tonumber(note.Address, 16)
  local new_addr_padded = string.format("0x%08x", new_addr_num)
  local new_line = "N0:" .. new_addr_padded .. ":\"" .. note.Note .. "\""

  local found = false
  for i = 3, #lines do
    local addr = lines[i]:match("^N0:(0x[%x]+):")
    if addr then
      local addr_num = tonumber(addr, 16)
      if addr_num == new_addr_num then
        lines[i] = new_line
        found = true
        break
      end
    end
  end

  if not found then
    local insert_pos = #lines + 1
    for i = 3, #lines do
      local addr = lines[i]:match("^N0:(0x[%x]+):")
      if addr then
        local addr_num = tonumber(addr, 16)
        if addr_num > new_addr_num then
          insert_pos = i
          break
        end
      end
    end
    table.insert(lines, insert_pos, new_line)
  end

  vim.fn.writefile(lines, user_file)
  return true
end

return M