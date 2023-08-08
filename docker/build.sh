#!/bin/bash

# This is a very long process

# 1. Build base and convenience layers
./build_base.sh
(cd ui && ./build_code.sh)
(cd ui && ./build_emacs.sh)

# 2. Build cross layers
./build_qemu.sh

# 2.1. aarch64 layer

(cd aarch64 && ./deboot.sh)
./prep_devarm.sh
./build_devarm.sh

# 2.2. riscv64 layer

#(cd riscv64 && ./deboot.sh)
#./prep_devriscv.sh
#./build_devriscv.sh

# 3. FPGA layers

(cd fpga && ./build.sh)
