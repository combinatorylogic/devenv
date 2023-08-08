#!/bin/bash


export SRC=/workdir/devenv/docker/aarch64
export BASEFS=workdir/chroot.tar.gz
export DST=chroot-aarch64.tar.gz
export BLD_CMAKE_VERSION=3.27.1
export BLD_CMAKE_URL=https://github.com/Kitware/CMake/releases/download/v3.27.1/cmake-3.27.1.tar.gz

cd ${SRC}

if [ ! -f ${BASEFS} ]; then
    echo "Execute deboot.sh script first!"
    exit -1
fi

mkdir -p /opt/rootfs
cd /opt/rootfs

tar -xf ${SRC}/${BASEFS}


# Go into chroot and build stuff

mkdir -p /opt/rootfs/workdir
rm -f /opt/rootfs/etc/resolv.conf
cp /etc/resolv.conf /opt/rootfs/etc/resolv.conf
mount --bind /proc /opt/rootfs/proc
mount --bind /dev /opt/rootfs/dev
mount --bind /sys /opt/rootfs/sys
mount --bind /workdir /opt/rootfs/workdir
chroot /opt/rootfs bash <<EOF

cd /usr/bin/

export CC="/opt/host/bin/clang"
export CXX="/opt/host/bin/clang++ -fuse-ld=/opt/host/bin/ld.lld -L/usr/lib -Qunused-arguments"
export LD="/opt/host/bin/ld.lld"
export LD_LIBRARY_PATH=/opt/host/lib:$LD_LIBRARY_PATH
export PATH=/opt/host/bin:$PATH

apt-get update
apt-get remove -y blueman
apt-get install -y ninja-build autoconf automake flex bison libssl-dev openssl sudo iproute2 can-utils

rm -f aarch64-linux-gnu-ld ld
ln -s /opt/host/bin/lld /opt/host/bin/ld
ln -s /opt/host/bin/ld aarch64-linux-gnu-ld
ln -s /opt/host/bin/ld ld

apt-get clean && rm -rf /var/lib/apt/lists/*

cd /workdir/

wget --quiet \${BLD_CMAKE_URL}
tar -xf cmake-\${BLD_CMAKE_VERSION}.tar.gz
cd /workdir/cmake-\${BLD_CMAKE_VERSION}
./bootstrap --parallel=16
make -j16
make -j16 install
cd /workdir
rm -rf /workdir/cmake-*

EOF


# Make sure we set up the right cross-compiler paths every time we log in into chroot

cat >> /opt/rootfs/root/.bashrc <<EOF
export CC="/opt/host/bin/clang"
export CXX="/opt/host/bin/clang++ -fuse-ld=/opt/host/bin/ld.lld -L/usr/lib -Qunused-arguments"
export LD="/opt/host/bin/ld.lld"
export LD_LIBRARY_PATH=/opt/host/lib:\$LD_LIBRARY_PATH
export PATH=/opt/host/bin:\$PATH
EOF

# Re-pack the chrootfs image to be later extracted into a Docker layer
#
# umount /opt/rootfs/opt/mirrors
umount /opt/rootfs/workdir/devenv
umount /opt/rootfs/workdir
umount /opt/rootfs/sys
umount /opt/rootfs/dev
umount /opt/rootfs/proc

  cd /opt/rootfs/
  rm -rf usr/lib/libclang*.a usr/lib/libLLVM*.a
  rm -f opt/host/lib/libclang*.a opt/host/lib/libLLVM*.a
  rm -rf /workdir/armchroot/var/cache/apt

(cd / && tar -czf /workdir/${DST} /opt/rootfs)
