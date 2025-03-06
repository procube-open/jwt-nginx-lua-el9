%define luaver 5.1
%define lualibdir %{_libdir}/lua/%{luaver}
%define luadatadir %{_datadir}/lua/%{luaver}
%define debug_package %{nil}

Name:		lua-base64

%define short_name lbase64
Version:	5.1
Release:	1%{?dist}
Summary:	base64 library for Lua

Group:		Development/Libraries
License:	MIT
URL:		http://webserver2.tecgraf.puc-rio.br/~lhf/ftp/lua/
Source0:	http://webserver2.tecgraf.puc-rio.br/~lhf/ftp/lua/%{version}/%{short_name}.tar.gz
BuildRoot:	%(mktemp -ud %{_tmppath}/%{short_name}-%{version}-%{release}-XXXXXX)

BuildRequires:	lua >= %{luaver}, lua-devel >= %{luaver}, gcc
Requires:	lua >= %{luaver}

%description
This is a base64 library for Lua 5.1. For information on base64 see
        http://en.wikipedia.org/wiki/Base64

There is no manual but the library is simple and intuitive; see the summary
below. Read also test.lua, which shows the library in action.

This code is hereby placed in the public domain.
Please send comments, suggestions, and bug reports to lhf@tecgraf.puc-rio.br .


%prep
%setup -q -n base64


%build
make %{?_smp_mflags} CFLAGS="%{optflags} -fPIC" LUABIN=/bin/


%install
rm -rf "$RPM_BUILD_ROOT"
mkdir -p $RPM_BUILD_ROOT%{lualibdir}
install $RPM_BUILD_DIR/base64/base64.so $RPM_BUILD_ROOT%{lualibdir}/


%clean
rm -rf "$RPM_BUILD_ROOT"


%preun


%files
%defattr(-,root,root,-)
#%doc README
%{lualibdir}/*


