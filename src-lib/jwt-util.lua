local string = require("string")
local cjson = require("cjson")
local table = require("table")
local base = _G
local _M = {}
if module then -- heuristic for exporting a global package table
    jwtUtil = _M
end


function _M.attributeQuery(handler_url, nameid_format, entity_id, nameid)
  if not handler_url and not #handler_url > 0 then
    ngx.log(ngx.ERR, "handler url is empty.")
    return
  end

  local arUrl = handler_url .. "?format=" .. __urlencode(nameid_format) .. "&entityID=" .. __urlencode(entity_id) .. "&nameId=" .. __urlencode(nameid) .. "&encoding=JSON%2FCGI"

  ngx.log(ngx.INFO, "Now executing request to Attribute Authority by: " .. arUrl)
  local arRes = ngx.location.capture(arUrl, { vars = { internal_ar = 1 }})
  
  if not arRes then
    ngx.log(ngx.WARN, "Error occurred while resolving attributes.")
    return
  end
  
  ngx.log(ngx.INFO, "Attribute Authority returned status: " .. arRes.status)
  ngx.log(ngx.INFO, "Attribute Authority returned body: " .. arRes.body)
  local ret, resolvedAttrs = pcall(cjson.decode, arRes.body)
  -- ngx.log(ngx.INFO, "Attribute Authority returned: " .. table_dump(resolvedAttrs))
  if ret then
    return resolvedAttrs
  else
    ngx.log(ngx.INFO, "Failed to decode JSON : ".. resolvedAttrs)
    return nil
  end
end

function setCtx(table, prefix)
  for k,v in pairs(table) do
    ngx.ctx[prefix .. k] = v
  end
end

local resolvedAttrsPrefix = "nswg_ar_"

function _M.setResolvedAttrsToCtx(table)
  setCtx(table, resolvedAttrsPrefix)
end

function decideValue(type, name)
    ngx.log(ngx.INFO, "Acquire value from " .. tostring(type) .. " named " .. name)
    local val
    if type == nil or #type == 0 or type == "static" then
        val = name -- when static, in fact, name is value.
    elseif type == "variable" then
        val = ngx.var[name]
    elseif type == "header" then
        local lowerkey = string.lower(name)
        val = ngx.req.get_headers()[lowerkey]
    elseif type == "jwt" then
        val = ngx.ctx.verifiedClaim[name]
    elseif type == "attribute_resolver" then
        val = ngx.ctx[resolvedAttrsPrefix .. name]
    else
        ngx.log(ngx.ERR, "UNKNOWN type!!!!  " .. ssoconfig.type)
    end
    ngx.log(ngx.INFO, "Acquired value [" .. (val and val or "<<< FAILED TO GET VALUE >>>") .. "]")
    return val
end

function _M.acquireValue(type, name)
    return decideValue(type, name)
end

-- function resolveParam() is for FORM parameters.So credconfig has 3 parameters below.
-- credconfig.type : Type name for resolving. Ex. static, header, jwt.
-- credconfig.value : Value for corresponding to credconfig.type. static value, header name, JWT property name, and so on.
-- credconfig.name : Name of HTML-Form like INPUT. So does not use this in this function.
function _M.resolveParam(credconfig)
    return decideValue(credconfig.type, credconfig.value)
end

function _M.toUnicode(a)
    a1,a2,a3,a4 = a:byte(1, -1)
    ans = string.format ("%%%02X", a1)
    n = a2
    if (n) then
        ans = ans .. string.format ("%%%02X", n)
    end
    n = a3
    if (n) then
        ans = ans .. string.format ("%%%02X", n)
    end
    n = a4
    if (n) then
        ans = ans .. string.format ("%%%02X", n)
    end
    return ans
end

function _M.urlencode(str)
  return __urlencode(str)
end

function __urlencode(str)
    if (str) then
        -- str = string.gsub(str, "\\n", "\\r\\n")
        str = string.gsub(str, "([^%w ])", _M.toUnicode)
        str = string.gsub(str, " ", "+")
    end
    return str
end

function getFileExtension(filename)
  return filename:match("^.+(%..+)$")
end

function _M.decideContentType(template_filename)
  local ext = getFileExtension(template_filename)
  if (ext == ".html") then
    return "text/html"
  elseif (ext == ".json") then
    return "application/json"
  else
    ngx.log(ngx.ERR, "Unsupported extension " .. ext .. "")
    return "text/plain"
  end
end

return _M

