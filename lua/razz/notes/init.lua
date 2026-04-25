local M = {}
local _server_notes_cache = {}
local constants = require("razz.constants")
local helpers = require("razz.helpers")
local storage = require("razz.storage")
local razz = require("razz")

function M._parse_line(line)
  local addr, content = line:match(constants.NOTE_LINE_WITH_CONTENT_PATTERN)
  if addr and content then
    content = helpers.unescape_content(content)
    local normalized_addr = helpers.normalize_address(addr):lower()
    return {
      Address = normalized_addr,
      Note = content,
      User = constants.LOCAL_USER_LABEL,
    }
  end
  return nil
end

function M._serialize(note)
  local addr_padded = helpers.format_address(note.Address)
  local escaped_note = helpers.escape_content(note.Note)
  return constants.NOTE_PREFIX .. addr_padded .. ':"' .. escaped_note .. '"'
end

function M.load_from_server(game_id)
  if _server_notes_cache[game_id] then
    return _server_notes_cache[game_id], nil
  end

  local ok, err = pcall(razz._ensure_configured)
  if not ok then
    return {}, err
  end

  local data_path = storage._get_data_path(game_id, constants.SERVER_NOTES_SUFFIX)
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
    note.Address = helpers.normalize_address(note.Address)
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
  local ok, err = pcall(razz._ensure_configured)
  if not ok then
    return {}, err
  end

  local user_file = storage._get_data_path(game_id, constants.USER_NOTES_SUFFIX)

  local readable = vim.fn.filereadable(user_file)
  if readable == 0 then
    return {}, "file not found: " .. user_file
  end

  local lines = vim.fn.readfile(user_file)
  local notes = {}

  for i = constants.HEADER_LINE_COUNT, #lines do
    local note = M._parse_line(lines[i])
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

function M._write_local_note(game_id, note)
  local user_file = storage._get_data_path(game_id, constants.USER_NOTES_SUFFIX)

  local readable = vim.fn.filereadable(user_file)
  if readable == 0 then
    return false, "file not found: " .. user_file
  end

  local lines = vim.fn.readfile(user_file)
  local new_line = M._serialize(note)

  local found = false
  for i = constants.HEADER_LINE_COUNT, #lines do
    local addr = lines[i]:match(constants.NOTE_LINE_PATTERN)
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
    for i = constants.HEADER_LINE_COUNT, #lines do
      local addr = lines[i]:match(constants.NOTE_LINE_PATTERN)
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

function M.delete_local(game_id, address)
  local ok, err = pcall(razz._ensure_configured)
  if not ok then
    return false, err
  end

  local user_file = storage._get_data_path(game_id, constants.USER_NOTES_SUFFIX)

  local readable = vim.fn.filereadable(user_file)
  if readable == 0 then
    return false, "file not found: " .. user_file
  end

  local lines = vim.fn.readfile(user_file)
  local addr_num = tonumber(address, 16)
  local new_lines = {}

  for i = 1, #lines do
    if i < constants.HEADER_LINE_COUNT then
      table.insert(new_lines, lines[i])
    else
      local line = lines[i]
      local addr = line:match(constants.NOTE_LINE_PATTERN)
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

function M.export(game_id, note)
  local ok, err = pcall(razz._ensure_configured)
  if not ok then
    return false, err
  end

  return M._write_local_note(game_id, note)
end

function M.open(opts)
  if type(opts) == "string" then
    opts = { game_id = opts }
  end
  opts = opts or {}

  local game_id = razz.get_game_id_or_error(opts)
  if not game_id then
    return
  end

  local notes_list = M.get_all(game_id)
  require("razz.picker").open({ game_id = game_id, notes = notes_list })
end

function M.open_local(opts)
  opts = opts or {}
  if type(opts) == "string" then
    opts = { game_id = opts }
  end

  local game_id = razz.get_game_id_or_error(opts)
  if not game_id then
    return
  end

  local notes_list = M.load_from_local(game_id)
  require("razz.picker").open({ game_id = game_id, notes = notes_list })
end

function M.open_server(opts)
  opts = opts or {}
  if type(opts) == "string" then
    opts = { game_id = opts }
  end

  local game_id = razz.get_game_id_or_error(opts)
  if not game_id then
    return
  end

  local notes_list = M.load_from_server(game_id)
  require("razz.picker").open({ game_id = game_id, notes = notes_list })
end

function M.create_new(opts, address)
  if type(opts) == "string" then
    opts = { game_id = opts }
  end
  opts = opts or {}

  local game_id = razz.get_game_id_or_error(opts)
  if not game_id then
    return
  end

  local function do_create(addr)
    local normalized = helpers.normalize_address(addr)
    local note = { Address = normalized, Note = "" }
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

