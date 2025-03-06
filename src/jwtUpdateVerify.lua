local wgu = require("webgate/jwt-util")
local jwt = require "luajwt"
local cjson = require "cjson"
local template = require "resty.template"

function table_dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
        s = s .. '['..k..'] = ' .. table_dump(v) .. ','
      end
    return s .. '} '
  else
    return tostring(o)
  end
end

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

function verifyPayloadForUpdate(jwtconfig, payload)
  if payload.expr and type(payload.expr) ~= "number" then
    ngx.log(ngx.INFO, "Invalid format. expr is not number. " .. payload.expr)
    exitSinceDeny(jwtconfig, "Invalid format. expr [" .. payload.expr ..  "] is not number.")
  end

  if payload.expr and os.time() >= payload.expr then
    ngx.log(ngx.INFO, "expr is expired. " .. payload.expr)
    exitSinceDeny(jwtconfig, "expr [" .. payload.expr ..  "] is expired.")
  end

  if not jwtconfig.diff_attrs then
    ngx.log(ngx.INFO, "jwtconfig.diff_attrs is empty, so skip checking attributes.")
    return
  end

  if not jwtconfig.diff_attrs.targets or not jwtconfig.diff_attrs.targets or not(#jwtconfig.diff_attrs.targets > 0) then
    ngx.log(ngx.INFO, "diff_check is empty, so skip checking attributes.")
    return
  end

  local arHandlerPath = "/Shibboleth.sso/AttributeResolver"
  if jwtconfig.diff_attrs.attribute_resolver.handler_path and #jwtconfig.diff_attrs.attribute_resolver.handler_path > 0 then
    arHandlerPath = jwtconfig.diff_attrs.attribute_resolver.handler_path
  end
  ngx.log(ngx.INFO, "Handler url of AttributeResolver set to " .. arHandlerPath)
  
  local arNameIdFormat = "urn:oasis:names:tc:SAML:2.0:nameid-format:persistent"
  if jwtconfig.diff_attrs.attribute_resolver.name_id_format and #jwtconfig.diff_attrs.attribute_resolver.name_id_format > 0 then
    arNameIdFormat = jwtconfig.diff_attrs.attribute_resolver.name_id_format
  end
  ngx.log(ngx.INFO, "NameID format for AttributeResolver set to " .. arNameIdFormat)

  local arEntityID = jwtconfig.diff_attrs.attribute_resolver.entity_id
  ngx.log(ngx.INFO, "EntityID  for AttributeResolver set to " .. arEntityID)

  local arNameID = payload.sub
  ngx.log(ngx.INFO, "NameID  for AttributeResolver set to " .. arNameID)

  local resolvedAttrs = wgu.attributeQuery(arHandlerPath, arNameIdFormat, arEntityID, arNameID)

  if not resolvedAttrs then
    ngx.log(ngx.INFO, "Error occurred while resolving attributes.")
    exitSinceDeny(jwtconfig, "Error occurred while resolving attributes.")
  end
  
  for _,chkattr in ipairs(jwtconfig.diff_attrs.targets) do
    if payload[chkattr] then
      local jwtval = payload[chkattr]
      if resolvedAttrs[chkattr] then
        idpval = resolvedAttrs[chkattr]
        ngx.log(ngx.INFO, "Check diff " .. jwtval .. " vs " .. idpval .. "")
        if jwtval == idpval then
          ngx.log(ngx.INFO, "Value is same.")
        else
          ngx.log(ngx.INFO, "Detected difference of [" .. chkattr .. "]. Value: [" .. jwtval ..  "] vs [" .. idpval .. "]")
          exitSinceDeny(jwtconfig, "Detected diff_check, Attribute [" .. chkattr ..  "] is not same.")
        end
      else
        ngx.log(ngx.INFO, "IdP attribute has no [" .. chkattr .. "], so do failing verification.")
        exitSinceDeny(jwtconfig, "Detected diff_check, JWT has [" .. chkattr ..  "] but IdP sent no value.")
      end
    else
      if resolvedAttrs[chkattr] then
        ngx.log(ngx.INFO, "His token has no [" .. chkattr .. "], but IdP attribute has it. So failed verification.")
        exitSinceDeny(jwtconfig, "Detected diff_check, JWT has no [" .. chkattr ..  "] but IdP attribute has this.")
      else
        ngx.log(ngx.INFO, "His token and IdP attribute have no [" .. chkattr .. "] both, So skip it.")
      end
    end
  end
end

function verifySuitable(jwtconfig, token, key)
  local decoded, err = jwt.decode(token, key, false)
  if not decoded then
    ngx.log(ngx.INFO, "Falied to decode token, because.... " .. err)
    exitSinceDeny(jwtconfig, err)
  end
  if not decoded.expr then
    ngx.log(ngx.INFO, "Token has no expr, so re-varidate JWT.")
    decoded, err = jwt.decode(token, key, true)
    if not decoded then
      ngx.log(ngx.INFO, "Falied to decode token, because.... " .. err)
      exitSinceDeny(jwtconfig, err)
    end
  end

  return decoded
end

local jwtUpdateVerifier = {}

function jwtUpdateVerifier.tryAuthorizationHeader(jwtconfig)
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
  return verifySuitable(jwtconfig, token, jwtconfig.decode.key)
end

function jwtUpdateVerifier.tryCookie(jwtconfig)
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
  return verifySuitable(jwtconfig, cookie_token, jwtconfig.decode.key)
end

function jwtUpdateVerifier.tryRequestQuery(jwtconfig)
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
  return verifySuitable(jwtconfig, query_token, jwtconfig.decode.key)
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

local verifyingFuncs = { jwtUpdateVerifier.tryAuthorizationHeader, jwtUpdateVerifier.tryCookie, jwtUpdateVerifier.tryRequestQuery }

for _, func in ipairs(verifyingFuncs) do
  local claim = func(jwtconfig)
  if claim ~= nil then
    ngx.log(ngx.INFO, "Recieve valid token.")
    local res = verifyPayloadForUpdate(jwtconfig, claim)
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
