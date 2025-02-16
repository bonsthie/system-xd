#!/usr/bin/env bash

ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/alpine-virt-3.21.2-x86_64.iso"
ALPINE_FILE="alpine-virt-3.21.2-x86_64.iso"
DISTRO_BOOT="$(pwd)/.distro"

function log() {
	echo "*> $@"
}

if [ ! -d $DISTRO_BOOT ]; then
	if [ ! -f $ALPINE_FILE ]; then
		log "Downloading $ALPINE_URL"
		wget $ALPINE_URL -O $ALPINE_FILE
	fi
	log "Extracting $ALPINE_FILE"
	TMP_TARGET=boot
	bsdtar -xf $ALPINE_FILE $TMP_TARGET
	chmod -R u+w $TMP_TARGET
	mv $TMP_TARGET $DISTRO_BOOT
fi

INITRAMFS_ORIG=$DISTRO_BOOT/initramfs-virt
INITRAMFS_GEN=$DISTRO_BOOT/initramfs-virt.gen

RAMFS_DUMP=$DISTRO_BOOT/ramfs-dump

if [ ! -d $RAMFS_DUMP ]; then
	log "Extracting initial initramfs"
	pushd $DISTRO_BOOT >/dev/null
	zcat initramfs-virt | cpio -idmv -D ${RAMFS_DUMP##*/}
	popd >/dev/null
fi

RAMFS_GEN=$DISTRO_BOOT/ramfs-gen

log "Building system-xd"
if [ -f $RAMFS_GEN/init ]; then
	OLD_HASH=$(sha256sum $RAMFS_GEN/init | cut -d' ' -f1)
fi
zig build

log "Generating initramfs"
cp -r $RAMFS_DUMP $RAMFS_GEN
rm -rf $RAMFS_GEN/init
cp zig-out/bin/init $RAMFS_GEN/init
NEW_HASH=$(sha256sum $RAMFS_GEN/init | cut -d' ' -f1)

BUILD=0
if [ "$OLD_HASH" != "$NEW_HASH" ]; then
	log "initramfs changed, rebuilding"
	BUILD=1
elif [ ! -f $INITRAMFS_GEN ]; then
	log "initramfs not found, building"
	BUILD=1
else
	log "initramfs unchanged, skipping"
fi

if [ $BUILD -eq 1 ]; then
	pushd $DISTRO_BOOT >/dev/null
	find . | cpio -o -H newc | gzip -9 > $INITRAMFS_GEN
	popd >/dev/null
fi

log "Launching qemu"
# i have no idea what "sane" boot params are so i'm gonna guess this is gonna work and nobody is gonna bother actually checking any other configuration

GRAPHICS=${GRAPHICS:-0}
if [ $GRAPHICS -eq 1 ]; then
	set -x
	qemu-system-x86_64 \
		-m 2048 \
		-vga std \
		-kernel $DISTRO_BOOT/vmlinuz-virt \
		-initrd $INITRAMFS_GEN \
		-drive file=$ALPINE_FILE,format=raw,index=0 \
		-append "modules=loop,squashfs,sd-mod,usb-storage quiet"
else
	set -x
	qemu-system-x86_64 \
		-m 2048 \
		-kernel $DISTRO_BOOT/vmlinuz-virt \
		-initrd $INITRAMFS_GEN \
		-drive file=$ALPINE_FILE,format=raw,index=0 \
		-append "modules=loop,squashfs,sd-mod,usb-storage quiet" \
		 -nographic \
		 -append "console=ttyS0 console=tty0" && reset
fi
