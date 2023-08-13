#!/bin/bash

source ../version.sh

ncores=$(cat /proc/cpuinfo | grep processor | wc -l)
((ncores--))



if [ -z ${BASEIMAGE+x} ]; then
    USEIMAGE=${IMAGE}
    SUFFIX=code
else
    USEIMAGE=${IMAGE}_${BASEIMAGE}
    SUFFIX=${BASEIMAGE}_code
fi

docker build . -t ${IMAGE}_${SUFFIX}:${VERSION} -f Dockerfile_vscode --cpuset-cpus "0-$ncores" --build-arg baseversion=${VERSION} --build-arg baseimage=${USEIMAGE}
