%define luaver 5.1
%define lualibdir %{_libdir}/lua/%{luaver}
%define luadatadir %{_datadir}/lua/%{luaver}
%define debug_package %{nil}
%define  work_dir luazlib_work
%define short_name luazlib

Name:		lua-zlib
Version:	1.2
Release:	1%{?dist}
Summary:	Simple streaming interface to zlib for Lua
Group:		Development/Libraries
License:	MIT
URL:		https://github.com/brimworks/lua-zlib
Source0:	https://github.com/brimworks/lua-zlib/archive/master.zip
BuildRoot:	%(mktemp -ud %{_tmppath}/%{short_name}-%{version}-%{release}-XXXXXX)

#BuildRequires:	lua >= %{luaver}, lua-devel >= %{luaver}, gcc
Requires:	lua >= %{luaver}

%description
Simple streaming interface to zlib for Lua.
Consists of two functions: inflate and deflate.

%build
luarocks --local install lua-zlib --tree %{work_dir}


%install
rm -rf "$RPM_BUILD_ROOT"
mkdir -p $RPM_BUILD_ROOT%{lualibdir}
install -m 755 $RPM_BUILD_DIR/%{work_dir}/lib64/lua/5.1/zlib.so $RPM_BUILD_ROOT%{lualibdir}/


%clean
rm -rf "$RPM_BUILD_ROOT"


%preun


%files
%defattr(-,root,root,-)
#%doc README
%{lualibdir}/*


%changelog
