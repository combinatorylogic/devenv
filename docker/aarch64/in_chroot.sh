#!/bin/bash

if [ ! -d /workdir/armchroot/etc ]; then
   mkdir -p /workdir/armchroot-upper
   mkdir -p /workdir/armchroot-work
   mkdir -p /workdir/armchroot
   mount -t overlay overlay -o lowerdir=/opt/rootfs/,upperdir=/workdir/armchroot-upper/,workdir=/workdir/armchroot-work/ /workdir/armchroot
fi

mkdir -p /workdir/armchroot/workdir
rm -f /workdir/armchroot/etc/resolv.conf
cp /etc/resolv.conf /workdir/armchroot/etc/resolv.conf
mount --bind /proc /workdir/armchroot/proc
mount --bind /dev /workdir/armchroot/dev
mount --bind /dev/pts /workdir/armchroot/dev/pts
mount --bind /sys /workdir/armchroot/sys
mount --bind /workdir /workdir/armchroot/workdir
if [ -d /workdir/mirrors ]; then
    mkdir -p /workdir/armchroot/workdir/mirrors
    mount --bind /workdir/mirrors /workdir/armchroot/workdir/mirrors
fi
cp /root/.gitconfig /workdir/armchroot/root/.gitconfig
mount --bind /workdir/devenv /workdir/armchroot/workdir/devenv

chroot /workdir/armchroot bash


