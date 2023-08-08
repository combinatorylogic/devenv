#!/bin/sh


rm -f /workdir/liblist0
mkdir -p /workdir/libtmp/
for f in ./opt/host/bin/*; do
    ldd $f | awk 'NF == 4 { system("echo cp " $3 " /workdir/libtmp/") }' >> /workdir/liblist0
done

sort /workdir/liblist0 | uniq| grep "usr/lib/x86_64" > /workdir/liblist

. /workdir/liblist

