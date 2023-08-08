#!/bin/bash

source ./version.sh

ncores=$(cat /proc/cpuinfo | grep processor | wc -l)
((ncores--))
rm -rf tmp_devarm/
mkdir -p tmp_devarm
sudo ln workdir/chroot-aarch64.tar.gz tmp_devarm/chroot-aarch64.tar.gz
cp aarch64/in_chroot.sh tmp_devarm/in_chroot.sh
cd tmp_devarm
docker build . -t ${IMAGE}_arm:${VERSION} -f ../Dockerfile_devarm --cpuset-cpus "0-$ncores" # --build-arg BASEIMAGE=${IMAGE}:${VERSION}
