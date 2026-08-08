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

guestunmount "$ROOTFS_MNT"
