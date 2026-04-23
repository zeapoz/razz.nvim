local M = {
  config = {
    emulator_dirs = {},
  },
  picker = require("razz.picker"),
  constants = require("razz.constants"),
  helpers = require("razz.helpers"),
}

function M._ensure_configured()
  if #M.config.emulator_dirs == 0 then
    return false, "no emulator_dirs configured"
  end
  return true
end

function M._get_data_dir()
  return vim.fn.expand(M.config.emulator_dirs[1]) .. "/" .. M.constants.RACACHE_DATA_DIR
end

function M._get_data_path(game_id, suffix)
  return M._get_data_dir() .. game_id .. suffix
end

function M._parse_note_line(line)
  local addr, content = line:match(M.constants.NOTE_LINE_WITH_CONTENT_PATTERN)
  if addr and content then
    content = M.helpers._unescape_content(content)
    local normalized_addr = M.helpers._normalize_address(addr):lower()
    return {
      Address = normalized_addr,
      Note = content,
      User = M.constants.LOCAL_USER_LABEL,
    }
  end
  return nil
end

function M._serialize_note(note)
  local addr_padded = M.helpers._format_address(note.Address)
  local escaped_note = M.helpers._escape_content(note.Note)
  return M.constants.NOTE_PREFIX .. addr_padded .. ':"' .. escaped_note .. '"'
end

function M.setup(opts)
  opts = opts or {}
  M.config.emulator_dirs = opts.emulator_dirs or {}
  return M
end

function M._get_game_id_or_error(opts)
  if opts.game_id then
    return opts.game_id
  end
  local game_id = M.get_current_game_id()
  if not game_id then
    vim.notify("Could not detect game ID from current buffer", vim.log.levels.ERROR)
    return nil
  end
  return game_id
end

function M.get_data_paths()
  local paths = {}
  for _, dir in ipairs(M.config.emulator_dirs) do
    table.insert(paths, vim.fn.expand(dir) .. "/" .. M.constants.RACACHE_DATA_DIR)
  end
  return paths
end

function M.load_server_notes(game_id)
  local ok, err = M._ensure_configured()
  if not ok then
    return {}, err
  end

  local data_path = M._get_data_path(game_id, M.constants.SERVER_NOTES_SUFFIX)
  local ok, lines = pcall(vim.fn.readfile, data_path)
  if not ok then
    return {}, "failed to read file: " .. data_path
  end

  local content = table.concat(lines, "\n")
  local ok_decode, notes = pcall(vim.json.decode, content)
  if not ok_decode then
    return {}, "failed to decode JSON"
  end

  for _, note in ipairs(notes) do
    note.Address = M.helpers._normalize_address(note.Address)
  end

  return notes or {}, nil
end

function M.load_local_notes(game_id)
  local ok, err = M._ensure_configured()
  if not ok then
    return {}, err
  end

  local user_file = M._get_data_path(game_id, M.constants.USER_NOTES_SUFFIX)

  local readable = vim.fn.filereadable(user_file)
  if readable == 0 then
    return {}, "file not found: " .. user_file
  end

  local lines = vim.fn.readfile(user_file)
  local notes = {}

  for i = M.constants.HEADER_LINE_COUNT, #lines do
    local note = M._parse_note_line(lines[i])
    if note then
      table.insert(notes, note)
    end
  end

  return notes, nil
end

function M.get_notes(game_id)
  local server_notes, _ = M.load_server_notes(game_id)
  local local_notes, _ = M.load_local_notes(game_id)

  local local_by_addr = {}
  for _, note in ipairs(local_notes) do
    local_by_addr[note.Address] = note
  end

  local results = {}
  local used_local = {}

  for _, note in ipairs(server_notes) do
    local addr = note.Address
    if local_by_addr[addr] then
      table.insert(results, local_by_addr[addr])
      used_local[addr] = true
    else
      table.insert(results, note)
    end
  end

  for _, note in ipairs(local_notes) do
    local addr = note.Address
    if not used_local[addr] then
      table.insert(results, note)
    end
  end

  return results
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

  local game_id = M._get_game_id_or_error(opts)
  if not game_id then
    return
  end
  opts.game_id = game_id
  M.picker.show_notes(opts)
end

function M.open_note(opts)
  if type(opts) == "string" then
    opts = { game_id = opts }
  end
  opts = opts or {}

  local game_id = M._get_game_id_or_error(opts)
  if not game_id then
    return
  end
  opts.game_id = game_id
  M.picker.open_note(opts)
end

function M.export_note(game_id, note)
  local ok, err = M._ensure_configured()
  if not ok then
    return false, err
  end

  return M._write_user_note(game_id, note)
end

function M.delete_local_note(game_id, address)
  local ok, err = M._ensure_configured()
  if not ok then
    return false, err
  end

  local user_file = M._get_data_path(game_id, M.constants.USER_NOTES_SUFFIX)

  local readable = vim.fn.filereadable(user_file)
  if readable == 0 then
    return false, "file not found: " .. user_file
  end

  local lines = vim.fn.readfile(user_file)
  local addr_num = tonumber(address, 16)
  local new_lines = {}

  for i = 1, #lines do
    if i < M.constants.HEADER_LINE_COUNT then
      table.insert(new_lines, lines[i])
    else
      local line = lines[i]
      local addr = line:match(M.constants.NOTE_LINE_PATTERN)
      if addr then
        local existing_addr_num = tonumber(addr, 16)
        if existing_addr_num ~= addr_num then
          table.insert(new_lines, line)
        end
      else
        table.insert(new_lines, line)
      end
    end
  end

  vim.fn.writefile(new_lines, user_file)
  return true
end

function M._write_user_note(game_id, note)
  local user_file = M._get_data_path(game_id, M.constants.USER_NOTES_SUFFIX)

  local readable = vim.fn.filereadable(user_file)
  if readable == 0 then
    return false, "file not found: " .. user_file
  end

  local lines = vim.fn.readfile(user_file)
  local new_line = M._serialize_note(note)

  local found = false
  for i = M.constants.HEADER_LINE_COUNT, #lines do
    local addr = lines[i]:match(M.constants.NOTE_LINE_PATTERN)
    if addr then
      local addr_num = tonumber(addr, 16)
      local new_addr_num = tonumber(note.Address, 16)
      if addr_num == new_addr_num then
        lines[i] = new_line
        found = true
        break
      end
    end
  end

  if not found then
    local insert_pos = #lines + 1
    for i = M.constants.HEADER_LINE_COUNT, #lines do
      local addr = lines[i]:match(M.constants.NOTE_LINE_PATTERN)
      if addr then
        local addr_num = tonumber(addr, 16)
        local new_addr_num = tonumber(note.Address, 16)
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

