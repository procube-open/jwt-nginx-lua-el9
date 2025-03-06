local base64 = require 'base64'

if ngx.var.nswg_jwt_sub then
  ngx.req.set_header("Authorization", "Basic " .. base64.encode(ngx.var.nswg_jwt_sub .. ":dummypassword"))
end
