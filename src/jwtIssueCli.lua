#!/usr/bin/lua

local jwt = require "luajwt"
local cjson = require "cjson"

local JWT_ENC_ALGORITHM = "HS256"

local mode_quiet = false

local debugInfo = debug.getinfo(1)
local fileName = debugInfo.source:match("[^/]*$")

-- Ref from: http://lua-users.org/wiki/AlternativeGetOpt
--
-- getopt, POSIX style command line argument parser
-- param arg contains the command line arguments in a standard table.
-- param options is a string with the letters that expect string values.
-- returns a table where associated keys are true, nil, or a string value.
-- The following example styles are supported
--   -a one  ==> opts["a"]=="one"
--   -bone   ==> opts["b"]=="one"
--   -c      ==> opts["c"]==true
--   --c=one ==> opts["c"]=="one"
--   -cdaone ==> opts["c"]==true opts["d"]==true opts["a"]=="one"
-- note POSIX demands the parser ends at the first non option
--      this behavior isn't implemented.

function getopt( arg, options )
  local tab = {}
  for k, v in ipairs(arg) do
    if string.sub( v, 1, 2) == "--" then
      local x = string.find( v, "=", 1, true )
      if x then tab[ string.sub( v, 3, x-1 ) ] = string.sub( v, x+1 )
      else      tab[ string.sub( v, 3 ) ] = true
      end
    elseif string.sub( v, 1, 1 ) == "-" then
      local y = 2
      local l = string.len(v)
      local jopt
      while ( y <= l ) do
        jopt = string.sub( v, y, y )
        if string.find( options, jopt, 1, true ) then
          if y < l then
            tab[ jopt ] = string.sub( v, y+1 )
            y = l
          else
            tab[ jopt ] = arg[ k + 1 ]
          end
        else
          tab[ jopt ] = true
        end
        y = y + 1
      end
    end
  end
  return tab
end

function usage()
  print("usage: " .. fileName .. " -s <subjectValue> -e <expiration seconds> -k <key for encoding> -a <ext/add props>")
  print([[
  -s
    REQUIRED.
    Subject value. userID, mail-address expected.

  -e
    REQUIRED.
    Expiration for JWT as seconds.

  -k
    REQUIRED.
    Key (Secret) value for encoding JWT.

  -a
    Extension/Additional property for including JWT.

  -q
    Quiet mode. 
]])
end

function genPayload(subject, expSec, addprops)
  local dtnow = os.time()
  local payload = {
    sub = subject,
    nbf = dtnow,
    nbf = dtnow,
    iat = dtnow,
    exp = dtnow + expSec,
  }

  if addprops then
    for k,v in pairs(addprops) do
      payload[k] = v
    end
  end
  return payload, err
end

function errorExit(message)
  print(message)
  os.exit(1)
end

function out_info(message)
  if not mode_quiet then
    print(message)
  end
end

function main()
  local opts = getopt(arg, "aeks")

  local targetVal = opts.s
  local expSecStr = opts.e
  local secret = opts.k
  local addprops = opts.a

  if not targetVal or not expSecStr or not secret then
    print("Missing required parameters")
    usage()
    return
  end

  local addpropsobj
  if addprops and #addprops > 0 then
    local flag, ret = pcall(cjson.decode, addprops)
    if not flag then
      out_info("Invalid format .... " .. addprops)
      errorExit("Invalid format, Extension/Additional property using -a : " .. ret)
    end
    addpropsobj = ret
  end

  mode_quiet = opts.q

  local expSec = tonumber(expSecStr)
  if not expSec then
    errorExit("Value of expiration-seconds must be numeric, but not. " .. expSecStr)
  end

  -- Generate JWT
  local payload = genPayload(targetVal, expSec, addpropsobj)
  out_info("Generated payload is ==> " .. cjson.encode(payload))
  token, err = jwt.encode(payload, secret, JWT_ENC_ALGORITHM)
  if not token then
    -- Failed to generate JWT.
    errorExit("Failed to generate token : " .. err)
  end

  out_info("JWT issued successfully.")
  print(token)
end

main()

