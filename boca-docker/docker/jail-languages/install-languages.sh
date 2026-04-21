#!/bin/sh
set -e

if [ ! -x /home/bocajail/usr/bin/gcc ] || [ ! -x /home/bocajail/usr/bin/g++ ] || [ ! -x /home/bocajail/usr/bin/kotlinc ]; then
    cp /etc/resolv.conf /home/bocajail/etc/resolv.conf || true
    mkdir -p /home/bocajail/etc/apt/sources.list.d.disabled

    if [ -f /home/bocajail/etc/apt/sources.list.d/icpc-latam-ubuntu-unstable-jammy.list ]; then
        mv /home/bocajail/etc/apt/sources.list.d/icpc-latam-ubuntu-unstable-jammy.list /home/bocajail/etc/apt/sources.list.d.disabled/
    fi

    chroot /home/bocajail apt-get -o Acquire::Retries=2 -o Acquire::http::Timeout=20 -o Acquire::ForceIPv4=true update

    mountpoint -q /home/bocajail/proc || mount -t proc proc /home/bocajail/proc || true

    chroot /home/bocajail apt-get -o Acquire::Retries=2 -o Acquire::http::Timeout=20 -o Acquire::ForceIPv4=true install -y --no-install-recommends build-essential kotlin || true
    chroot /home/bocajail dpkg --configure -a || true

    if mountpoint -q /home/bocajail/proc; then
        umount /home/bocajail/proc || true
    fi

    chroot /home/bocajail apt-get clean || true
    rm -rf /home/bocajail/var/lib/apt/lists/*

    chroot /home/bocajail test -x /usr/bin/gcc
    chroot /home/bocajail test -x /usr/bin/g++
    chroot /home/bocajail test -x /usr/bin/kotlinc
fi

exec /init.sh "$@"
