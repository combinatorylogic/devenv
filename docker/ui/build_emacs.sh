#!/bin/bash

source ../version.sh

echo "Building ${IMAGE}_emacs:${VERSION}"


if [ -z ${BASEIMAGE+x} ]; then
    USEIMAGE=${IMAGE}
    SUFFIX=emacs
else
    echo "Baseimag"
    USEIMAGE=${IMAGE}_${BASEIMAGE}
    SUFFIX=${BASEIMAGE}_emacs
fi

echo "Image=${USEIMAGE} / ${IMAGE} / ${BASEIMAGE} : ${SUFFIX}"
ncores=$(cat /proc/cpuinfo | grep processor | wc -l)
((ncores--))
echo 0 | sudo tee /proc/sys/kernel/randomize_va_space
docker build . -t ${IMAGE}_${SUFFIX}:${VERSION} -f Dockerfile_emacs --cpuset-cpus "0-$ncores" --build-arg baseversion=${VERSION} --build-arg baseimage=${USEIMAGE}

