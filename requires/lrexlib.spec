%define luaver 5.1
%define lualibdir %{_libdir}/lua/%{luaver}
%define luadatadir %{_datadir}/lua/%{luaver}
%define debug_package %{nil}
%define _builddir %{_topdir}/BUILD/lrexlib

Name:		lrexlib-pcre

Version:	2.8.0
Release:	1%{?dist}
Summary:	Binding of PCRE regular expression library APIs.

Group:		Development/Libraries
License:	MIT/X
URL:		http://luaforge.net/projects/lrexlib/
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

Requires:	lua >= %{luaver}

%define  work_dir lrexlib_work

%description
lrexlib-pcre is binding of PCRE regular expression library APIs.


%prep
#%setup -q -n %{master_name}


%build
luarocks install lrexlib-PCRE %{version} --tree %{work_dir}


%install
rm -rf "$RPM_BUILD_ROOT"
mkdir -p $RPM_BUILD_ROOT%{lualibdir}
install -m 755 $RPM_BUILD_DIR/%{work_dir}/lib64/lua/5.1/*.so $RPM_BUILD_ROOT%{lualibdir}/


%clean
rm -rf "$RPM_BUILD_ROOT"


%preun


%files
%defattr(-,root,root,-)
#%doc README
%{lualibdir}/*

