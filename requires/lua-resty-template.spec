%define luaver 5.1
%define lualibdir %{_libdir}/lua/%{luaver}
%define luadatadir %{_datadir}/lua/%{luaver}
%define debug_package %{nil}

Name:		lua-resty-template

Version:	1.9
Release:	1%{?dist}
Summary:	Templating Engine (HTML) for Lua and OpenResty

Group:		Development/Libraries
License:	3BSD
URL:		https://github.com/bungle/lua-resty-template
Source0:	https://github.com/bungle/lua-resty-template/archive/lua-resty-template-master.zip
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

Requires:	lua >= %{luaver}

%description
lua-resty-template is a compiling (1) (HTML) templating engine for Lua and OpenResty.

(1) with compilation we mean that templates are translated to Lua functions that
you may call or string.dump as a binary bytecode blobs to disk that can be later utilized
with lua-resty-template or basic load and loadfile standard Lua functions
(see also Template Precompilation). 
Although, generally you don't need to do that as lua-resty-template handles
this behind the scenes.


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

%changelog
* Thu Sep 29 2016 - 1.9
- Added Support for the official OpenResty package manager (opm).

- Changed the change log format to keep-a-changelog.

* Tue Jun 14 2016 - 1.8
- Added Allow pass layout as a template object to template.new.

* Wed May 11 2016 - 1.7
- Fixed The loadngx was not working properly on non-file input.
  See also: https://github.com/bungle/lua-resty-template/pull/19
  Thanks @zhoukk

* Mon Apr 25 2016 - 1.6
- Added short escaping syntax.

* Tue Feb 10 2015 - 1.5
- Added Support for {-verbatim-}...{-verbatim-}, and {-raw-}...{-raw-} blocks
  (contents is not processed by template).
  Please note that this could break your templates if you have used
  blocks with names "verbatim" or "raw".
- FixedIssue #8: not returning value when using template.new and its render
  function.

* Wed Dec 3 2014 - 1.4
- Added support for {[expression include]} syntax.
- Changed Rewrote template.parse (cleaned up, less repetition of code, and
  better handling of new lines - i.e. doesn't eat newlines anymore.
  Also some adjustments to preceding spaces (space, tab, NUL-byte,
  and vertical tabs) on some tags ({% ... %}, {-block-} ... {-block-},
  and {# ... #}) for a cleaner output.

* Thu Nov 6 2014 - 1.3
- Added Small modification to html helper example to handle valueless tag
  attributess in HTML5 style.
- Fixed a bug when a view was missing from context when using layouts.

* Mon Sep 29 2014 - 1.2
- Fixes nasty recursion bug (reported in bug #5) where sub-templates
  modify the context table. Thank you for reporting this @DDarko.
  
* Wed Sep 10 2014 - 1.1
- Added _VERSION information to the module.
- Added CHANGES file to the project (this file).
- Changed Lua > 5.1 uses _ENV instead of _G (Lua 5.1 uses _G). Future Proofing
  if Lua is deprecating _G in Lua 5.3.

* Thu Aug 28 2014 - 1.0
- Added LuaRocks Support via MoonRocks.

