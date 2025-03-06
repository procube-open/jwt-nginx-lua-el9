%define luaver 5.1
%define lualibdir %{_libdir}/lua/%{luaver}
%define luadatadir %{_datadir}/lua/%{luaver}
%define debug_package %{nil}

Name:		luajwt

Version:	1.3.0
Release:	4%{?dist}
Summary:	JSON Web Tokens for Lua

Group:		Development/Libraries
License:	MIT
URL:		https://github.com/x25/luajwt
Source0:	https://github.com/x25/luajwt/archive/master.zip
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

#BuildRequires:	lua >= %{luaver}, lua-devel >= %{luaver}, gcc
Requires:	lua >= %{luaver}, lua-crypto >= 0.3.0, lua-cjson >= 2.1.0, lua-base64

%description
JSON Web Tokens for Lua
Supported algorithms are HMAC
 - HS256 - HMAC using SHA-256 hash algorithm (default)
 - HS384 - HMAC using SHA-384 hash algorithm
 - HS512 - HMAC using SHA-512 hash algorithm


%prep


%build


%install
rm -rf "$RPM_BUILD_ROOT"
mkdir -p $RPM_BUILD_ROOT%{luadatadir}
install $RPM_SOURCE_DIR/luajwt/luajwt.lua $RPM_BUILD_ROOT%{luadatadir}/


%clean
rm -rf "$RPM_BUILD_ROOT"


%preun


%files
%defattr(-,root,root,-)
#%doc README
%{luadatadir}/*


