FROM ghcr.io/joaofazolo/boca-docker/boca-jail:latest

USER root

RUN cp /etc/resolv.conf /home/bocajail/etc/resolv.conf \
    && mkdir -p /home/bocajail/etc/apt/sources.list.d.disabled \
    && if [ -f /home/bocajail/etc/apt/sources.list.d/icpc-latam-ubuntu-unstable-jammy.list ]; then \
        mv /home/bocajail/etc/apt/sources.list.d/icpc-latam-ubuntu-unstable-jammy.list /home/bocajail/etc/apt/sources.list.d.disabled/; \
    fi \
    && chroot /home/bocajail apt-get -o Acquire::Retries=2 -o Acquire::http::Timeout=20 -o Acquire::ForceIPv4=true update \
    && (mountpoint -q /home/bocajail/proc || mount -t proc proc /home/bocajail/proc) \
    && (chroot /home/bocajail apt-get -o Acquire::Retries=2 -o Acquire::http::Timeout=20 -o Acquire::ForceIPv4=true install -y --no-install-recommends build-essential kotlin || true) \
    && chroot /home/bocajail dpkg --configure -a \
    && umount /home/bocajail/proc \
    && chroot /home/bocajail apt-get clean \
    && rm -rf /home/bocajail/var/lib/apt/lists/* \
    && chroot /home/bocajail test -x /usr/bin/gcc \
    && chroot /home/bocajail test -x /usr/bin/g++ \
    && chroot /home/bocajail test -x /usr/bin/kotlinc
