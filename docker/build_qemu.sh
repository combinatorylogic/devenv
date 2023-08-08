#!/bin/sh

###
### Build the right qemu version to be used in the aarch64 cross-environment bootstrapping.
###

. ./version.sh 

sudo rm -rf ./workdir_qemu
mkdir -p ./workdir_qemu

docker run --privileged --cap-add=SYS_PTRACE --security-opt seccomp=unconfined  -i -v ${PWD}/workdir_qemu:/workdir -v ${PWD}/..:/workdir/devenv --entrypoint "/bin/bash"  ${IMAGE}:${VERSION} <<EOF

cd /workdir/
git clone https://github.com/qemu/qemu.git
cd qemu
git checkout 0450cf08976f9036feaded438031b4cba94f6452
git submodule update --init --recursive
mkdir build && cd build
../configure --prefix=/usr --static --disable-system --enable-linux-user --enable-attr --target-list=aarch64-linux-user
make -j
strip /workdir/qemu/build/qemu-aarch64
cd /workdir/qemu/
mkdir build1 && cd build1
../configure --prefix=/usr --static --disable-system --enable-linux-user --enable-attr --target-list=riscv64-linux-user
make -j
strip /workdir/qemu/build1/qemu-riscv64


EOF

cp ./workdir_qemu/qemu/build/qemu-aarch64 ./aarch64/qemu-aarch64-static
cp ./workdir_qemu/qemu/build1/qemu-riscv64 ./riscv64/qemu-riscv64-static


