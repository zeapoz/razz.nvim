local CodeNote = {
  LOCAL_USER_LABEL = "Local Note",
  ADDRESS_FORMAT = "0x%08x",
}

function CodeNote:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function CodeNote:serialize()
  local addr_padded = self:format_address()
  local escaped = self.content:gsub("\r", "\\r"):gsub("\n", "\\n")
  return "N0:" .. addr_padded .. ':"' .. escaped .. '"'
end

function CodeNote:format_address()
  local num = tonumber(self.address, 16)
  if not num then
    return self.address
  end
  return string.format(self.ADDRESS_FORMAT, num)
end

function CodeNote:is_local()
  return self.user == self.LOCAL_USER_LABEL
end

function CodeNote:from_line(line)
  local addr, content = line:match('^N0:(0x[%x]+):"(.*)"')
  if not addr then
    return nil
  end
  local normalized_addr = string.format("0x%x", tonumber(addr, 16)):lower()
  local unescaped = content:gsub("\\r", "\r"):gsub("\\n", "\n")
  return self:new({
    address = normalized_addr,
    content = unescaped,
    user = self.LOCAL_USER_LABEL,
  })
end

function CodeNote:from_server(json)
  local normalized_addr = string.format("0x%x", tonumber(json.Address, 16)):lower()
  return self:new({
    address = normalized_addr,
    content = json.Note or "",
    user = json.User,
  })
end

function CodeNote:new_note(address, content)
  local normalized_addr = string.format("0x%x", tonumber(address, 16)):lower()
  return self:new({
    address = normalized_addr,
    content = content or "",
    user = self.LOCAL_USER_LABEL,
  })
end

function CodeNote:from_buffer_content(address, buffer_content)
  local normalized_addr = string.format("0x%x", tonumber(address, 16)):lower()
  return self:new({
    address = normalized_addr,
    content = buffer_content,
    user = self.LOCAL_USER_LABEL,
  })
end

return CodeNote
