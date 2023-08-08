#!/bin/bash

source ../version.sh

echo "Building ${IMAGE}_emacs:${VERSION}"

ncores=$(cat /proc/cpuinfo | grep processor | wc -l)
((ncores--))
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space
docker build . -t ${IMAGE}_emacs:${VERSION} -f Dockerfile_emacs --cpuset-cpus "0-$ncores" --build-arg baseversion=${VERSION} --build-arg baseimage=${IMAGE}

