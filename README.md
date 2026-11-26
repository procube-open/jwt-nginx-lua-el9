# jwt-nginx-lua-el9

EL9 向けの JWT nginx Lua モジュールと依存ライブラリの RPM ビルドです。
[nginx-shib-rpm-el9](https://github.com/procube-open/nginx-shib-rpm-el9)
2.0.0 以降の、OpenResty LuaJIT2 を同梱した nginx を対象とします。

```sh
docker build -t jwt-nginx-lua-el9 .
mkdir -p /tmp/RPMS
sudo -A chown 111:111 /tmp/RPMS
docker run --rm -v /tmp/RPMS:/home/builder/rpmbuild/RPMS jwt-nginx-lua-el9
docker run --rm -v /tmp/RPMS:/rpms:ro -v "$PWD/tests:/tests:ro" \
  almalinux/9-base bash /tests/run.sh
docker run --rm -e TEST_UPGRADE=1 -v /tmp/RPMS:/rpms:ro -v "$PWD/tests:/tests:ro" \
  almalinux/9-base bash /tests/run.sh
```

RPM は nginx と併せてインストールし、既存環境では依存 RPM も同時に
更新してください。Lua モジュールは nginx 同梱 LuaJIT の検索パス
`/opt/procube-nginx-luajit/{share,lib}/lua/5.1` に配置されます。
`5.1` は LuaJIT の互換 API のバージョンで、Lua 5.1 本体は不要です。
FFI は LuaJIT に組み込まれているため、旧 `luaffi` RPM は不要です。

nginx RPM は LuaJIT のコマンドを含みません。`jwtIssueCli.lua` を
コマンドラインで利用する場合は、別途 LuaJIT を用意し、上記のモジュール
ディレクトリを `LUA_PATH` と `LUA_CPATH` に追加して実行してください。
従来の Lua 5.1 用バイナリモジュールやバイトコードは使用せず、
LuaJIT 用に再ビルドしてください。

既存の Lua ソースおよび外部 C モジュールにはグローバル変数を設定するものが
あり、nginx の LuaJIT 実行時に警告が出る場合があります。また LuaCrypto は
OpenSSL 3 の非推奨 API を使用しています。
