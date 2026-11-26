Name: lua-htmlparser
Version: 0.3.2
Release: 3%{?dist}
Summary: Parse HTML text into a tree of elements with selectors
License: GNU Lesser General Public License (LGPL)
URL: https://github.com/msva/lua-htmlparser

BuildArch: noarch
Requires: /bin/sh

%description
Parse HTML text into a tree of elements with selectors

%prep
#%setup -q -n lua-htmlparser

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT/opt/procube-nginx-luajit/share/lua/5.1/
cp -R $RPM_SOURCE_DIR/%{name}/src/htmlparser* $RPM_BUILD_ROOT/opt/procube-nginx-luajit/share/lua/5.1/

%files
%defattr(644,root,root,755)
/opt/procube-nginx-luajit/share/lua/5.1/*

