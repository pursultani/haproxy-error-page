--
-- error-page.lua
-- 
--   A script for handling HTTP error pages in HAProxy
--

core.Alert("lua.error-page: init started")

--
-- find_config_file_path:
--
--   returns path of the main HAProxy config file, e.g. `haproxy.cfg` 
-- 
function find_config_file_path()
  local cmd_file = io.open("/proc/self/cmdline", "rb")
  local cmd_line = cmd_file:read("a*")
  cmd_file:close()
  for s in string.gmatch(cmd_line, "%g+") do
    if s == "-f" then
      found = true
    elseif found then
      file_path = s
      break
    end
  end
  if file_path == nil then
    core.Warning("lua.error-page: config file path not found")
  else
    core.Debug("lua.error-page: config file path: " .. file_path)
  end
  return file_path
end


--
-- read_error_file
--
--   reads and returns the content of an error file
--
function read_error_file(file_path)
  local error_file = io.open(file_path, "r")
  if error_file == nil then
    core.Warning("lua.error-page: error file not found: " .. file_path)
    return nil
  end
  local error_page = error_file:read("a*")
  error_file:close()
  core.Debug(string.format("lua.error-page: error page: %s [%d]", file_path, error_page:len()))
  return error_page
end


--
-- read_error_pages
--
--   reads `errorfile` keywords from config file and returns a mapping between
--   status codes and error pages
--
function read_error_pages(file_path)
  local config_file = io.open(file_path, "r")
  local error_pages = {}
  while true do
    local line = config_file:read()
    if line == nil then
      break
    end
    local parts = line:gmatch("%S+")
    if parts() == "errorfile" then
      local error_code = parts()
      local error_file = parts()
      if error_code ~= nil and error_file ~= nil then
        error_page = read_error_file(error_file)
        if error_page ~= nil then
          error_pages[error_code] = error_page
          core.Debug(string.format("lua.error-page: %s page is available", error_code))
        end
      end
    end
  end
  config_file:close()
  return error_pages
end

--
-- error_pages
--
--   status code to error page mapping
--
error_pages = read_error_pages(find_config_file_path())

--
-- lua.error-page
--
--   the error-page action for http-response
--
core.register_action("error-page", { "http-res" }, function(txn)
  local error_code = txn.sf:status()
  local error_page = error_pages[error_code]
  if error_page ~= nil then
    txn:Debug("lua.error-page: rewrite error page: " .. error_code)
    txn.res:set("")
    txn.res:send(error_page)
    txn:done()
  end
end)
