%define luaver 5.1
%define lualibdir %{_libdir}/lua/%{luaver}
%define luadatadir %{_datadir}/lua/%{luaver}
%define debug_package %{nil}

Name:		lua-resty-string

Version:	0.09
Release:	1%{?dist}
Summary:	Templating Engine (HTML) for Lua and OpenResty

Group:		Development/Libraries
License:	BSD
URL:		https://github.com/bungle/lua-resty-string
Source0:	https://github.com/bungle/lua-resty-string/archive/lua-resty-string-master.zip
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

Requires:	lua >= %{luaver}, luaffi

%description
This library requires an nginx build with OpenSSL, the ngx_lua module, and LuaJIT 2.0.

This library requires an nginx build with OpenSSL,
the [ngx_lua module](http://wiki.nginx.org/HttpLuaModule), and [LuaJIT 2.0](http://luajit.org/luajit.html).


%prep
#%setup -q -n %{master_name}


%build


%install
rm -rf "$RPM_BUILD_ROOT"
mkdir -p $RPM_BUILD_ROOT%{luadatadir}
cp -R $RPM_SOURCE_DIR/%{name}/lib/resty/ $RPM_BUILD_ROOT%{luadatadir}/


%clean
rm -rf "$RPM_BUILD_ROOT"


%preun


%files
%defattr(-,root,root,-)
#%doc README
%{luadatadir}/*

