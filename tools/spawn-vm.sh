#!/usr/bin/env bash

function log() {
	echo "*> $@"
}

DIRECTORY="$(dirname "$0")"
if [ "$DIRECTORY" != "." ]; then
	log "Wrong directory detected, moving to $DIRECTORY"
	cd $DIRECTORY
fi

source ./config.sh

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

if [ ! -f "$ROOTFS_IMG" ]; then
	log "Downloading Alpine minirootfs"
	wget "$ALPINE_ROOTFS_URL" -O alpine-minirootfs.tar.gz

	log "Creating disk image"
	truncate -s 512M "$ROOTFS_IMG"
	mkfs.ext4 -F -q "$ROOTFS_IMG"

	log "Populating rootfs"
	mkdir -p "$ROOTFS_MNT"

	log "Guestmounting..."
	guestmount \
		-a "$ROOTFS_IMG" \
		-m /dev/sda \
		"$ROOTFS_MNT"

	log "Copying rootfs..."
	tar -xzf alpine-minirootfs.tar.gz -C "$ROOTFS_MNT"

	log "Unmounting rootfs..."
	guestunmount "$ROOTFS_MNT"

	sleep 1

	log "Running guestfish"
	guestfish -a "$ROOTFS_IMG" -i <<-EOF
		command "sh -c 'echo root:root | chpasswd'"
		command "sh -c 'adduser -D user'"
		command "sh -c 'echo user:user | chpasswd'"
	EOF
	log "Done"
fi

if [ ! -d $RAMFS_DUMP ]; then
	log "Extracting initial initramfs"
	pushd $DISTRO_BOOT >/dev/null
	zcat initramfs-virt | cpio -idmv -D ${RAMFS_DUMP##*/} 2>/dev/null
	popd >/dev/null
fi

bash ./fsck.sh

# Build and add /init
NO_REPLACE_INIT=${NO_REPLACE_INIT:-0}
BUILD=0
if [ $NO_REPLACE_INIT -eq 0 ]; then
	if [ -f $RAMFS_GEN/init ]; then
		OLD_HASH=$(sha256sum $RAMFS_GEN/init | cut -d' ' -f1)
	fi

	log "Building system-xd"
	cd ..
	zig build || exit
	cd tools

	log "Copying ramfs to $RAMFS_GEN"
	rm -rf $RAMFS_GEN
	cp -r $RAMFS_DUMP $RAMFS_GEN

	log "Copying fsck impls to $RAMFS_GEN"
	cp -vf ./e2fsck $RAMFS_GEN/e2fsck
	cp -vf ./fsck.fat $RAMFS_GEN/fsck.fat

	log "Replacing init"
	rm -vrf $RAMFS_GEN/init
	cp -v ../zig-out/bin/init $RAMFS_GEN/init
	NEW_HASH=$(sha256sum $RAMFS_GEN/init | cut -d' ' -f1)
	mkdir -p "$ROOTFS_MNT"
	mkdir -p "$ROOTFS_MNT"

	guestmount \
		-a "$ROOTFS_IMG" \
		-m /dev/sda \
		"$ROOTFS_MNT"

	rm -vf "$ROOTFS_MNT/sbin/init"
	cp -v ../zig-out/bin/init "$ROOTFS_MNT/sbin/init"
	touch "$ROOTFS_MNT/.rootfs-marker"
	cp -v ../zig-out/bin/xd "$ROOTFS_MNT/sbin/xd"

	guestunmount "$ROOTFS_MNT"

	REQUIRED_MODULES="virtio_blk"
	python3 ./resolve-modules.py $RAMFS_GEN lib/modules/6.12.8-0-virt $REQUIRED_MODULES > $RAMFS_GEN/modules.xd

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

read -p "Press enter to continue"
log "Launching qemu"
# i have no idea what "sane" boot params are so i'm gonna guess this is gonna work and nobody is gonna bother actually checking any other configuration

# CMDLINE_TTY="console=ttyS0" 
CMDLINE_TTY="modules=loop,squashfs,sd-mod,usb-storage console=ttyS0"

INITRAMFS_BOOT=${INITRAMFS_BOOT:-$INITRAMFS_GEN}
GRAPHICS=${GRAPHICS:-0}

INITRAMFS_BOOT=${INITRAMFS_BOOT:-$INITRAMFS_GEN}
GRAPHICS=${GRAPHICS:-0}
# echo $CMDLINE
if [ $GRAPHICS -eq 1 ]; then
	log "qemu graphics version exploded, no more"
	exit 1232138139
	# qemu-system-x86_64 \
	# 	-m 2048 \
	# 	-kernel $DISTRO_BOOT/vmlinuz-virt \
	# 	-initrd $INITRAMFS_BOOT \
	# 	-drive file=$ALPINE_FILE,format=raw,index=0 \
	# 	-append "modules=loop,squashfs,sd-mod,usb-storage"
else
	log "qemu tty version"
	qemu-system-x86_64 \
		-m 2048 \
		-kernel "$DISTRO_BOOT/vmlinuz-virt" \
		-initrd "$INITRAMFS_BOOT" \
		-drive file="$ROOTFS_IMG",format=raw,if=virtio \
		-append "root=/dev/vda rootfstype=ext4 rw $CMDLINE_TTY" \
		-nographic
fi
