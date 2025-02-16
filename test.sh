ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/alpine-virt-3.21.2-x86_64.iso"
ALPINE_FILE="alpine-virt-3.21.2-x86_64.iso"
DISTRO_BOOT=".distro"

if [ ! -d $DISTRO_BOOT ]; then
	if [ ! -f $ALPINE_FILE ]; then
		wget $ALPINE_URL -O $ALPINE_FILE
	fi
	TMP_TARGET=boot
	bsdtar -xf $ALPINE_FILE $TMP_TARGET
	chmod -R u+w $TMP_TARGET
	mv $TMP_TARGET $DISTRO_BOOT
fi

RAMFS_ORIG=$DISTRO_BOOT/initramfs-virt
RAMFS_GEN=$DISTRO_BOOT/initramfs-virt.gen

if [ ! -f $RAMFS_GEN ]; then
	pushd $DISTRO_BOOT
	zcat initramfs-virt | cpio -idmv -D ramfs-gen
	popd
	pushd $DISTRO_BOOT/ramfs-gen
	# TODO: do modifications
	
	find . -type f | cpio -o -H newc | gzip -9 > ../../$RAMFS_GEN
	popd
fi

# i have no idea what "sane" boot params are so i'm gonna guess this is gonna work and nobody is gonna bother actually checking any other configuration
qemu-system-x86_64 \
	-kernel $DISTRO_BOOT/vmlinuz-virt \
	-initrd $RAMFS_GEN \
	-drive file=$ALPINE_FILE,format=raw,index=0 \
	-append "modules=loop,squashfs,sd-mod,usb-storage quiet" \
	-nographic \
	-append "console=ttyS0 console=tty0"
