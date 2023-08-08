#!/bin/sh

. ../version.sh

export CROSSCHROOT=/workdir/crosschroot
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
cp /workdir/devenv/docker/riscv64/qemu-riscv64-static /usr/bin/qemu-riscv64-static
cp /workdir/devenv/docker/riscv64/qemu-riscv64-static /usr/bin/qemu-riscv64

if [ ! -d ${CROSSCHROOT} ]; then
   debootstrap --arch=riscv64 --foreign focal ${CROSSCHROOT}
fi

EOF

# Phase 1.5.

docker run --privileged --cap-add=SYS_PTRACE --security-opt seccomp=unconfined  --entrypoint "/bin/bash" -i -v ${PWD}/workdir:/workdir -v ${PWD}/../..:/workdir/devenv ${IMAGE}:${VERSION} <<EOF

unset PYTHONHOME
unset PYTHONPATH
unset CONDA_PREFIX
unset CONDA_EXE
unset PYTHONBREAKPOINT

cp /workdir/devenv/docker/riscv64/run_chroot.sh /workdir
cp /workdir/devenv/docker/riscv64/sources.list /workdir

set -e

if [ ! -f ${CROSSCHROOT}/phase1_5 ]; then
   cp /etc/resolv.conf /workdir/crosschroot/etc/resolv.conf
   mount --bind /proc /workdir/crosschroot/proc
   mount --bind /dev /workdir/crosschroot/dev
   mount --bind /sys /workdir/crosschroot/sys
   mkdir -p /workdir/crosschroot/usr/bin
   cp /workdir/devenv/docker/riscv64/qemu-riscv64-static /workdir/crosschroot/usr/bin
   (cd /workdir/crosschroot && patch -p1 < /workdir/devenv/docker/riscv64/debootstrap.patch)
   rm  -f /workdir/crosschroot/var/lib/dpkg/info/ubuntu-advantage-tools.postinst
   chroot /workdir/crosschroot "/debootstrap/debootstrap" --second-stage
   touch ${CROSSCHROOT}/phase1_5
else
  cp /etc/resolv.conf /workdir/crosschroot/etc/resolv.conf
  mount --bind /proc /workdir/crosschroot/proc
  mount --bind /dev /workdir/crosschroot/dev
  mount --bind /sys /workdir/crosschroot/sys
fi

if [ ! -d ${CROSSCHROOT}/root/symlinks ]; then
  cd /workdir && /bin/bash ./run_chroot.sh
fi

mkdir -p /workdir/crosschroot/root/

EOF



## Phase 2.
docker run --privileged --cap-add=SYS_PTRACE --security-opt seccomp=unconfined  --entrypoint "/bin/bash" -i -v ${PWD}/workdir:/workdir -v ${PWD}/../..:/workdir/devenv ${IMAGE}:${VERSION} <<EOF

apt-get update && apt-get install -y gcc-10-riscv64-linux-gnu

unset PYTHONHOME
unset PYTHONPATH
unset CONDA_PREFIX
unset CONDA_EXE
unset PYTHONBREAKPOINT
export LLVM_VERSION_BRANCH=${LLVM_VERSION_BRANCH}
export CROSSCHROOT=${CROSSCHROOT}

unset CXX
unset CC

export CXX="clang++"
export CC="clang"

cp /workdir/devenv/docker/riscv64/toolchain.riscv64 /workdir

cp /etc/resolv.conf /workdir/crosschroot/etc/resolv.conf
mount --bind /proc /workdir/crosschroot/proc
mount --bind /dev /workdir/crosschroot/dev
mount --bind /sys /workdir/crosschroot/sys

set -e

## Add this:
# deb http://ports.ubuntu.com/ubuntu-ports focal universe

if [ ! -f /workdir/crosschroot/stage0.txt ]; then
if [ ! -f /workdir/clang-riscv3native.tar.gz ]; then
   cp /workdir/devenv/docker/llvm-16.0.6.patch /workdir/llvm.patch
   cp /workdir/devenv/docker/riscv64/clang16w /workdir/
   cp /workdir/devenv/docker/riscv64/clang++16w /workdir/
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


   # First native clang stage
   export CCEXTRA=""
   mkdir -p /workdir/llvm-build1 && cd /workdir/llvm-build1
   # Clang driver is broken again in 16.0.x, does not look in the right places and looks where it should not
   ln -s /usr/lib/clang/16/include/ /workdir/crosschroot/include
   
   cmake -Wno-dev -GNinja -DLLVM_ENABLE_PROJECTS="clang;lld" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=0 -DLLVM_DEFAULT_TARGET_TRIPLE=riscv64-linux-gnu -DLLVM_TARGET_ARCH=RISCV64 -DCMAKE_CROSSCOMPILING=True -DCMAKE_TOOLCHAIN_FILE=/workdir/toolchain.riscv64 -DLLVM_TARGETS_TO_BUILD=RISCV -DLLVM_TABLEGEN=/workdir/llvm-build-native/bin/llvm-tblgen  -DCLANG_TABLEGEN=/workdir/llvm-build-native/bin/clang-tblgen ../llvm-project/llvm/ -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON -DLLVM_PARALLEL_LINK_JOBS=4  -DLLVM_USE_HOST_TOOLS=ON -DCMAKE_CROSSCOMPILING=ON
   DESTDIR=/opt/clang-riscv1/ ninja -j16 install/strip
   (cd /opt/clang-riscv1 && tar -cf - .) | (cd /workdir/crosschroot && tar -xvvf -)

   rm -f /workdir/crosschroot/include
   ln -s /workdir/crosschroot/usr/lib/clang/16/include /workdir/crosschroot/include

   mkdir -p /workdir/llvm-build1x && cd /workdir/llvm-build1x
   cmake -Wno-dev -GNinja -DLLVM_ENABLE_PROJECTS="clang;lld;compiler-rt"  -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=0 -DLLVM_DEFAULT_TARGET_TRIPLE=riscv64-linux-gnu -DLLVM_TARGET_ARCH=RISCV64 -DCMAKE_CROSSCOMPILING=True -DCMAKE_TOOLCHAIN_FILE=/workdir/toolchain.riscv64 -DLLVM_TARGETS_TO_BUILD=RISCV -DLLVM_TABLEGEN=/workdir/llvm-build-native/bin/llvm-tblgen  -DCLANG_TABLEGEN=/workdir/llvm-build-native/bin/clang-tblgen ../llvm-project/llvm/ -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON -DLLVM_PARALLEL_LINK_JOBS=4  -DLLVM_USE_HOST_TOOLS=ON -DCMAKE_CROSSCOMPILING=ON
   DESTDIR=/opt/clang-riscv1/ ninja -j16 cxx cxxabi unwind compiler-rt

   for PFX in /workdir/crosschroot /opt/clang-riscv1
   do
          (cd include/c++/ && tar -cf - .) | (cd \$PFX/usr/include/c++/ && tar -xf -)
          cp include/riscv64-linux-gnu/c++/v1/__config_site  \$PFX/usr/include/c++/v1/
          (cd lib/clang/16/ && tar -cf - lib share) | (cd \$PFX/lib/clang/16/ && tar -xvvf -)
          (cd lib/riscv64-linux-gnu/ && tar -cf - .) | (cd \$PFX/lib/riscv64-linux-gnu/ && tar -xvvf -)
   done

   
   # rm -f /workdir/crosschroot/include
      
   # Second native clang stage
   export CCEXTRA="-stdlib=libc++"
   mkdir -p /workdir/llvm-build2 && cd /workdir/llvm-build2
   cmake -Wno-dev -GNinja -DLLVM_ENABLE_PROJECTS="clang;lld" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=0 -DLLVM_DEFAULT_TARGET_TRIPLE=riscv64-linux-gnu -DLLVM_TARGET_ARCH=RISCV64 -DCMAKE_CROSSCOMPILING=True -DCMAKE_TOOLCHAIN_FILE=/workdir/toolchain.riscv64 -DLLVM_TARGETS_TO_BUILD=RISCV -DLLVM_TABLEGEN=/workdir/llvm-build-native/bin/llvm-tblgen -DCLANG_TABLEGEN=/workdir/llvm-build-native/bin/clang-tblgen ../llvm-project/llvm/ -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON -DLLVM_PARALLEL_LINK_JOBS=4  -DLLVM_USE_HOST_TOOLS=OFF -DCMAKE_CROSSCOMPILING=ON -DLLVM_NATIVE_TOOL_DIR=/workdir/llvm-build1/NATIVE/bin/ -DLLVM_CONFIG_PATH=/workdir/llvm-build1/NATIVE/bin/
   DESTDIR=/opt/clang-riscv2/ ninja -j16 install/strip
   (cd /opt/clang-riscv2 && tar -cf - .) | (cd /workdir/crosschroot && tar -xvvf -)

   mkdir -p /workdir/llvm-build2x && cd /workdir/llvm-build2x
   cmake -Wno-dev -GNinja -DLLVM_ENABLE_PROJECTS="clang;compiler-rt"  -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=0 -DLLVM_DEFAULT_TARGET_TRIPLE=riscv64-linux-gnu -DLLVM_TARGET_ARCH=RISCV64 -DCMAKE_CROSSCOMPILING=True -DCMAKE_TOOLCHAIN_FILE=/workdir/toolchain.riscv64 -DLLVM_TARGETS_TO_BUILD=RISCV -DLLVM_TABLEGEN=/workdir/llvm-build-native/bin/llvm-tblgen -DCLANG_TABLEGEN=/workdir/llvm-build-native/bin/clang-tblgen ../llvm-project/llvm/ -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON -DLLVM_PARALLEL_LINK_JOBS=4  -DLLVM_USE_HOST_TOOLS=OFF -DCMAKE_CROSSCOMPILING=ON -DLLVM_NATIVE_TOOL_DIR=/workdir/llvm-build1/NATIVE/bin/ -DLLVM_CONFIG_PATH=/workdir/llvm-build1/NATIVE/bin/
   DESTDIR=/opt/clang-riscv1/ ninja -j16 cxx cxxabi unwind compiler-rt

   for PFX in /workdir/crosschroot /opt/clang-riscv2
   do
          (cd include/c++/ && tar -cf - .) | (cd \$PFX/usr/include/c++/ && tar -xf -)
          cp include/riscv64-linux-gnu/c++/v1/__config_site  \$PFX/usr/include/c++/v1/
          (cd lib/clang/16/ && tar -cf - lib share) | (cd \$PFX/lib/clang/16/ && tar -xvvf -)
          (cd lib/riscv64-linux-gnu/ && tar -cf - .) | (cd \$PFX/lib/riscv64-linux-gnu/ && tar -xvvf -)
   done



   cd /opt/clang-riscv1 && tar -cvvzf /workdir/clang-riscv1.tar.gz .
   cd /opt/clang-riscv2 && tar -cvvzf /workdir/clang-riscv2.tar.gz .

   # Now, the nasty trick - build a scratchbox2-like environment, with a native clang 
   #   inside riscv64 chroot fs
   export CC=clang
   export CXX="clang++ -stdlib=libc++"

   mkdir -p /workdir/llvm-build3 && cd /workdir/llvm-build3
   cmake -Wno-dev -GNinja -DLLVM_ENABLE_PROJECTS="clang;lld" -DCMAKE_INSTALL_PREFIX=/opt/host -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=0 -DLLVM_DEFAULT_TARGET_TRIPLE=riscv64-linux-gnu -DLLVM_TARGETS_TO_BUILD=RISCV -DLLVM_TABLEGEN=/workdir/llvm-build-native/bin/llvm-tblgen -DCLANG_TABLEGEN=/workdir/llvm-build-native/bin/clang-tblgen ../llvm-project/llvm/ -DCMAKE_BUILD_WITH_INSTALL_RPATH=ON -DLLVM_PARALLEL_LINK_JOBS=4
   DESTDIR=/opt/clang-riscv3 ninja -j16 install/strip
   (cd /opt/clang-riscv3 && tar -cf - .) | (cd /workdir/crosschroot && tar -xvvf -)
   ## It's still broken
   # DESTDIR=${CROSSCHROOT} ninja -j6 install/strip
   cd /opt/clang-riscv3 && tar -cvvzf /workdir/clang-riscv3native.tar.gz .

   rm -rf /opt/clang-riscv*
   rm -rf /workdir/llvm-build* 
else
   if [ ! -f /workdir/crosschroot/opt/host/bin/clang ]; then
      (cd /workdir/crosschroot && tar -xvvf /workdir/clang-riscv2.tar.gz)
      (cd /workdir/crosschroot && tar -xvvf /workdir/clang-riscv3native.tar.gz)
   fi
fi

rm -f /usr/bin/ranlib
rm -f /usr/bin/ar
ln -s /opt/host/bin/llvm-ranlib /usr/bin/ranlib
ln -s /opt/host/bin/llvm-ar /usr/bin/ar

cd /workdir/crosschroot

/workdir/devenv/docker/aarch64/getlibs.sh

mkdir -p /workdir/crosschroot/usr/lib/x86_64-linux-gnu
cp /workdir/libtmp/* /workdir/crosschroot/usr/lib/x86_64-linux-gnu/
mkdir -p /workdir/crosschroot/lib64/
cp /lib/x86_64-linux-gnu/ld-2.31.so /workdir/crosschroot/lib64/ld-linux-x86-64.so.2

touch /workdir/crosschroot/stage0.txt
fi

EOF

docker run --privileged --cap-add=SYS_PTRACE --security-opt seccomp=unconfined  -i -v ${PWD}/workdir:/workdir -v ${PWD}/../..:/workdir/devenv --entrypoint "/bin/bash"  ${IMAGE}:${VERSION} <<EOF

cd ${CROSSCHROOT}

if [ -f /workdir/crosschroot/stage0.txt ]; then
  rm -rf usr/lib/libclang*.a usr/lib/libLLVM*.a
  rm -f opt/host/lib/libclang*.a opt/host/lib/libLLVM*.a
  rm -rf /workdir/crosschroot/var/cache/apt
  tar -czf /workdir/chroot.tar.gz .
fi

EOF


echo "Done"
