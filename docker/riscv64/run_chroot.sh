#!/bin/bash

cd /workdir/crosschroot
cp /workdir/sources.list ./
chroot /workdir/crosschroot/ bash<<EOF
set -e
touch /etc/apt/apt.conf.d/99verify-peer.conf \
&& echo >>/etc/apt/apt.conf.d/99verify-peer.conf "Acquire { https::Verify-Peer false }"
apt-get update
apt-get install -y ca-certificates 
apt-get install -y gnupg
cp /sources.list /etc/apt/sources.list 
apt-get update
apt-get install -y ca-certificates
rm -f /etc/apt/apt.conf.d/99verify-peer.conf
apt-get install wget debconf devscripts vim software-properties-common -y --allow-unauthenticated
apt-get install libpcap-dev libncurses-dev pax netbase doxygen bzip2 libbz2-dev  libssl-dev -y
apt-get install libopenthreads-dev gdb less wget pkg-config -y
apt-get install libffi-dev libunistring-dev libltdl-dev libgmp-dev libgc-dev -y
apt-get install ninja-build python3-pip -y
apt-get install parallel -y
cd /root
git clone https://github.com/brandt/symlinks.git
cd symlinks
make
./symlinks -c -r -v /
EOF
