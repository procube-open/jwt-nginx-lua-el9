assert(jit and jit.version:match("LuaJIT 2"))
assert(require("ffi").abi("64bit"))

local json = require "cjson"
assert(json.decode(json.encode({value = 42})).value == 42)
assert(require("cjson.safe").decode('{"ok":true}').ok)
assert(require("cjson.util"))

local base64 = require "base64"
assert(base64.decode(base64.encode("lua\0jit")) == "lua\0jit")
local jwt = require "luajwt"
local token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJhbGljZSJ9.c3brGQkxoiCgrl5LGiV0go9qgN0MtrdnDBCCfJ45f_Q"
assert(jwt.decode(token, "secret").sub == "alice")
local invalid, err = jwt.decode(token, "wrong secret")
assert(invalid == nil and err == "Invalid signature")
for _, alg in ipairs({"HS256", "HS384", "HS512"}) do
    local encoded = assert(jwt.encode({sub = "alice"}, "secret", alg))
    assert(jwt.decode(encoded, "secret").sub == "alice")
end

local rex = require "rex_pcre"
assert(rex.match("hello 123", [[\d+]]) == "123")
local zlib = require "zlib"
local compressed = zlib.deflate()("hello", "finish")
assert(zlib.inflate()(compressed) == "hello")
assert(require("htmlparser").parse("<p>hello</p>"))
assert(require("resty.template").process("hello {{name}}", {name = "LuaJIT"}, nil, true) == "hello LuaJIT")
local md5 = require("resty.md5").new()
assert(md5:update("hello"))
assert(require("resty.string").to_hex(md5:final()) == "5d41402abc4b2a76b9719d911017c592")
assert(require "webgate/jwt-util")

ngx.say("ok")
