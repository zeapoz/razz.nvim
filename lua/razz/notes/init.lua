---@module "razz.notes"
---@class razz.notes._FindLineOpts
---@field find_insert_pos? boolean If true, returns insert position instead of exact match

local M = {}
local storage = require("razz.storage")
local razz = require("razz")
local util = require("razz.util")
local LocalNote = require("razz.notes.types.local")
local LocalNotes = require("razz.notes.types.local_notes")
local ServerNotes = require("razz.notes.types.server_notes")

--- Resolves a game ID from input or infers from current buffer.
---@param game_id? string|number The game ID (or nil to infer)
---@return string|nil The resolved game ID, or nil on failure
local function resolve_game_id(game_id)
  local id, err = razz.get_game_id_or_error(game_id)
  if not id then
    if err then
      vim.notify(err, vim.log.levels.ERROR)
    end
  end
  return id
end

--- Loads local notes for a game.
---@param game_id string The game ID
---@return LocalNote[]|nil The notes array, or nil if not found
---@return string|nil Error message if failed
local function load_local_notes(game_id)
  local notes_obj, load_err = LocalNotes.load(game_id)
  if not notes_obj then
    return nil, load_err
  end
  return notes_obj.notes
end

--- Loads server notes for a game.
---@param game_id string The game ID
---@return LocalNote[]|nil The notes array, or nil if not found
---@return string|nil Error message if failed
local function load_server_notes(game_id)
  local notes_obj, load_err = ServerNotes.load(game_id)
  if not notes_obj then
    return nil, load_err
  end
  return notes_obj.notes
end

--- Marks a note as synced by updating server JSON and removing local note.
---@param game_id string The game ID
---@param address number The note address
---@param content string The note content
---@return boolean True if successful
---@return string|nil Error message if failed
function M.mark_synced(game_id, address, content)
  local server_notes, load_err = ServerNotes.load(game_id)
  if not server_notes then
    return false, load_err
  end

  local username = storage.get_username()
  if not username then
    return false, "not logged in"
  end

  server_notes:update_or_add(address, content, username)

  local ok, save_err = server_notes:save()
  if not ok then
    return false, save_err
  end

  local local_notes = LocalNotes.load(game_id)
  if local_notes then
    local_notes:delete(address)
  end

  return true
end

--- Gets all notes (server and local) for a game, merging them.
--- Local notes override server notes at the same address.
---@param game_id string The game ID
---@return CodeNote[] Array of all merged notes
function M.get_all(game_id)
  local server_notes_obj = ServerNotes.load(game_id)
  local local_notes_obj = LocalNotes.load(game_id)

  local server_notes = server_notes_obj and server_notes_obj.notes or {}
  local local_notes = local_notes_obj and local_notes_obj.notes or {}

  local results = {}
  local seen = {}

  for _, note in ipairs(server_notes) do
    local addr = note.address
    local local_note = util.find_by_address(local_notes, addr)
    if local_note then
      table.insert(results, local_note)
    else
      table.insert(results, note)
    end
    seen[addr] = true
  end

  for _, note in ipairs(local_notes) do
    if not seen[note.address] then
      table.insert(results, note)
    end
  end

  return results
end

--- Exports a note to the local notes file.
---@param game_id string The game ID
---@param note LocalNote The note to export
---@return boolean True if successful
---@return string|nil Error message if failed
function M.export(game_id, note)
  local local_notes, load_err = LocalNotes.load(game_id)
  if not local_notes then
    return false, load_err
  end

  local_notes:update_or_add(note)
  return local_notes:save()
end

--- Opens a specific note or the notes picker with all notes (server and local).
---@param game_id? string|number The game ID (or nil to infer)
---@param address? number If provided, opens note at address directly (skips picker)
function M.open(game_id, address)
  local resolved_game_id = resolve_game_id(game_id)
  if not resolved_game_id then
    return
  end

  if address then
    local notes_list = M.get_all(resolved_game_id)
    local note = util.find_by_address(notes_list, address)
    if note then
      require("razz.notes.buffer").open_buffer(note)
    else
      vim.notify("No note found at address: " .. util.format_hex_address(address), vim.log.levels.WARN)
    end
    return
  end

  local notes_list = M.get_all(resolved_game_id)
  require("razz.picker").open({ game_id = resolved_game_id, notes = notes_list })
end

--- Opens a specific local note or the notes picker with local notes only.
---@param game_id? string|number The game ID (or nil to infer)
---@param address? number If provided, opens note at address directly (skips picker)
function M.open_local(game_id, address)
  local resolved_game_id = resolve_game_id(game_id)
  if not resolved_game_id then
    return
  end

  if address then
    local local_notes = LocalNotes.load(resolved_game_id)
    local note = local_notes and local_notes:find_by_addr(address)
    if note then
      require("razz.notes.buffer").open_buffer(note)
    else
      vim.notify("No local note found at address: " .. util.format_hex_address(address), vim.log.levels.WARN)
    end
    return
  end

  local notes_list = load_local_notes(resolved_game_id)
  require("razz.picker").open({ game_id = resolved_game_id, notes = notes_list or {} })
end

--- Opens a specific server note or the notes picker with server notes only.
---@param game_id? string|number The game ID (or nil to infer)
---@param address? number If provided, opens note at address directly (skips picker)
function M.open_server(game_id, address)
  local resolved_game_id = resolve_game_id(game_id)
  if not resolved_game_id then
    return
  end

  if address then
    local server_notes = ServerNotes.load(resolved_game_id)
    local note = server_notes and server_notes:find_by_addr(address)
    if note then
      require("razz.notes.buffer").open_buffer(note)
    else
      vim.notify("No server note found at address: " .. util.format_hex_address(address), vim.log.levels.WARN)
    end
    return
  end

  local notes_list = load_server_notes(resolved_game_id)
  require("razz.picker").open({ game_id = resolved_game_id, notes = notes_list or {} })
end

--- Fetches server notes from the server.
---@param game_id? string|number The game ID (or nil to infer)
function M.fetch_server(game_id)
  local resolved_game_id = resolve_game_id(game_id)
  if not resolved_game_id then
    return
  end

  ServerNotes.fetch_from_server(resolved_game_id)
end

--- Creates a new note at the given address or prompts for one.
---@param address? number Optional address to create note at
---@param game_id? string|number The game ID (or nil to infer)
function M.open_new(address, game_id)
  local resolved_game_id = resolve_game_id(game_id)
  if not resolved_game_id then
    return
  end

  local function do_create(addr)
    local note = LocalNote:new(addr, "", resolved_game_id)
    require("razz.notes.buffer").open_buffer(note, nil, true)
  end

  if address then
    do_create(address)
  else
    vim.ui.input({ prompt = "Address: " }, function(input)
      if input and input ~= "" then
        do_create(tonumber(input, 16))
      end
    end)
  end
end

--- Publishes a single local note to the server.
--- If address is provided, publishes that specific note.
--- Otherwise, falls back to publishing the current buffer's note.
---@param address? number The note address (or nil to use buffer.publish)
---@param game_id? string|number The game ID (required if address provided)
function M.publish(address, game_id)
  if address then
    local resolved_game_id = resolve_game_id(game_id)
    if not resolved_game_id then
      return
    end

    local local_notes = load_local_notes(resolved_game_id)
    if not local_notes then
      vim.notify("Failed to load local notes", vim.log.levels.ERROR)
      return
    end

    local note
    for _, n in ipairs(local_notes) do
      if n.address == address then
        note = n
        break
      end
    end
    if not note then
      vim.notify("Local note not found at address: " .. util.format_hex_address(address), vim.log.levels.ERROR)
      return
    end

    if not note.address or not note.content then
      vim.notify("Note is missing address or content", vim.log.levels.ERROR)
      return
    end

    local note_to_publish = LocalNote:new(note.address, note.content, resolved_game_id)
    note_to_publish:publish()
    return
  end

  require("razz.notes.buffer").publish()
end

--- Publishes all local notes to the server sequentially.
---@param game_id? string|number The game ID (or nil to infer)
function M.publish_all(game_id)
  local resolved_game_id = resolve_game_id(game_id)
  if not resolved_game_id then
    return
  end

  local local_notes = load_local_notes(resolved_game_id)
  if not local_notes then
    vim.notify("Failed to load local notes", vim.log.levels.ERROR)
    return
  end

  local count = #local_notes
  if count == 0 then
    vim.notify("No local notes to publish", vim.log.levels.WARN)
    return
  end

  local prompt_msg = string.format("Upload %d local code note%s? ", count, count == 1 and "" or "s")
  local confirm = vim.fn.confirm(prompt_msg, "&Yes\n&No", 1)
  if confirm ~= 1 then
    return
  end

  local function publish_next(index)
    if index > count then
      vim.notify("All notes published", vim.log.levels.INFO)
      return
    end

    local note = local_notes[index]
    local note_to_publish = LocalNote:new(note.address, note.content, resolved_game_id)

    note_to_publish:publish()

    vim.defer_fn(function()
      publish_next(index + 1)
    end, 500)
  end

  publish_next(1)
end

--- Creates and exports a note to the local notes file.
---@param address number The memory address
---@param lines string[] Array of lines
---@param game_id? string|number The game ID (or nil to infer)
---@return boolean True if successful
---@return string|nil Error message if failed
function M.create_new(address, lines, game_id)
  lines = lines or {}

  local resolved_game_id = resolve_game_id(game_id)
  if not resolved_game_id then
    return false, "invalid game_id"
  end

  local content = table.concat(lines, "\r\n")
  local note = LocalNote:new(address, content, resolved_game_id)
  local local_notes, load_err = LocalNotes.load(resolved_game_id)
  if not local_notes then
    return false, load_err
  end
  local_notes:update_or_add(note)
  return local_notes:save()
end

return M
