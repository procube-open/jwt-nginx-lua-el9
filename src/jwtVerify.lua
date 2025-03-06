local wgu = require("webgate/jwt-util")
local jwt = require "luajwt"
local cjson = require "cjson"
local template = require "resty.template"

function exitSinceDeny(jwtconfig, msg)
  local status = ngx.HTTP_FORBIDDEN
  if jwtconfig.onDeny ~= nil and jwtconfig.onDeny.code ~= nil then
    local tmpcode = tonumber(jwtconfig.onDeny.code)
    if tmpcode then
      status = tmpcode
    end
  end
  ngx.status = status

  if jwtconfig.onDeny ~= nil and jwtconfig.onDeny.template ~= nil then
    local deny_thml = ngx.location.capture("/jwt.settings/" .. jwtconfig.onDeny.template)
    local tplfunc = template.compile(deny_thml.body)
    local contenttype = wgu.decideContentType(jwtconfig.onDeny.template)
    ngx.header["Content-Type"] = contenttype
    ngx.say(tplfunc{ message = msg })
  end

  if jwtconfig.onDeny ~= nil and jwtconfig.onDeny.redirect ~= nil then
    local tplfunc = template.compile(jwtconfig.onDeny.redirect.uri)
    local location = tplfunc(ngx.var)
    if jwtconfig.onDeny.redirect.param_name then
      local original = ngx.var.scheme .. "://" .. ngx.var.http_host .. ngx.var.request_uri
      location = location .. "?" .. jwtconfig.onDeny.redirect.param_name .. "=" .. wgu.urlencode(original)
    end
    ngx.header["location"] = location
  end

  ngx.exit(ngx.HTTP_OK)
end

local jwtVerifier = {}

function jwtVerifier.tryAuthorizatuinHeader(jwtconfig)
  local auth_header = ngx.var.http_Authorization
  if auth_header == nil then
    ngx.log(ngx.INFO, "No Authorization header, skip this process.")
    return
  end

  ngx.log(ngx.INFO, "Authorization header found. The value is " .. auth_header)

  local _, _, token = string.find(auth_header, "Bearer%s+(.+)")
  if token == nil then
    ngx.log(ngx.INFO, "Missing token....., so skip this process.")
    return
  end

  ngx.log(ngx.INFO, "Token found in Authorization header. " .. token)
  local decoded, err = jwt.decode(token, jwtconfig.decode.key, true)
  if not decoded then
    ngx.log(ngx.INFO, "Falied to decode token, because.... " .. err)
    exitSinceDeny(jwtconfig, err)
  end

  return decoded
end

function jwtVerifier.tryCookie(jwtconfig)
  if jwtconfig.receive == nil or jwtconfig.receive.byCookie == nil then
    ngx.log(ngx.INFO, "receive.byCookie is not found in config")
    return
  end
  if jwtconfig.receive.byCookie.name == nil or #jwtconfig.receive.byCookie.name == 0 then
    ngx.log(ngx.INFO, "receive.byCookie.name is not found in config or empty.")
    return
  end

  local varname = "cookie_" .. jwtconfig.receive.byCookie.name
  local cookie_token = ngx.var[varname]
  if cookie_token == nil then
    ngx.log(ngx.INFO, "No Cookie " .. jwtconfig.receive.byCookie.name .. " found, so skip this process..")
    return
  end

  ngx.log(ngx.INFO, "Token found in Cookie. " .. cookie_token)
  local decoded, err = jwt.decode(cookie_token, jwtconfig.decode.key, true)
  if not decoded then
    ngx.log(ngx.INFO, "Falied to decode token, because.... " .. err)
    exitSinceDeny(jwtconfig, err)
    return
  end

  return decoded
end

function jwtVerifier.tryRequestQuery(jwtconfig)
  if jwtconfig.receive == nil or jwtconfig.receive.byQuery == nil then
    ngx.log(ngx.INFO, "receive.byQuery is not found in config")
    return
  end
  if jwtconfig.receive.byQuery.name == nil or #jwtconfig.receive.byQuery.name == 0 then
    ngx.log(ngx.INFO, "receive.byQuery.name is not found in config or empty.")
    return
  end

  local varname = "arg_" .. jwtconfig.receive.byQuery.name
  local query_token = ngx.var[varname]
  if query_token == nil then
    ngx.log(ngx.INFO, "No query paramter " .. jwtconfig.receive.byQuery.name .. " found, so skip this process..")
    return
  end

  ngx.log(ngx.INFO, "Token found in request query. " .. query_token)
  local decoded, err = jwt.decode(query_token, jwtconfig.decode.key, true)
  if not decoded then
    ngx.log(ngx.INFO, "Falied to decode token, because.... " .. err)
    exitSinceDeny(jwtconfig, err)
    return
  end

  return decoded
end

function jwtVerifier.checkRevoked(jwtconfig, decodedClaim)
  ngx.log(ngx.INFO, "Check if the jwt is revoked by revokeList.")
  if not ngx.var.revokeList then
    ngx.log(ngx.INFO, "Variable of revoke-list is empty.")
    return
  end

  local issuedAt = tonumber(decodedClaim.iat)
  if not issuedAt then
    ngx.log(ngx.INFO, "JWT has not \"iat\", so skip revoking.")
    return
  end

  revokeRes = ngx.location.capture("/jwt.settings/" .. ngx.var.revokeList)
  if revokeRes == nil or revokeRes.status ~= ngx.HTTP_OK or #revokeRes.body == 0 then
    ngx.log(ngx.INFO, "Revoke-list [" .. ngx.var.revokeList .. "] is empty or not exists.")
    return
  end

  local revokeconfig = cjson.decode(revokeRes.body)
  if revokeconfig == nil then
    ngx.log(ngx.INFO, "Failed to decode revoke list as JSON, input was => " .. revokeRes.body)
    return
  end
  if revokeconfig.list == nil or type(revokeconfig.list) ~= "table" then
    ngx.log(ngx.INFO, "Invalid revoke list, .list is missing. It must be table, input was => " .. revokeRes.body)
    return
  end

  local revokeList = revokeconfig.list
  local revokeDtStr = nil
  for k,v in pairs(revokeList) do
    if v.sub == decodedClaim.sub then
      ngx.log(ngx.INFO, "Found sub " .. v.sub .. ", so set exp " .. v.exp)
      revokeDtStr = v.exp
      break
    end
  end

  if revokeDtStr == nil or #revokeDtStr == 0 then
    ngx.log(ngx.INFO, "User " .. decodedClaim.sub .. " is not found in revokeList.")
    return
  end

  ngx.log(ngx.INFO, "User " .. decodedClaim.sub .. " is found in revokeList.")

  local xyear, xmonth, xday, xhour, xminute, xseconds = revokeDtStr:match("(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)")
  if xyear == nil or xmonth == nil or xday == nil or xhour == nil or xminute == nil or xseconds == nil or
     #xyear == 0 or #xmonth == 0 or #xday == 0 or #xhour == 0 or #xminute == 0 or #xseconds == 0 then
    ngx.log(ngx.INFO, "DateTime value is invalid format. It must be yyyy/MM/dd HH:mm:ss but " .. revokeDtStr)
    return
  end

  local revokeTs = os.time({year = xyear, month = xmonth, day = xday, hour = xhour, min = xminute, sec = xseconds})
  if issuedAt < revokeTs then
    ngx.log(ngx.INFO, "User " .. decodedClaim.sub .. " is revoked. iat=" .. issuedAt .. " vs rvlist=" .. revokeTs)
    exitSinceDeny(jwtconfig, "User " .. decodedClaim.sub .. " is revoked by revokedList.")
  end

  ngx.log(ngx.INFO, "User " .. decodedClaim.sub .. " is NOT revoked. iat=" .. issuedAt .. " vs rvlist=" .. revokeTs)
end

function errorExitNoConf()
  ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
  ngx.say("Cannot load configuration file...")
  ngx.exit(ngx.OK)
end

-- Read configuration,
local confname = ngx.var.verifyconf
if not confname or #confname == 0 then
  if ngx.var.conf and #ngx.var.conf > 0 then
    ngx.log(ngx.WARN, "Variable $conf for configuration is deprecated. Use $verifyconf.")
    confname = ngx.var.conf
  else
    errorExitNoConf()
  end
end
configRes = ngx.location.capture("/jwt.settings/" .. confname)
local jwtconfig = cjson.decode(configRes.body)
ngx.log(ngx.INFO, "jwt start processing...  " .. jwtconfig.type)

local verifyingFuncs = { jwtVerifier.tryAuthorizatuinHeader, jwtVerifier.tryCookie, jwtVerifier.tryRequestQuery }
for _, func in ipairs(verifyingFuncs) do
  local claim = func(jwtconfig)
  if claim ~= nil then
    ngx.log(ngx.INFO, "Recieve valid token.")
    jwtVerifier.checkRevoked(jwtconfig, claim)
    for k,v in pairs(claim) do
      ngx.log(ngx.INFO, "Claim part " .. k .. "=" .. v)
      local jwtkey = "nswg_jwt_" .. k
      if ngx.var[jwtkey] ~= nil then
        ngx.var[jwtkey] = v
      end
    end
    ngx.ctx.verifiedClaim = claim
    ngx.exit(ngx.OK)
    return
  end
end

ngx.log(ngx.INFO, "Failed to verifying token, access rejected.")
exitSinceDeny(jwtconfig, "Suitable token was not sent.")
