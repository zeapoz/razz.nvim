---@module "razz.util"
local M = {}

local constants = require("razz.constants")

--- Formats an address as a padded lowercase hex string.
---@param address number The memory address
---@return string The formatted address (e.g., "0x00001234")
function M.format_hex_address(address)
  return string.format(constants.ADDRESS_FORMAT, address)
end

--- Finds an item in a list by address.
---@param items CodeNote[] The list of items to search
---@param address number The address to find
---@return CodeNote|nil The item with the matching address, or nil
function M.find_by_address(items, address)
  if not items then
    return nil
  end
  for _, item in ipairs(items) do
    if item.address == address then
      return item
    end
  end
  return nil
end

return M
