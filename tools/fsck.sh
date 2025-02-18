#!/usr/bin/env bash

set -euo pipefail

### fsck.ext4

EXEC="e2fsck"
if [ ! -f $EXEC ]; then
	DIRNAME="e2fsprogs-1.47.2"
	if [ ! -d $DIRNAME ]; then
		TARGET="https://github.com/tytso/e2fsprogs/archive/refs/tags/v1.47.2.tar.gz"
		TAR_NAME="e2fsprogs-v1.47.2.tar.gz"
		wget -O $TAR_NAME $TARGET
		tar -xpvf $TAR_NAME
		rm -rf $TAR_NAME
	fi

	mkdir -vp $DIRNAME/build
	pushd $DIRNAME/build

	nix-shell -p pkgs.glibc.static --command \
		"../configure LDFLAGS=-static --without-pthread --without-libarchive && make -j$(nproc)"

	popd

	cp $DIRNAME/build/$EXEC/$EXEC $EXEC
	rm -rf $DIRNAME

	echo "e2fsck built"
else
	echo "e2fsck already built"
fi


### fsck.vfat

EXEC="fsck.fat"
if [ ! -f $EXEC ]; then
	DIRNAME="dosfstools-4.2"
	if [ ! -d $DIRNAME ]; then
		TARGET="https://github.com/dosfstools/dosfstools/releases/download/v4.2/dosfstools-4.2.tar.gz"
		TAR_NAME="dosfstools-4.2.tar.gz"
		wget -O $TAR_NAME $TARGET
		tar -xpvf $TAR_NAME
		rm -rf $TAR_NAME
	fi

	pushd $DIRNAME
	nix-shell -p pkgs.glibc.static --command "./configure LDFLAGS=-static && make -j$(nproc)"
	popd

	cp $DIRNAME/src/$EXEC $EXEC 
	rm -rf $DIRNAME

	echo "fsck.fat built"
else
	echo "fsck.fat already built"
fi
