FROM almalinux/9-base
MAINTAINER "Shigeki Kitamura" <kitamura@procube.jp>
RUN groupadd -g 111 builder
RUN useradd -g builder -u 111 builder
ENV HOME /home/builder
WORKDIR ${HOME}
RUN dnf -y update \
    && dnf -y install epel-release \
    && dnf -y install unzip wget sudo git rpm-build gcc make openssl-devel pcre-devel zlib-devel
RUN mkdir -p /tmp/requires \
    && cd /tmp/requires/ \
    && wget --no-verbose -O /tmp/requires/lua.tar.gz https://github.com/procube-open/lua51-el9/releases/download/1.0.0/lua51-el9.tar.gz \
    && tar xvzf lua.tar.gz \
    && cd RPMS/x86_64/ \
    && rpm -ivh lua-5.1.4-15.el9.x86_64.rpm lua-devel-5.1.4-15.el9.x86_64.rpm luarocks-2.3.0-1.el9.x86_64.rpm
RUN mkdir -p /tmp/buffer
COPY requires/*.spec /tmp/buffer/
COPY jwt-nginx-lua.spec /tmp/buffer/
COPY requires/*.patch /tmp/buffer/
RUN mkdir -p /tmp/buffer/{src,src-lib,conf}
COPY src/*.lua /tmp/buffer/src/
COPY src-lib/*.lua /tmp/buffer/src-lib/
COPY nginx.server.conf.example /tmp/buffer/
COPY conf/* /tmp/buffer/conf/
USER builder
RUN mkdir -p ${HOME}/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
RUN echo "%_topdir %(echo ${HOME})/rpmbuild" > ${HOME}/.rpmmacros
RUN cp /tmp/buffer/*.spec ${HOME}/rpmbuild/SPECS/
RUN cp /tmp/buffer/*.patch ${HOME}/rpmbuild/SOURCES/
RUN git clone https://github.com/x25/luajwt.git rpmbuild/SOURCES/luajwt
RUN git clone https://github.com/mpx/lua-cjson.git rpmbuild/BUILD/lua-cjson
RUN git clone https://github.com/msva/lua-htmlparser.git rpmbuild/SOURCES/lua-htmlparser
RUN git clone https://github.com/bungle/lua-resty-template.git rpmbuild/SOURCES/lua-resty-template
RUN git clone https://github.com/bungle/lua-resty-string.git rpmbuild/SOURCES/lua-resty-string
RUN git clone https://github.com/starius/luacrypto.git rpmbuild/BUILD/lua-crypto
RUN git clone https://github.com/facebookarchive/luaffifb.git rpmbuild/BUILD/luaffi
RUN wget -O rpmbuild/SOURCES/lbase64.tar.gz http://webserver2.tecgraf.puc-rio.br/~lhf/ftp/lua/5.1/lbase64.tar.gz
RUN git clone https://github.com/rrthomas/lrexlib.git rpmbuild/BUILD/lrexlib
RUN cp rpmbuild/BUILD/lua-cjson/lua-cjson.spec rpmbuild/SPECS/
RUN cd rpmbuild/SPECS \
    && patch -p 1 lua-cjson.spec < ../SOURCES/lua-cjson.spec.patch

RUN mkdir -p ${HOME}/rpmbuild/SOURCES/jwt-nginx-lua
RUN cp -R /tmp/buffer/* ${HOME}/rpmbuild/SOURCES/jwt-nginx-lua/
CMD ["/usr/bin/rpmbuild","-bb","rpmbuild/SPECS/lua-ffi.spec", \
                               "rpmbuild/SPECS/lua-cjson.spec", \
                               "rpmbuild/SPECS/lua-htmlparser.spec", \
                               "rpmbuild/SPECS/lua-resty-template.spec", \
                               "rpmbuild/SPECS/lua-resty-string.spec", \
                               "rpmbuild/SPECS/lbase64.spec", \
                               "rpmbuild/SPECS/lcrypto.spec", \
                               "rpmbuild/SPECS/luajwt.spec", \
                               "rpmbuild/SPECS/lrexlib.spec", \
                               "rpmbuild/SPECS/luazlib.spec", \
                               "rpmbuild/SPECS/jwt-nginx-lua.spec"]

