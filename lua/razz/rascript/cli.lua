local config = require("razz.config")
local storage = require("razz.storage")

local M = {}

--- Runs a rascript-cli command asynchronously.
---@param cmd string[] Command arguments
---@param on_done fun() Callback when command completes with no output
---@return nil
local function run_command(cmd, on_done)
  local cli_path = vim.fn.expand(config.rascript_cli_bin)
  if vim.fn.executable(cli_path) == 0 then
    vim.notify("Could not find rascript-cli binary at: " .. cli_path, vim.log.levels.ERROR)
    return
  end

  vim.system({ cli_path, unpack(cmd) }, { text = true }, function(result)
    if result.code ~= 0 and result.stderr ~= "" then
      vim.notify(result.stderr, vim.log.levels.ERROR)
    elseif result.stdout ~= "" then
      vim.notify(result.stdout, vim.log.levels.INFO)
    else
      on_done()
    end
  end)
end

--- Exports a RAScript file using rascript-cli.
--- If no file is provided, exports the current buffer.
---@param input_file? string Explicit file path to export
---@param output_dir? string Explicit output directory
---@return nil
function M.export(input_file, output_dir)
  if input_file then
    M.do_export(input_file, output_dir)
  else
    M.export_current_file(output_dir)
  end
end

--- Exports the current buffer's RAScript file using rascript-cli.
--- Prompts to save if the buffer is modified.
---@param output_dir? string Explicit output directory
---@return nil
function M.export_current_file(output_dir)
  local cli_path = vim.fn.expand(config.rascript_cli_bin)
  if vim.fn.executable(cli_path) == 0 then
    vim.notify("Could not find rascript-cli binary at: " .. cli_path, vim.log.levels.ERROR)
    return
  end

  local current_file = vim.fn.expand("%")
  if current_file == "" then
    vim.notify("No file to export", vim.log.levels.ERROR)
    return
  end

  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].modified then
    local confirm = vim.fn.confirm("Buffer has unsaved changes. Save before export?", "&Yes\n&No", 1)
    if confirm == 1 then
      vim.cmd("write")
    end
  end

  M.do_export(current_file, output_dir)
end

--- Exports a RAScript file to the emulation directory.
---@param input_file string The input RAScript file path
---@param output_dir? string Explicit output directory
---@return nil
function M.do_export(input_file, output_dir)
  local emulation_dir = output_dir
  if not emulation_dir then
    local dir, err = storage.get_emulation_dir()
    if not dir then
      vim.notify("Could not determine emulator directory: " .. err, vim.log.levels.ERROR)
      return
    end
    emulation_dir = dir
  end

  run_command({ "-i", input_file, "-o", emulation_dir }, function()
    vim.notify("Export completed successfully", vim.log.levels.INFO)
  end)
end

return M
