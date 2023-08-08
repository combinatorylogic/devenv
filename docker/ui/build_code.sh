#!/bin/bash

source ../version.sh

ncores=$(cat /proc/cpuinfo | grep processor | wc -l)
((ncores--))



docker build . -t ${IMAGE}_code:${VERSION} -f Dockerfile_vscode --cpuset-cpus "0-$ncores" --build-arg baseversion=${VERSION} --build-arg baseimage=base_devenv
