#!/bin/sh
# Restores the saved random seed (if present), then saves a fresh one
# every 60 seconds for the rest of the process lifetime.

SEED_FILE="/var/lib/random-seed"
SEED_SIZE=1024

if [ -f "$SEED_FILE" ]; then
    cat "$SEED_FILE" > /dev/urandom
fi

mkdir -p "$(dirname "$SEED_FILE")"

while true; do
    umask 077
    head -c "$SEED_SIZE" /dev/urandom > "$SEED_FILE.new"
    mv "$SEED_FILE.new" "$SEED_FILE"
    sleep 60
done
