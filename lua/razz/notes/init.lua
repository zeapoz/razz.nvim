local M = {}
local _server_notes_cache = {}
local constants = require("razz.constants")
local storage = require("razz.storage")
local razz = require("razz")
local CodeNote = require("razz.notes.type")

function M.load_from_server(game_id)
  if _server_notes_cache[game_id] then
    return _server_notes_cache[game_id], nil
  end

  local data_path, path_err = storage.get_data_path(game_id, constants.SERVER_NOTES_SUFFIX)
  if not data_path then
    return {}, path_err
  end
  local ok, lines = pcall(vim.fn.readfile, data_path)
  if not ok then
    return {}, "failed to read file: " .. data_path
  end

  local content = table.concat(lines, "\n")
  local ok_decode, json_notes = pcall(vim.json.decode, content)
  if not ok_decode then
    return {}, "failed to decode JSON"
  end

  local notes = {}
  for _, json_note in ipairs(json_notes) do
    table.insert(notes, CodeNote:from_server(json_note))
  end

  _server_notes_cache[game_id] = notes
  return notes, nil
end

function M.clear_server_cache(game_id)
  if game_id then
    _server_notes_cache[game_id] = nil
  else
    _server_notes_cache = {}
  end
end

function M.load_from_local(game_id)
  local user_file, path_err = storage.get_data_path(game_id, constants.USER_NOTES_SUFFIX)
  if not user_file then
    return {}, path_err
  end

  local readable = vim.fn.filereadable(user_file)
  if readable == 0 then
    return {}, "file not found: " .. user_file
  end

  local ok, lines = pcall(vim.fn.readfile, user_file)
  if not ok then
    return {}, "failed to read file: " .. user_file
  end

  local notes = {}

  for i = constants.HEADER_LINE_COUNT, #lines do
    local note = CodeNote:from_line(lines[i])
    if note then
      table.insert(notes, note)
    end
  end

  return notes, nil
end

function M.get_all(game_id)
  local server_notes, _ = M.load_from_server(game_id)
  local local_notes, _ = M.load_from_local(game_id)

  local local_by_addr = {}
  for _, note in ipairs(local_notes) do
    local_by_addr[note.address] = note
  end

  local results = {}
  local used_local = {}

  for _, note in ipairs(server_notes) do
    local addr = note.address
    if local_by_addr[addr] then
      table.insert(results, local_by_addr[addr])
      used_local[addr] = true
    else
      table.insert(results, note)
    end
  end

  for _, note in ipairs(local_notes) do
    local addr = note.address
    if not used_local[addr] then
      table.insert(results, note)
    end
  end

  return results
end

function M._ensure_user_file_exists(game_id)
  local user_file, path_err = storage.get_data_path(game_id, constants.USER_NOTES_SUFFIX)
  if not user_file then
    return false, path_err
  end
  local readable = vim.fn.filereadable(user_file)
  if readable == 0 then
    return false, "file not found: " .. user_file
  end
  return true, user_file
end

function M._find_line_idx_by_addr(lines, addr, opts)
  local addr_num = tonumber(addr, 16)
  if not addr_num then
    return nil
  end

  local find_insert_pos = opts and opts.find_insert_pos
  local insert_pos = #lines + 1

  for i = constants.HEADER_LINE_COUNT, #lines do
    local line_addr = lines[i]:match(constants.NOTE_LINE_PATTERN)
    if line_addr then
      local line_addr_num = tonumber(line_addr, 16)
      if line_addr_num == addr_num then
        return i
      end
      if find_insert_pos and line_addr_num > addr_num and i < insert_pos then
        insert_pos = i
      end
    end
  end

  if find_insert_pos then
    return insert_pos
  end
  return nil
end

function M._write_local_note(game_id, note)
  local ok, err_or_path = M._ensure_user_file_exists(game_id)
  if not ok then
    return false, err_or_path
  end

  local lines = vim.fn.readfile(err_or_path)
  local new_line = note:serialize()

  local idx = M._find_line_idx_by_addr(lines, note.address)
  if idx then
    lines[idx] = new_line
  else
    local insert_pos = M._find_line_idx_by_addr(lines, note.address, { find_insert_pos = true }) or #lines + 1
    table.insert(lines, insert_pos, new_line)
  end

  vim.fn.writefile(lines, err_or_path)
  return true
end

function M.delete_local(game_id, address)
  local ok, err_or_path = M._ensure_user_file_exists(game_id)
  if not ok then
    return false, err_or_path
  end

  local lines = vim.fn.readfile(err_or_path)
  local idx = M._find_line_idx_by_addr(lines, address)
  if idx then
    table.remove(lines, idx)
  end

  vim.fn.writefile(lines, err_or_path)
  return true
end

function M.export(game_id, note)
  return M._write_local_note(game_id, note)
end

function M.open(opts)
  local game_id, err = razz.get_game_id_or_error(opts)
  if not game_id then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local notes_list = M.get_all(game_id)
  require("razz.picker").open({ game_id = game_id, notes = notes_list })
end

function M.open_local(opts)
  local game_id, err = razz.get_game_id_or_error(opts)
  if not game_id then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local notes_list = M.load_from_local(game_id)
  require("razz.picker").open({ game_id = game_id, notes = notes_list })
end

function M.open_server(opts)
  local game_id, err = razz.get_game_id_or_error(opts)
  if not game_id then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local notes_list = M.load_from_server(game_id)
  require("razz.picker").open({ game_id = game_id, notes = notes_list })
end

function M.create_new(opts, address)
  local game_id, err = razz.get_game_id_or_error(opts)
  if not game_id then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local function do_create(addr)
    local note = CodeNote:new_note(addr, "")
    require("razz.notes.buffer").open_buffer(note, game_id, nil, true)
  end

  if address then
    do_create(address)
  else
    vim.ui.input({ prompt = "Address: " }, function(input)
      if input and input ~= "" then
        do_create(input)
      end
    end)
  end
end

return M
