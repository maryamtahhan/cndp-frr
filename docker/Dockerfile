# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2020-2022 Intel Corporation.

FROM quay.io/mtahhan/cndp-fedora-dev

# Setup container to build CNDP applications
RUN dnf -y upgrade && dnf -y install git autoconf automake libtool make \
  readline-devel texinfo net-snmp-devel groff pkgconfig json-c-devel \
  pam-devel python3-pytest bison flex c-ares-devel python3-devel \
  python3-sphinx perl-core patch libcap-devel \
  elfutils-libelf-devel libunwind-devel cmake pcre2-devel \
  elfutils-libelf-devel libpcap-devel perf \
  clang llvm bpftool tcpdump

# Build and install libyang from source
WORKDIR /
RUN git clone https://github.com/CESNET/libyang.git
WORKDIR /libyang
RUN git checkout v2.0.0
RUN mkdir build;
WORKDIR /libyang/build
RUN cmake -D CMAKE_INSTALL_PREFIX:PATH=/usr -D CMAKE_BUILD_TYPE:String="Release" ..
RUN make -j
RUN make -j install

RUN groupadd -g 92 frr
RUN groupadd -r -g 85 frrvty
RUN useradd -u 292 -g 92 -M -r -G frrvty -s /sbin/nologin -c "FRR FRRouting suite" -d /var/run/frr frr

WORKDIR /

RUN git clone https://github.com/frrouting/frr.git frr
WORKDIR /frr
RUN ./bootstrap.sh
RUN ./configure \
    --prefix=/usr \
    --includedir=\${prefix}/include \
    --bindir=\${prefix}/bin \
    --sbindir=\${prefix}/lib/frr \
    --libdir=\${prefix}/lib/frr \
    --libexecdir=\${prefix}/lib/frr \
    --localstatedir=/var/run/frr \
    --sysconfdir=/etc/frr \
    --with-moduledir=\${prefix}/lib/frr/modules \
    --with-libyang-pluginsdir=\${prefix}/lib/frr/libyang_plugins \
    --enable-configfile-mask=0640 \
    --enable-logfile-mask=0640 \
    --enable-snmp=agentx \
    --enable-multipath=64 \
    --enable-user=frr \
    --enable-group=frr \
    --enable-vty-group=frrvty \
    --with-pkg-git-version \
    --with-pkg-extra-version=-MyOwnFRRVersion
RUN make -j
RUN make -j install

RUN install -m 775 -o frr -g frr -d /var/log/frr
RUN install -m 775 -o frr -g frrvty -d /etc/frr
RUN install -m 640 -o frr -g frrvty tools/etc/frr/vtysh.conf /etc/frr/vtysh.conf
RUN install -m 640 -o frr -g frr tools/etc/frr/frr.conf /etc/frr/frr.conf
RUN install -m 640 -o frr -g frr tools/etc/frr/daemons.conf /etc/frr/daemons.conf
RUN install -m 640 -o frr -g frr tools/etc/frr/daemons /etc/frr/daemons

COPY docker/logging.sh /
COPY docker/startup.sh /
RUN install -p -m 644 tools/frr.service /usr/lib/systemd/system/frr.service
COPY docker/90-routing-sysctl.conf /etc/sysctl.d/90-routing-sysctl.conf

WORKDIR /
COPY my-filter-udp-to-xdp /my-filter-udp-to-xdp
WORKDIR /my-filter-udp-to-xdp
RUN make -j

WORKDIR /cndp
RUN git pull
RUN git checkout fede861421e1790427f4b3ce4100ddb079e210d5
COPY docker/0001-load-custom-bpf-program-shouldn-t-do-on-a-per-port-b.patch /cndp
RUN git apply 0001-load-custom-bpf-program-shouldn-t-do-on-a-per-port-b.patch
RUN make clean
RUN make -j
COPY docker/cnetfwd-graph.jsonc /cndp/builddir/examples/cnet-graph
WORKDIR /cndp/builddir/examples/cnet-graph
RUN cp /my-filter-udp-to-xdp/my_xdp_prog_kern.o .
WORKDIR /
