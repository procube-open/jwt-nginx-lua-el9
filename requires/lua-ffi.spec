%define luaver 5.1
%define lualibdir %{_libdir}/lua/%{luaver}
%define luadatadir %{_datadir}/lua/%{luaver}
%define debug_package %{nil}
%define _builddir %{_topdir}/BUILD/luaffi

Name:		luaffi

Version:	scm_1
Release:	1%{?dist}
Summary:	FFI library for calling C functions from lua

Group:		Development/Libraries
License:	BSD
URL:		https://github.com/facebook/luaffifb
Source0:	https://github.com/facebook/luaffifb/archive/luaffifb-master.zip
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

Requires:	lua >= %{luaver}

%description
This library is designed to be source compatible with LuaJIT's FFI extension.
The documentation at http://luajit.org/ext_ffi.html describes the API and semantics.


%prep
#%setup -q -n %{master_name}

%build
luarocks make --local


%install
rm -rf "$RPM_BUILD_ROOT"
mkdir -p $RPM_BUILD_ROOT%{lualibdir}
install -m 755 $RPM_BUILD_DIR/ffi.so $RPM_BUILD_ROOT%{lualibdir}/
mkdir -p $RPM_BUILD_ROOT%{lualibdir}/ffi
install -m 755 $RPM_BUILD_DIR//ffi/*.so $RPM_BUILD_ROOT%{lualibdir}/ffi/


%clean
rm -rf "$RPM_BUILD_ROOT"


%preun


%files
%defattr(-,root,root,-)
#%doc README
%{lualibdir}/*

