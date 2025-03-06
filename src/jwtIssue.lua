local wgu = require("webgate/jwt-util")
local jwt = require "luajwt"
local cjson = require "cjson"
local template = require "resty.template"
local lrex = require ("rex_pcre")

function string.ends(String,End)
  return End=='' or string.sub(String,-string.len(End))==End
end

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

function updatePayload(jwtconfig, updateTemplate)
  local dtnow = os.time()
  local payload = updateTemplate
  local oldexp = updateTemplate.exp
  local err
  payload.nbf = dtnow
  payload.iat = dtnow
  payload.exp = dtnow + jwtconfig.encode.expSec
  ngx.log(ngx.INFO, "JWT updated. Exp " .. oldexp .. " to " .. payload.exp)
  
  if updateTemplate.expr and updateTemplate.expr > 0 then
    payload.expr = updateTemplate.expr
  else
    ngx.log(ngx.INFO, "updatePayload(): His JWT token has no expr, so set nothing.")
  end
  return payload, err
end

function genPayload(jwtconfig)
  local targetVarName = jwtconfig.subject.var_name
  local targetVal = ""
  local err
  ngx.log(ngx.INFO, targetVarName)
  if (jwtconfig.subject.from == "variable") then
    targetVal = ngx.var[targetVarName]
  elseif (jwtconfig.subject.from == "header") then
    targetVal = ngx.req.get_headers()[targetVarName]
  else
    ngx.log(ngx.ERR, "Unknown subject source. Check your subject.from.")
  end

  if (targetVal == nil) then
    ngx.log(ngx.ERR, "Failed to acquire subject-value.")
    targetVal = "__UNKNOWN__"
    err = "Unknown authenticated user."
  end

  local dtnow = os.time()
  local payload = {
    sub = targetVal,
    nbf = dtnow,
    iat = dtnow,
    exp = dtnow + jwtconfig.encode.expSec,
  }

  if jwtconfig.encode.updateExpSec and #jwtconfig.encode.updateExpSec > 0 then
    payload.expr = dtnow + jwtconfig.encode.updateExpSec
  else
    ngx.log(ngx.INFO, "genPayload(): jwtconfig.encode.expSec is missing, maybe config format is too old. So do nothing.")
    -- payload.expr = dtnow + jwtconfig.encode.expSec
  end

  local privateClaim = jwtconfig.privateClaim
  if not privateClaim then
    ngx.log(ngx.INFO, "Private Claim setting is empty.")
    return payload, err
  end

  ngx.log(ngx.INFO, "Private Claim required. So acquiring...")
  -- table_dump(ngx.req.get_headers())
  if privateClaim.copyFromHeader and #privateClaim.copyFromHeader > 0 then
    local headerNames = privateClaim.copyFromHeader
    for i,hname in ipairs(headerNames) do
      local lowerkey = string.lower(hname)
      local hval = ngx.req.get_headers()[lowerkey]
      if hval and #hval > 0 then
        ngx.log(ngx.INFO, "Header " .. hname .. " is exists, so set value " .. hval)
        payload[hname] = hval
      else
        ngx.log(ngx.INFO, "Header " .. hname .. " is NOT exists.")
      end
    end
  end

  if privateClaim.copyFromVariable and #privateClaim.copyFromVariable > 0 then
    local varNames = privateClaim.copyFromVariable
    for i,vname in ipairs(varNames) do
      local vval = ngx.var["HTTP_" .. vname]
      if vval and #vval > 0 then
        ngx.log(ngx.INFO, "Variable " .. vname .. " is exists, so set value " .. vval)
        payload[vname] = vval
      else
        ngx.log(ngx.INFO, "Variable " .. vname .. " is NOT exists.")
      end
    end
  end

  return payload, err
end

function errorExit(jwtconfig, strMessage, strCode)
  local error_html = ngx.location.capture("/jwt.settings/" .. jwtconfig.onError.template)
  local tplfunc = template.compile(error_html.body)
  local contenttype = wgu.decideContentType(jwtconfig.onError.template)
  if (jwtconfig.onError.code and #jwtconfig.onError.code > 0) then
    ngx.status = jwtconfig.onError.code
  else
    ngx.status = ngx.HTTP_OK
  end
  ngx.header["Content-Type"] = contenttype
  ngx.say(tplfunc{ message = strMessage, code = strCode })
  ngx.exit(ngx.OK)
end

function errorExitNoConf()
  ngx.status = ngx.HTTP_INTERNAL_SERVER_ERROR
  ngx.say("Cannot load configuration file...")
  ngx.exit(ngx.OK)
end

-- Start MAIN
-- Read configuration,
local confname = ngx.var.issuerconf
if not confname or #confname == 0 then
  if ngx.var.conf and #ngx.var.conf > 0 then
    ngx.log(ngx.WARN, "Variable $conf for configuration is deprecated. Use $issuerconf.")
    confname = ngx.var.conf
  else
    errorExitNoConf()
  end
end
ngx.log(ngx.INFO, confname)
configRes = ngx.location.capture("/jwt.settings/" .. confname)
local jwtconfig = cjson.decode(configRes.body)
ngx.log(ngx.INFO, "jwt start processing...  " .. jwtconfig.type)

-- When request includes redirect_uri parameter, 
-- check if match with onSuccess.redirect.uriPattern.
local req_args = ngx.req.get_uri_args()
if (req_args.redirect_uri and #req_args.redirect_uri > 0) then
  ngx.log(ngx.INFO, "Request includes redirect_uri parameter. Check if is permitted.")

  local ckeckUriPattern = jwtconfig.onSuccess.redirect and jwtconfig.onSuccess.redirect.uriPattern or nil
  if not ckeckUriPattern or #ckeckUriPattern == 0 then
    ngx.log(ngx.INFO, "onSuccess.redirect.uriPatttern is not set.So is not permitted redirecting.")
    errorExit(jwtconfig, "Request includes redirect_uri patameter, but not permitted.", "redirect_not_permitted")
    return
  end

  local requested_redirect_uri = ngx.unescape_uri(req_args.redirect_uri)
  ngx.log(ngx.INFO, "redirect_uri sent is " .. requested_redirect_uri)
  ngx.log(ngx.INFO, "redirect_uri will be checked with " .. ckeckUriPattern)

  if lrex.count(requested_redirect_uri, ckeckUriPattern) == 0 then
    ngx.log(ngx.INFO, "Does not match redirect_uri parameter against uriPattern.")
    errorExit(jwtconfig, "redirect_uri patameter is unmatch.", "redirect_uri_unmatch")
    return
  end

  ngx.log(ngx.INFO, "redirect_uri may be safe, so will be redirecting when JWT is valid.")
end

local payload, err
if ngx.ctx.verifiedClaim then
  ngx.log(ngx.INFO, "Update JWT for " .. ngx.ctx.verifiedClaim.sub)
  payload, err = updatePayload(jwtconfig, ngx.ctx.verifiedClaim)
else
  payload, err = genPayload(jwtconfig)
end

-- Generate JWT
local token
if not err then
  local alg = jwtconfig.encode.alg
  local key = jwtconfig.encode.key
  ngx.log(ngx.INFO, "Generate payload successfully. ==> " .. table_dump(payload))
  token, err = jwt.encode(payload, key, alg)
end

if not token then
  -- Failed to generate JWT.
  ngx.log(ngx.ERR, "Failed to generate token : " .. err)
  errorExit(jwtconfig, err, "invalid_request")
  return
end

ngx.log(ngx.INFO, "JWT generated successfully FOR : " .. payload.sub .. " TOKEN: " .. token)

-- Check and do Set-Cookie or do nothing.
local onSuccess = jwtconfig.onSuccess
if (onSuccess.set_cookie and onSuccess.set_cookie.name and #onSuccess.set_cookie.name > 0) then
  ngx.log(ngx.INFO, "Add Set-Cookie header as " .. onSuccess.set_cookie.name)
  local val = onSuccess.set_cookie.name .. "=" .. token
  if (onSuccess.set_cookie.expSec and #onSuccess.set_cookie.expSec > 0) then
    if not tonumber(onSuccess.set_cookie.expSec) then
      ngx.log(ngx.WARN, "Skip setting Max-Age to Set-Cookie, because value is not number. " ..  onSuccess.set_cookie.expSec)
    else
      val = val .. "; Max-Age=" .. onSuccess.set_cookie.expSec
    end
  end
  if (onSuccess.set_cookie.opts and #onSuccess.set_cookie.opts > 0) then
    val = val .. "; " .. onSuccess.set_cookie.opts
  end

  ngx.header["Set-Cookie"] = val
end

-- Decide Rediret or content
-- 1st, check if request parameter inlcudes redirect_uri.
-- 2nd, check if configuration includes onSuccess.redirect.uri parameter.
local redirect_location
if (req_args.redirect_uri and #req_args.redirect_uri > 0) then
  redirect_location = req_args.redirect_uri
elseif (onSuccess.redirect and onSuccess.redirect.uri and #onSuccess.redirect.uri > 0) then
  redirect_location = onSuccess.redirect.uri
end

-- IF set redirect_uri, return redirect to client.
if redirect_location and #redirect_location > 0 then
  ngx.log(ngx.INFO, "Response as redirect to " .. redirect_location .. "")
  local token_param
  if (onSuccess.redirect.param_name and #onSuccess.redirect.param_name > 0) then
    token_param = onSuccess.redirect.param_name .. "=" .. token
  else
    token_param = "access_token=" .. token
  end
  
  local s, e = string.find(redirect_location, "?", 1, true)
  if s and not string.ends(redirect_location, "&") then
      redirect_location = redirect_location .. "&"
  else
    -- No query exists.
    redirect_location = redirect_location .. "?"
  end
  redirect_location = redirect_location .. token_param
  ngx.log(ngx.INFO, "Actually, Redirect location is " .. redirect_location .. "")
  return ngx.redirect(redirect_location, ngx.HTTP_MOVED_TEMPORARILY)
  -- ngx.header["Location"] = redirect_location
  -- ngx.status = ngx.HTTP_MOVED_TEMPORARILY
else
  ngx.log(ngx.INFO, "Response as content as status " .. ngx.status .. "")
  if onSuccess.content then
    if (onSuccess.content.code and #onSuccess.content.code > 0) then
      ngx.status = onSuccess.content.code
    else
      ngx.status = ngx.HTTP_OK
    end
    local res_html = ngx.location.capture("/jwt.settings/" .. onSuccess.content.template)
    local tplfunc = template.compile(res_html.body)
    local contenttype = wgu.decideContentType(onSuccess.content.template)
    ngx.header["Content-Type"] = contenttype
    ngx.say(tplfunc{ token = token })
  else
    ngx.log(ngx.WARN, "Configuration of onSuccess.content is not found. Cannot send content to client because of mis-configuration.")
  end
end

ngx.exit(ngx.OK)
