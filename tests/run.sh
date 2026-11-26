#!/bin/bash
set -euo pipefail

dnf -y install epel-release
dnf -y install curl-minimal tar gzip
curl -fsSL -o /tmp/nginx-rpms.tar.gz \
    https://github.com/procube-open/nginx-shib-rpm-el9/releases/download/2.0.0/nginx-shib-rpm-el9.tar.gz
tar xzf /tmp/nginx-rpms.tar.gz -C /tmp
if [ "${TEST_UPGRADE:-0}" = 1 ]; then
    mkdir -p /tmp/old-jwt /tmp/old-lua
    curl -fsSL https://github.com/procube-open/jwt-nginx-lua-el9/releases/download/1.0.0/jwt-nginx-lua-el9.tar.gz \
        | tar xz -C /tmp/old-jwt
    curl -fsSL https://github.com/procube-open/lua51-el9/releases/download/1.0.0/lua51-el9.tar.gz \
        | tar xz -C /tmp/old-lua
    dnf -y install /tmp/old-lua/RPMS/x86_64/lua-5.1.4-15.el9.x86_64.rpm \
        /tmp/old-jwt/RPMS/x86_64/*.rpm /tmp/old-jwt/RPMS/noarch/*.rpm
fi
dnf -y install /tmp/RPMS/x86_64/nginx-1.30.7-1.el9.ngx.procube.x86_64.rpm \
    /rpms/x86_64/*.rpm /rpms/noarch/*.rpm

rpm -q --requires jwt-nginx-lua | grep -Fx 'luajwt >= 1.3.0-5'
rpm -q --requires luajwt | grep -Fx 'lua-crypto >= 0.3.2-3'
for package in jwt-nginx-lua luajwt lua-base64 lua-cjson lua-crypto \
    lua-htmlparser lua-resty-string lua-resty-template lua-zlib lrexlib-pcre; do
    if rpm -q --requires "$package" | grep -Eq '^lua( |$)|^luaffi|^liblua'; then
        echo "$package unexpectedly depends on a separate Lua runtime" >&2
        exit 1
    fi
done

/usr/sbin/nginx -t -c /tests/nginx.conf
/usr/sbin/nginx -c /tests/nginx.conf -g 'daemon off;' &
nginx_pid=$!
trap 'kill "$nginx_pid"; wait "$nginx_pid" || true' EXIT
for attempt in {1..30}; do
    if curl --silent --fail http://127.0.0.1:18080/test -o /tmp/jwt-test-result; then
        grep -qx ok /tmp/jwt-test-result
        break
    fi
    if [ "$attempt" -eq 30 ]; then
        echo "nginx LuaJIT smoke test failed" >&2
        exit 1
    fi
    sleep 1
done

curl --silent --fail -H 'X-Test-User: alice' -D /tmp/jwt-headers \
    http://127.0.0.1:18080/issue -o /tmp/jwt-issue-result
token=$(sed -n 's/^Set-Cookie: access_token=\([^;]*\).*/\1/ip' /tmp/jwt-headers | tr -d '\r')
test -n "$token"
grep -Fq "$token" /tmp/jwt-issue-result
curl --silent --fail -H "Authorization: Bearer $token" \
    http://127.0.0.1:18080/verify -o /tmp/jwt-verify-result
grep -qx alice /tmp/jwt-verify-result
curl --silent --fail -H "Cookie: access_token=$token" \
    http://127.0.0.1:18080/verify -o /tmp/jwt-verify-result
grep -qx alice /tmp/jwt-verify-result
curl --silent --fail "http://127.0.0.1:18080/verify?access_token=$token" \
    -o /tmp/jwt-verify-result
grep -qx alice /tmp/jwt-verify-result
status=$(curl --silent -o /dev/null -w '%{http_code}' \
    -H "Authorization: Bearer ${token}x" http://127.0.0.1:18080/verify)
test "$status" = 401
status=$(curl --silent -o /dev/null -w '%{http_code}' http://127.0.0.1:18080/verify)
test "$status" = 401
