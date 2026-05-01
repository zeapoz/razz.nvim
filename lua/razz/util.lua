---@module "razz.util"
local M = {}

local constants = require("razz.constants")

--- Formats an address as a padded lowercase hex string.
---@param address number The memory address
---@return string The formatted address (e.g., "0x00001234")
function M.format_hex_address(address)
  return string.format(constants.ADDRESS_FORMAT, address)
end

return M
