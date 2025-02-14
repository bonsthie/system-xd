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

RAMFS_ORIG=$DISTRO_BOOT/boot/initramfs-virt
RAMFS_GEN=$DISTRO_BOOT/boot/initramfs-virt.gen

#TODO(kiroussa): append/replace /sbin/init to the initramfs
cp $RAMFS_ORIG $RAMFS_GEN #remove this shit lol

# i have no idea what "sane" boot params are so i'm gonna guess this is gonna work and nobody is gonna bother actually checking any other configuration
qemu-system-x86_64 \
	-kernel $DISTRO_BOOT/boot/vmlinuz-virt \
	-initrd $RAMFS_GEN \
	-drive file=$ALPINE_FILE,format=raw,index=0 \
	-append "modules=loop,squashfs,sd-mod,usb-storage quiet" \
	-nographic \
	-append "console=ttyS0 console=tty0"
