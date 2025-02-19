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
INITRAMFS_GEN=${INITRAMFS_GEN:-$DISTRO_BOOT/initramfs-virt.gen}

RAMFS_DUMP=$DISTRO_BOOT/ramfs-dump

if [ ! -d $RAMFS_DUMP ]; then
	log "Extracting initial initramfs"
	pushd $DISTRO_BOOT >/dev/null
	zcat initramfs-virt | cpio -idmv -D ${RAMFS_DUMP##*/} 2>/dev/null
	popd >/dev/null
fi

RAMFS_GEN=$DISTRO_BOOT/ramfs-gen

# Build and add /init
NO_REPLACE_INIT=${NO_REPLACE_INIT:-0}
BUILD=0
if [ $NO_REPLACE_INIT -eq 0 ]; then
	if [ -f $RAMFS_GEN/init ]; then
		OLD_HASH=$(sha256sum $RAMFS_GEN/init | cut -d' ' -f1)
	fi

	log "Building system-xd"
	zig build || exit

	log "Copying ramfs to $RAMFS_GEN"
	rm -rf $RAMFS_GEN
	cp -r $RAMFS_DUMP $RAMFS_GEN

	log "Replacing init"
	rm -vrf $RAMFS_GEN/init
	cp -v zig-out/bin/init $RAMFS_GEN/init
	NEW_HASH=$(sha256sum $RAMFS_GEN/init | cut -d' ' -f1)

	if [ "$OLD_HASH" != "$NEW_HASH" ]; then
		log "initramfs changed, rebuilding"
		BUILD=1
	elif [ ! -f $INITRAMFS_GEN ]; then
		log "initramfs not found, building"
		BUILD=1
	else
		log "initramfs unchanged, skipping"
	fi
else
	log "Skipping init replacement generation"
	BUILD=1
	if [ -z $RAMFS_NOCOPY ]; then
		cp -r $RAMFS_DUMP $RAMFS_GEN
	fi
fi

if [ $BUILD -eq 1 ]; then
	pushd $RAMFS_GEN >/dev/null
	log "Building initramfs"
	find . | sort | cpio -o --renumber-inodes -H newc > $INITRAMFS_GEN.raw
	
	INITRAMFS_COMPRESS=${INITRAMFS_COMPRESS:-0}
	if [ $INITRAMFS_COMPRESS -eq 1 ]; then
		log "Compressing initramfs"
		gzip -9 $INITRAMFS_GEN.raw -c > $INITRAMFS_GEN
	else
		cp $INITRAMFS_GEN.raw $INITRAMFS_GEN
	fi
	popd >/dev/null

	if [ ${INITRAMFS_TEST_EXTRACT:-0} -eq 1 ]; then
		log "Test extracting new initramfs"
		if [ $INITRAMFS_COMPRESS -eq 1 ]; then
			zcat $INITRAMFS_GEN | cpio -idmv -D .distro/test-ramfs 2>/dev/null
		else
			cat $INITRAMFS_GEN | cpio -idmv -D .distro/test-ramfs 2>/dev/null
		fi
	fi

	rm -rf $INITRAMFS_GEN.raw
fi

log "Launching qemu"
# i have no idea what "sane" boot params are so i'm gonna guess this is gonna work and nobody is gonna bother actually checking any other configuration

# CMDLINE_TTY="console=ttyS0" 
CMDLINE_TTY="modules=loop,squashfs,sd-mod,usb-storage console=ttyS0 init=/bin/sh"

INITRAMFS_BOOT=${INITRAMFS_BOOT:-$INITRAMFS_GEN}
GRAPHICS=${GRAPHICS:-0}
echo $CMDLINE_TTY
if [ $GRAPHICS -eq 1 ]; then
    log "qemu graphics version"
	qemu-system-x86_64 \
		-m 2048 \
		-kernel $DISTRO_BOOT/vmlinuz-virt \
		-initrd $INITRAMFS_BOOT \
		-drive file=$ALPINE_FILE,format=raw,index=0 \
		-append "modules=loop,squashfs,sd-mod,usb-storage"
else
    log "qemu tty version"
    qemu-system-x86_64 \
        -m 2048 \
        -kernel $DISTRO_BOOT/vmlinuz-virt \
        -initrd $INITRAMFS_BOOT \
        -drive file=$ALPINE_FILE,format=raw,index=0 \
        -nographic \
        -append "$CMDLINE_TTY" && reset
fi
