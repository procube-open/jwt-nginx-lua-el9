%define luaver 5.1
%define lualibdir %{_libdir}/lua/%{luaver}
%define luadatadir /opt/procube-nginx-luajit/share/lua/%{luaver}
%define luanginxdir %{_sysconfdir}/nginx/lua
%define jwtconfdir %{_sysconfdir}/nginx/jwt.settings
%define luanginxconfdir %{_sysconfdir}/nginx/conf.d
%define libdistname webgate
%define debug_package %{nil}

Name:		jwt-nginx-lua

Version:	0.0.2
Release:	2%{?dist}
Summary:	Templating Engine (HTML) for Lua and OpenResty

Group:		Development/Libraries
License:	BSD
URL:		https://github.com/procube-open/jwt-nginx-lua
Source0:	https://github.com/procube-open/jwt-nginx-lua/archive/jwt-nginx-lua-master.zip
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
BuildArch:	noarch

Requires:	nginx >= 1.30.7
Requires:	lua-cjson >= 2.1.0-2
Requires:	lua-htmlparser >= 0.3.2-3
Requires:	luajwt >= 1.3.0-5
Requires:	lua-resty-template >= 1.9-2
Requires:	lua-resty-string >= 0.09-2
Requires:	lua-base64 >= 5.1-2
Requires:	lrexlib-pcre >= 2.8.0-2

%description
This library requires an nginx build with OpenSSL, the ngx_lua module, and LuaJIT 2.0.

This library requires an nginx build with OpenSSL,
the [ngx_lua module](http://wiki.nginx.org/HttpLuaModule), and [LuaJIT 2.0](http://luajit.org/luajit.html).

Or you can use openresty with some customization.

%prep
#%setup -q -n %{master_name}


%build


%install
rm -rf "$RPM_BUILD_ROOT"
mkdir -p $RPM_BUILD_ROOT%{luadatadir}/%{libdistname}
mkdir -p $RPM_BUILD_ROOT%{luanginxdir}
mkdir -p $RPM_BUILD_ROOT%{jwtconfdir}
mkdir -p $RPM_BUILD_ROOT%{luanginxconfdir}
install -m 644 $RPM_SOURCE_DIR/%{name}/src/*.lua $RPM_BUILD_ROOT%{luanginxdir}/
install -m 644 $RPM_SOURCE_DIR/%{name}/src-lib/*.lua $RPM_BUILD_ROOT%{luadatadir}/%{libdistname}/
install -m 644 $RPM_SOURCE_DIR/%{name}/conf/* $RPM_BUILD_ROOT%{jwtconfdir}/
install -m 644 $RPM_SOURCE_DIR/%{name}/nginx.server.conf.example $RPM_BUILD_ROOT%{luanginxconfdir}/


%clean
rm -rf "$RPM_BUILD_ROOT"


%preun


%files
%defattr(-,root,root,-)
#%doc README
%{luanginxdir}/*
%{luadatadir}/*
%{jwtconfdir}/*
%{luanginxconfdir}/*

