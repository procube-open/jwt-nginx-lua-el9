%define luaver 5.1
%define lualibdir %{_libdir}/lua/%{luaver}
%define luadatadir %{_datadir}/lua/%{luaver}
%define debug_package %{nil}
%define _builddir %{_topdir}/BUILD/lua-crypto
%define  work_dir lcrypto_work

Name:		lua-crypto

Version:	0.3.2
Release:	2%{?dist}
Summary:	Crypto library for Lua

Group:		Development/Libraries
License:	MIT
#URL:		http://luacrypto.luaforge.net/
URL:		https://luarocks.org/modules/Ehekatl/luacrypto2/0.3.2-1
Source0:	https://github.com/starius/luacrypto/%{name}-master.zip
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

Patch: lcrypto.config.patch

BuildRequires:	lua >= %{luaver}, lua-devel >= %{luaver}, gcc
Requires:	lua >= %{luaver}

%description
LuaCrypto provides a Lua frontend to the OpenSSL cryptographic library.
The OpenSSL features that are currently exposed are digests
 (MD5, SHA-1, HMAC, and more) and crypto-grade random number generators.



%build
#./configure 
#make 
#luarocks --local install luacrypto2 --tree %{work_dir}
luarocks unpack luacrypto2
cd luacrypto2-0.3.2-1/luacrypto
sed -i -e 's/SHLIB_VERSION_NUMBER/OPENSSL_SHLIB_VERSION/g' src/lcrypto.c
luarocks make --local --tree %{work_dir}


%install
rm -rf "$RPM_BUILD_ROOT"
mkdir -p $RPM_BUILD_ROOT%{lualibdir}
#install $RPM_BUILD_DIR/src/.libs/crypto.so $RPM_BUILD_ROOT%{lualibdir}/
install -m 755 $RPM_BUILD_DIR/luacrypto2-0.3.2-1/luacrypto/%{work_dir}/lib64/lua/5.1/*.so $RPM_BUILD_ROOT%{lualibdir}/


%clean
rm -rf "$RPM_BUILD_ROOT"


%preun


%files
%defattr(-,root,root,-)
#%doc README
%{lualibdir}/*


%changelog
* Thu Apr 25 2013 starius 0.3.2
    Updated for Lua 5.2

* Tue Mar 6 2012 starius 0.3.1
    Added a compile-time option to initialize OpenSSL outside of LuaCrypto

* Thu Mar 1 2012 starius 0.3.0
    Added encryption, decryption, signing, verifying, sealing and opening functionality.

* Thu Aug 24 2006 nezroy 0.2.0
- README, doc/us/index.html: adding README and historical doc links
- Makefile, config, doc/luacrypto.html, doc/us/examples.html,
  doc/us/index.html, doc/us/license.html, doc/us/luacrypto-128.png,
  doc/us/manual.html, src/lcrypto.c, tests/rand.lua,
  tests/test.lua: adding new documentation and tweaking build

  Added random support.
  Removed Lua stub files and collapsed modules.
  Changed all supporting materials (documentation, build, etc.) to Kepler standards.

* Tue Aug 22 2006 nezroy
- Makefile, config, src/crypto.c, src/crypto.h, src/crypto.lua,
  src/evp.c, src/evp.h, src/evp.lua, src/hmac.c, src/hmac.h,
  src/hmac.lua, src/lcrypto.c, src/lcrypto.h, tests/test.lua:
  adding rand support and collapsing into a kepler-ized format

* Mon Aug 21 2006 nezroy
- LICENSE, README: cleaning out files

* Sun Jan 22 2006 xxxx 0.1.1
  Added Lua 5.0/Compat-5.1 support.

* Fri Jan 13 2006 xxxx 0.1.0
  Initial release.
