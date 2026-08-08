#!/usr/bin/env false

ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/alpine-virt-3.21.2-x86_64.iso"
ALPINE_FILE="alpine-virt-3.21.2-x86_64.iso"
DISTRO_BOOT="$(pwd)/.distro"

ALPINE_ROOTFS_URL="https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/alpine-minirootfs-3.21.2-x86_64.tar.gz"
ROOTFS_IMG="$DISTRO_BOOT/rootfs.img"
ROOTFS_MNT="$DISTRO_BOOT/rootfs-mnt"

INITRAMFS_ORIG=$DISTRO_BOOT/initramfs-virt
INITRAMFS_GEN=${INITRAMFS_GEN:-$DISTRO_BOOT/initramfs-virt.gen}

RAMFS_DUMP=$DISTRO_BOOT/ramfs-dump
RAMFS_GEN=$DISTRO_BOOT/ramfs-gen
