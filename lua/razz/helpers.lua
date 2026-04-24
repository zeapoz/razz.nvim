local M = {}

function M.unescape_content(content)
  return content:gsub("\\r", "\r"):gsub("\\n", "\n")
end

function M.escape_content(content)
  return content:gsub("\r", "\\r"):gsub("\n", "\\n")
end

function M.normalize_address(addr)
  local num_part = addr:sub(3):gsub("^0+", "")
  if num_part == "" then
    num_part = "0"
  end
  return "0x" .. num_part
end

function M.format_address(addr)
  local num = tonumber(addr, 16)
  if not num then
    return addr
  end
  return string.format("0x%08x", num)
end

function M.addresses_equal(addr1, addr2)
  local num1 = tonumber(addr1, 16)
  local num2 = tonumber(addr2, 16)
  return num1 and num2 and num1 == num2
end

function M.find_note_by_addr(notes, address)
  for _, note in ipairs(notes) do
    if M.addresses_equal(note.Address, address) then
      return note
    end
  end
  return nil
end

function M.normalize_for_display(content)
  return content:gsub("\r\n", "\n")
end

return M
