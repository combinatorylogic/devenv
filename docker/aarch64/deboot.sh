#!/bin/sh

. ../version.sh

export ARMCHROOT=/workdir/armchroot
export LLVM_VERSION_BRANCH=llvmorg-16.0.6


echo "Trying...."


# Phase 1.

docker run --privileged --cap-add=SYS_PTRACE --security-opt seccomp=unconfined  -i -v ${PWD}/workdir:/workdir -v ${PWD}/../..:/workdir/devenv --entrypoint "/bin/bash"  ${IMAGE}:${VERSION} <<EOF

unset PYTHONHOME
unset PYTHONPATH
unset CONDA_PREFIX
unset CONDA_EXE
unset PYTHONBREAKPOINT

set -e

echo "Going..."

apt-get update && apt-get install -y qemu-user-static binfmt-support debootstrap
cp /workdir/devenv/docker/aarch64/qemu-aarch64-static /usr/bin/qemu-aarch64-static
cp /workdir/devenv/docker/aarch64/qemu-aarch64-static /usr/bin/qemu-aarch64

if [ ! -d ${ARMCHROOT} ]; then
   debootstrap --arch=arm64 --foreign focal ${ARMCHROOT}
fi

EOF

# Phase 1.5.

docker run --privileged --cap-add=SYS_PTRACE --security-opt seccomp=unconfined  --entrypoint "/bin/bash" -i -v ${PWD}/workdir:/workdir -v ${PWD}/../..:/workdir/devenv ${IMAGE}:${VERSION} <<EOF

unset PYTHONHOME
unset PYTHONPATH
unset CONDA_PREFIX
unset CONDA_EXE
unset PYTHONBREAKPOINT

cp /workdir/devenv/docker/aarch64/run_chroot.sh /workdir
cp /workdir/devenv/docker/aarch64/sources.list /workdir

set -e

if [ ! -f ${ARMCHROOT}/phase1_5 ]; then
   cp /etc/resolv.conf /workdir/armchroot/etc/resolv.conf
   mount --bind /proc /workdir/armchroot/proc
   mount --bind /dev /workdir/armchroot/dev
   mount --bind /sys /workdir/armchroot/sys
   mkdir -p /workdir/armchroot/usr/bin
   cp /workdir/devenv/docker/aarch64/qemu-aarch64-static /workdir/armchroot/usr/bin
   (cd /workdir/armchroot && patch -p1 < /workdir/devenv/docker/aarch64/debootstrap.patch)
   chroot /workdir/armchroot "/debootstrap/debootstrap" --second-stage
   touch ${ARMCHROOT}/phase1_5
else
  cp /etc/resolv.conf /workdir/armchroot/etc/resolv.conf
  mount --bind /proc /workdir/armchroot/proc
  mount --bind /dev /workdir/armchroot/dev
  mount --bind /sys /workdir/armchroot/sys
fi

if [ ! -d ${ARMCHROOT}/root/symlinks ]; then
  cd /workdir && /bin/bash ./run_chroot.sh
fi

mkdir -p /workdir/armchroot/root/

EOF


## Phase 2.
docker run --privileged --cap-add=SYS_PTRACE --security-opt seccomp=unconfined  --entrypoint "/bin/bash" -i -v ${PWD}/workdir:/workdir -v ${PWD}/../..:/workdir/devenv ${IMAGE}:${VERSION} <<EOF

apt-get update && apt-get install -y gcc-10-aarch64-linux-gnu

unset PYTHONHOME
unset PYTHONPATH
unset CONDA_PREFIX
unset CONDA_EXE
unset PYTHONBREAKPOINT
export LLVM_VERSION_BRANCH=${LLVM_VERSION_BRANCH}
export ARMCHROOT=${ARMCHROOT}

unset CXX
unset CC

export CXX="clang++"
export CC="clang"

cp /workdir/devenv/docker/aarch64/toolchain.aarch64 /workdir

cp /etc/resolv.conf /workdir/armchroot/etc/resolv.conf
mount --bind /proc /workdir/armchroot/proc
mount --bind /dev /workdir/armchroot/dev
mount --bind /sys /workdir/armchroot/sys

set -e

## Add this:
# deb http://ports.ubuntu.com/ubuntu-ports focal universe

if [ ! -f /workdir/armchroot/stage0.txt ]; then
if [ ! -f /workdir/clang-arm3native.tar.gz ]; then
   cp /workdir/devenv/docker/llvm-16.0.6.patch /workdir/llvm.patch
   cd /workdir
   if [ ! -d /workdir/llvm-project ]; then
     mkdir llvm-project && cd /workdir/llvm-project && git init . && git remote add origin https://github.com/llvm/llvm-project.git
     git fetch --depth 1 origin \${LLVM_VERSION_BRANCH} && git checkout FETCH_HEAD
     patch -p1 < /workdir/llvm.patch
   fi

   # Host tablegen build
   mkdir -p /workdir/llvm-build-native && cd /workdir/llvm-build-native
   cmake -Wno-dev -GNinja -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=0 ../llvm-project/llvm/
   ninja -j6 clang-tblgen llvm-tblgen


   # First ARM native clang stage
   export ARMEXTRA=""
   mkdir -p /workdir/llvm-build1 && cd /workdir/llvm-build1
   # Clang driver is broken again in 16.0.x, does not look in the right places and looks where it should not
   ln -s /usr/lib/clang/16/include/ /workdir/armchroot/include
   
   cmake -Wno-dev -GNinja -DLLVM_ENABLE_PROJECTS="clang;lld" -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=0 -DLLVM_DEFAULT_TARGET_TRIPLE=aarch64-linux-gnu -DLLVM_TARGET_ARCH=AArch64 -DCMAKE_CROSSCOMPILING=True -DCMAKE_TOOLCHAIN_FILE=/workdir/toolchain.aarch64 -DLLVM_TARGETS_TO_BUILD=AArch64 -DLLVM_TABLEGEN=/workdir/llvm-build-native/bin/llvm-tblgen  -DCLANG_TABLEGEN=/workdir/llvm-build-native/bin/clang-tblgen ../llvm-project/llvm/ -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON -DLLVM_PARALLEL_LINK_JOBS=4  -DLLVM_USE_HOST_TOOLS=ON -DCMAKE_CROSSCOMPILING=ON
   DESTDIR=/opt/clang-arm1/ ninja -j16 install/strip
   (cd /opt/clang-arm1 && tar -cf - .) | (cd /workdir/armchroot && tar -xvvf -)
   
   # wrong installation path? why?
   cp /workdir/armchroot/usr/include/aarch64-linux-gnu/c++/v1/__config_site /workdir/armchroot/usr/include/c++/v1/__config_site
   
   rm -f /workdir/armchroot/include
      
   # Second ARM native clang stage
   export ARMEXTRA="-stdlib=libc++"
   mkdir -p /workdir/llvm-build2 && cd /workdir/llvm-build2
   cmake -Wno-dev -GNinja -DLLVM_ENABLE_PROJECTS="clang;lld" -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind;compiler-rt" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=0 -DLLVM_DEFAULT_TARGET_TRIPLE=aarch64-linux-gnu -DLLVM_TARGET_ARCH=AArch64 -DCMAKE_CROSSCOMPILING=True -DCMAKE_TOOLCHAIN_FILE=/workdir/toolchain.aarch64 -DLLVM_TARGETS_TO_BUILD=AArch64 -DLLVM_TABLEGEN=/workdir/llvm-build-native/bin/llvm-tblgen -DCLANG_TABLEGEN=/workdir/llvm-build-native/bin/clang-tblgen ../llvm-project/llvm/ -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON -DLLVM_PARALLEL_LINK_JOBS=4  -DLLVM_USE_HOST_TOOLS=OFF -DCMAKE_CROSSCOMPILING=ON -DLLVM_NATIVE_TOOL_DIR=/workdir/llvm-build1/NATIVE/bin/ -DLLVM_CONFIG_PATH=/workdir/llvm-build1/NATIVE/bin/
   DESTDIR=/opt/clang-arm2/ ninja -j16 install/strip
   (cd /opt/clang-arm2 && tar -cf - .) | (cd /workdir/armchroot && tar -xvvf -)
   cd /opt/clang-arm1 && tar -cvvzf /workdir/clang-arm1.tar.gz .
   cd /opt/clang-arm2 && tar -cvvzf /workdir/clang-arm2.tar.gz .

   # Now, the nasty trick - build a scratchbox2-like environment, with a native clang 
   #   inside aarch64 chroot fs

   export CC=clang
   export CXX="clang++ -stdlib=libc++"
   mkdir -p /workdir/llvm-build3 && cd /workdir/llvm-build3
   cmake -Wno-dev -GNinja -DLLVM_ENABLE_PROJECTS="clang;lld" -DCMAKE_INSTALL_PREFIX=/opt/host -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=0 -DLLVM_DEFAULT_TARGET_TRIPLE=aarch64-linux-gnu -DLLVM_TARGETS_TO_BUILD=AArch64 -DLLVM_TABLEGEN=/workdir/llvm-build-native/bin/llvm-tblgen -DCLANG_TABLEGEN=/workdir/llvm-build-native/bin/clang-tblgen ../llvm-project/llvm/ -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON -DLLVM_PARALLEL_LINK_JOBS=4
   ninja -j16
   DESTDIR=/opt/clang-arm3 ninja -j6 install/strip
   (cd /opt/clang-arm3 && tar -cf - .) | (cd /workdir/armchroot && tar -xvvf -)
   ## It's still broken
   # DESTDIR=${ARMCHROOT} ninja -j6 install/strip
   cd /opt/clang-arm3 && tar -cvvzf /workdir/clang-arm3native.tar.gz .

   rm -rf /opt/clang-arm*
   rm -rf /workdir/llvm-build* 
else
   if [ ! -f /workdir/armchroot/opt/host/bin/clang ]; then
      (cd /workdir/armchroot && tar -xvvf /workdir/clang-arm2.tar.gz)
      (cd /workdir/armchroot && tar -xvvf /workdir/clang-arm3native.tar.gz)
   fi
fi

rm -f /usr/bin/ranlib
rm -f /usr/bin/ar
ln -s /opt/host/bin/llvm-ranlib /usr/bin/ranlib
ln -s /opt/host/bin/llvm-ar /usr/bin/ar

cd /workdir/armchroot

/workdir/devenv/docker/aarch64/getlibs.sh

mkdir -p /workdir/armchroot/usr/lib/x86_64-linux-gnu
cp /workdir/libtmp/* /workdir/armchroot/usr/lib/x86_64-linux-gnu/
mkdir -p /workdir/armchroot/lib64/
cp /lib/x86_64-linux-gnu/ld-2.31.so /workdir/armchroot/lib64/ld-linux-x86-64.so.2

touch /workdir/armchroot/stage0.txt
fi

EOF

docker run --privileged --cap-add=SYS_PTRACE --security-opt seccomp=unconfined  -i -v ${PWD}/workdir:/workdir -v ${PWD}/../..:/workdir/devenv --entrypoint "/bin/bash"  ${IMAGE}:${VERSION} <<EOF

cd ${ARMCHROOT}

if [ -f /workdir/armchroot/stage0.txt ]; then
  rm -rf usr/lib/libclang*.a usr/lib/libLLVM*.a
  rm -f opt/host/lib/libclang*.a opt/host/lib/libLLVM*.a
  rm -rf /workdir/armchroot/var/cache/apt
  tar -czf /workdir/chroot.tar.gz .
fi

EOF


echo "Done"
