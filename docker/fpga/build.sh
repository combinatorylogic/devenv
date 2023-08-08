#!/bin/bash

. ../version.sh 
set -e

ncores=$(cat /proc/cpuinfo | grep processor | wc -l)
((ncores--))
docker build . -t ${IMAGE}_fpgadev:${VERSION} -f Dockerfile --cpuset-cpus "0-$ncores"  --build-arg baseversion=${VERSION} --build-arg baseimage=${IMAGE}
docker build . -t ${IMAGE}_fpgaenv:${VERSION} -f Dockerfile-dev --cpuset-cpus "0-$ncores"  --build-arg baseversion=${VERSION} --build-arg baseimage=${IMAGE}
docker build . -t ${IMAGE}_fpgaext:${VERSION} -f Dockerfile-extra --cpuset-cpus "0-$ncores"  --build-arg baseversion=${VERSION} --build-arg baseimage=${IMAGE}
docker build . -t ${IMAGE}_fpgaext_nogl:${VERSION} -f Dockerfile-nogl --cpuset-cpus "0-$ncores"  --build-arg baseversion=${VERSION} --build-arg baseimage=${IMAGE}

