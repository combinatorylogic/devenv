#!/bin/bash

. ./version.sh

### Build the base image. Do it in a temp directory to
### avoid creating accidentally a large context if we
### have some garbage in the current directory.

mkdir -p temp_base

cp llvm-16.0.6.patch  temp_base/

ncores=$(cat /proc/cpuinfo | grep processor | wc -l)
((ncores--))
echo "Building dev image"
docker build temp_base/ -t ${IMAGE}:${VERSION} -f Dockerfile_base --cpuset-cpus "0-$ncores"
