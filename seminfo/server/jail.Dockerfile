ARG BASE=ghcr.io/joaofazolo/boca-docker/boca-jail:latest
FROM ${BASE}
USER root
# Install the toolchains inside the jail; the upstream image may have only
# Python and loose Java binaries, with no host JDK or C/C++ compiler.
# Java's package scripts require /proc, which is available outside the jail
# during a Docker build. Install there, then copy the complete JDK below.
RUN apt-get update \
    && apt-get install -y --no-install-recommends openjdk-17-jdk-headless \
    && apt-get clean
# Use Ubuntu's repositories rather than the optional upstream ICPC PPA.
RUN cp --remove-destination /etc/resolv.conf /home/bocajail/etc/resolv.conf \
    && chroot /home/bocajail apt-get -o Dir::Etc::sourceparts=- update \
    && chroot /home/bocajail /usr/bin/env DEBIAN_FRONTEND=noninteractive \
       apt-get -o Dir::Etc::sourceparts=- install -y --no-install-recommends \
       build-essential python3 \
    && chroot /home/bocajail apt-get clean
# BOCA extracts multi-file submissions before entering the jail.
RUN apt-get update \
    && apt-get install -y --no-install-recommends unzip \
    && apt-get clean
COPY src/ /var/www/boca/src/
COPY tools/ /var/www/boca/tools/
COPY boca-docker/boca/src/private/conf.php /var/www/boca/src/private/conf.php
RUN mkdir -p /home/bocajail/usr/lib/jvm \
    && cp -a /usr/lib/jvm/java-17-openjdk-amd64 /home/bocajail/usr/lib/jvm/ \
    && cp -a /etc/java-17-openjdk /home/bocajail/etc/ \
    && ln -sf /usr/lib/jvm/java-17-openjdk-amd64/bin/java /home/bocajail/usr/bin/java \
    && ln -sf /usr/lib/jvm/java-17-openjdk-amd64/bin/javac /home/bocajail/usr/bin/javac \
    && ln -sf /usr/lib/jvm/java-17-openjdk-amd64/bin/jar /home/bocajail/usr/bin/jar \
    && printf '%s\n' /usr/lib/jvm/java-17-openjdk-amd64/lib /usr/lib/jvm/java-17-openjdk-amd64/lib/server > /home/bocajail/etc/ld.so.conf.d/seminfo-java.conf \
    && chroot /home/bocajail /sbin/ldconfig \
    && chroot /home/bocajail /usr/bin/gcc --version \
    && chroot /home/bocajail /usr/bin/g++ --version \
    && chroot /home/bocajail /usr/bin/python3 --version \
    && chroot /home/bocajail /usr/bin/java -version \
    && chroot /home/bocajail /usr/bin/javac -version \
    && chroot /home/bocajail /usr/bin/jar --version
