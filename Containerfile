FROM docker.io/alpine AS unpack

# Version of the tar archive to download. Updated once per month.
ENV VERSION="2026.01.01"
ENV SHASUM="9040b365657c9c8b209dbb2d17fab578ed14eee62e4f34f8eaa3458b190f44b3"

# Temporary resolv.conf. We set --dns=none so that /etc/resolv.conf doesn't get mounted into the image.
RUN echo -e 'nameserver 1.1.1.1' > /etc/resolv.conf

RUN apk add \
  zstd \
  libarchive-tools \
  curl

RUN curl -fLOJ --retry 3 https://fastly.mirror.pkgbuild.com/iso/$VERSION/archlinux-bootstrap-$VERSION-x86_64.tar.zst
RUN echo "$SHASUM archlinux-bootstrap-$VERSION-x86_64.tar.zst" > sha256sum.txt
RUN sha256sum -c sha256sum.txt || exit 1
RUN bsdtar -xf /archlinux-bootstrap-$VERSION-x86_64.tar.zst -p

# This is where the Arch Linux image actually gets built.
FROM scratch
COPY --from=unpack /root.x86_64/ /

# Temporary resolv.conf. We set --dns=none so that /etc/resolv.conf doesn't get mounted into the image.
RUN echo -e 'nameserver 1.1.1.1' > /etc/resolv.conf

RUN touch /var/log/pacman.log
RUN sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist

# Move everything from `/var` to `/usr/lib/sysimage` so behavior around pacman remains the same on `bootc usroverlay`'d systems
RUN grep "= */var" /etc/pacman.conf | sed "/= *\/var/s/.*=// ; s/ //" | xargs -n1 sh -c 'mkdir -p "/usr/lib/sysimage/$(dirname $(echo $1 | sed "s@/var/@@"))" && mv -v "$1" "/usr/lib/sysimage/$(echo "$1" | sed "s@/var/@@")"' '' && \
    sed -i -e "/= *\/var/ s/^#//" -e "s@= */var@= /usr/lib/sysimage@g" -e "/DownloadUser/d" /etc/pacman.conf

RUN pacman-key --init && \
    pacman-key --populate && \
    pacman -Syu --noconfirm

# Install bootc from my repository (https://github.com/hecknt/arch-bootc-pkgs)
RUN pacman-key --recv-key 5DE6BF3EBC86402E7A5C5D241FA48C960F9604CB --keyserver keyserver.ubuntu.com && \
    pacman-key --lsign-key 5DE6BF3EBC86402E7A5C5D241FA48C960F9604CB && \
    echo -e '[bootc]\nSigLevel = Required\nServer=https://github.com/hecknt/arch-bootc-pkgs/releases/download/$repo' >> /etc/pacman.conf

RUN pacman -Sy --noconfirm --needed base dracut linux linux-firmware ostree btrfs-progs e2fsprogs xfsprogs dosfstools skopeo dbus dbus-glib glib2 ostree shadow bootc && pacman -S --clean --noconfirm

# https://github.com/bootc-dev/bootc/issues/1801
RUN printf "systemdsystemconfdir=/etc/systemd/system\nsystemdsystemunitdir=/usr/lib/systemd/system\n" | tee /usr/lib/dracut/dracut.conf.d/30-bootcrew-fix-bootc-module.conf && \
    printf 'reproducible=yes\nhostonly=no\ncompress=zstd\nadd_dracutmodules+=" ostree bootc "' | tee "/usr/lib/dracut/dracut.conf.d/30-bootcrew-bootc-container-build.conf" && \
    dracut --force "$(find /usr/lib/modules -maxdepth 1 -type d | grep -v -E "*.img" | tail -n 1)/initramfs.img"

# Necessary for general behavior expected by image-based systems
RUN sed -i 's|^HOME=.*|HOME=/var/home|' "/etc/default/useradd" && \
    rm -rf /mnt /boot /home /root /usr/local /srv /var /usr/lib/sysimage/log /usr/lib/sysimage/cache/pacman/pkg && \
    mkdir -p /sysroot /boot /usr/lib/ostree /var && \
    ln -s sysroot/ostree /ostree && ln -s var/roothome /root && ln -s var/srv /srv && ln -s var/opt /opt && ln -s var/mnt /mnt && ln -s var/home /home && \
    echo "$(for dir in opt home srv mnt usrlocal ; do echo "d /var/$dir 0755 root root -" ; done)" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf" && \
    printf "d /var/roothome 0700 root root -\nd /run/media 0755 root root -" | tee -a "/usr/lib/tmpfiles.d/bootc-base-dirs.conf" && \
    printf '[composefs]\nenabled = yes\n[sysroot]\nreadonly = true\n' | tee "/usr/lib/ostree/prepare-root.conf"

# Setup a temporary root passwd (changeme) for dev purposes
# RUN pacman -S whois --noconfirm
# RUN usermod -p "$(echo "changeme" | mkpasswd -s)" root

# https://bootc-dev.github.io/bootc/bootc-images.html#standard-metadata-for-bootc-compatible-images
LABEL containers.bootc 1

RUN bootc container lint
