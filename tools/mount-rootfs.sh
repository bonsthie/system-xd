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

if [ ! -f "$ROOTFS_IMG" ]; then
	log "No rootfs image found: $ROOTFS_IMG"
	exit 1
fi

guestmount \
	-a "$ROOTFS_IMG" \
	-m /dev/sda \
	"$ROOTFS_MNT"
