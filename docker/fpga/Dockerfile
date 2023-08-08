ARG baseversion=1.0.0
ARG baseimage=base_devenv
FROM ${baseimage}:${baseversion}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install tzdata

RUN apt-get update && apt-get install -y libtool-bin autoconf python3-pip libx11-dev libxext-dev x11proto-core-dev x11proto-gl-dev libglew-dev freeglut3-dev bison flex  && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 10

# Yosys, nextpnr and icestorm dependencies
RUN apt-get update && apt-get install -y  build-essential bison flex \
                libreadline-dev gawk tcl-dev libffi-dev git \
                graphviz xdot pkg-config python3 libboost-system-dev \
                libboost-python-dev libboost-filesystem-dev zlib1g-dev libftdi-dev \
                python3-dev libboost-all-dev libeigen3-dev qt5-default gperf libgmp-dev  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Build Mesa
WORKDIR /root
RUN apt-get update && apt-get install -y wget pkg-config zlib1g-dev llvm-dev  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Builds icestorm
RUN cd /root; git clone --recursive https://github.com/cliffordwolf/icestorm.git && \
    cd /root/icestorm && git checkout 0ec00d892a91cc68e45479b46161f649caea2933 && make -j16 install && cd /root && rm -rf icestorm

# Build Yosys
RUN cd /root; git clone --recursive https://github.com/YosysHQ/yosys.git && \
    cd /root/yosys && git checkout 84e9fa764803e93c59aff9f10bcc1a5ae2f9f120 && git submodule update --init --recursive && make -j16 install && cd /root && rm -rf yosys


# Build Trellis
RUN cd /root; git clone https://github.com/SymbiFlow/prjtrellis.git && cd /root/prjtrellis \
        && git checkout f93243b000c52b755c70829768d2ae6bcf7bb91a && git submodule update --init --recursive \
        && mkdir -p build && cd build \
        && cmake -DCMAKE_INSTALL_PREFIX=/usr/local ../libtrellis/ \
        && make -j16 install && cd /root && rm -rf prjtrellis

# Build nextpnr-ice40 and nextpnr-ecp5
RUN cd /root; git clone --recursive https://github.com/YosysHQ/nextpnr.git && \
    cd /root/nextpnr && git checkout 576baa994f4b9e1746a231469bfd9e65d1d5a2b4 && \
        mkdir build-ice40 && cd build-ice40 && cmake -DARCH=ice40 ..  && make -j16 install \
        && cd /root/nextpnr && mkdir build-ecp5 && cd build-ecp5 && cmake  -DARCH=ecp5 -DCMAKE_INSTALL_PREFIX=/usr/local -DTRELLIS_ROOT=/usr/local/share/trellis .. && make -j16 install \
        && cd /root && rm -rf nextpnr

# Build arachne
RUN cd /root; git clone --recursive https://github.com/YosysHQ/arachne-pnr.git && \
    cd arachne-pnr && git checkout c40fb2289952f4f120cc10a5a4c82a6fb88442dc && make -j16 install && cd /root && rm -rf arachne-pnr

# Build icarus
RUN cd /root && git clone --recursive https://github.com/steveicarus/iverilog.git && \
    cd /root/iverilog && git checkout 359b2b65c2f015191ec05109d82e91ec22569a9b && autoconf && ./configure --prefix=/usr/local && make -j16 install && cd /root && rm -rf iverilog


# Build verilator
RUN cd /root; git clone --recursive https://github.com/verilator/verilator.git && \
    cd /root/verilator && git checkout e3cf5c07e480910fde843c1da00ff0c8ba48bb12 && autoconf && ./configure --prefix=/usr/local && make -j16 && make install && cd /root && rm -rf verilator

# Build z3
RUN cd /root; git clone --recursive https://github.com/Z3Prover/z3.git && \
    cd /root/z3 &&  git checkout 2841796a92dbd5b38228c6b87e401eb19a2efdff && mkdir -p build && cd build && cmake .. && make -j16 && make -j16 install

# Build yices: https://github.com/SRI-CSL/yices2.git
RUN cd /root; git clone --recursive https://github.com/SRI-CSL/yices2.git && \
    cd /root/yices2 && git checkout 4692d8db85a609ac5f30b41c6994b048d0bcb2a4 && autoconf && ./configure && make -j16 && make -j16 install

# Build boolector
RUN apt-get update && apt-get install -y curl mercurial && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN cd /root && git clone --recursive https://github.com/Boolector/boolector.git && cd /root/boolector && git checkout 1cff6b0bff8a6c783790c864b0b2cafbcaf8302e \
        && ./contrib/setup-lingeling.sh && ./contrib/setup-btor2tools.sh && ./configure.sh --prefix /usr/local && cd build && make -j16 && make -j16 install

# Build super_prove
COPY suprove /usr/local/bin/
RUN cd /root && git clone --recursive https://github.com/sterin/super-prove-build.git super_prove_build && cd /root/super_prove_build/ && mkdir build && cd build && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local .. && make -j16 install && cd /root && rm -rf super_prove_build

# Build https://github.com/YosysHQ/SymbiYosys.git
RUN cd /root && git clone --recursive https://github.com/YosysHQ/SymbiYosys.git && \
    cd /root/SymbiYosys && git checkout cc1becc1bf1990c4aa604c55f8ed34eb75ed1188 && make install

# Build mbase
RUN apt-get update && apt-get install -y git mono-devel libncurses5-dev swi-prolog && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN git clone --recursive https://github.com/combinatorylogic/mbase.git
RUN cd /root/mbase && git checkout a2528e45cfbd81d208e7a916a7492ad219647478 && cd /root/mbase/bin && make && ./install.sh
ENV PATH="/root/mbase/bin:${PATH}"

