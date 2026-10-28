ARG UBUNTU_VERSION=20.04
FROM ubuntu:${UBUNTU_VERSION}
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
# Package names differ between Ubuntu releases, so install only those this release provides.
RUN pkgs=' \
  bash ca-certificates sudo curl wget usbutils udev python3 python3-distutils \
  python3-pip python-is-python3 python3-yaml python3-pexpect \
  tar bzip2 lbzip2 xz-utils gzip zip unzip file binutils \
  openssl device-tree-compiler libxml2-utils lz4 liblz4-tool \
  qemu-user-static binfmt-support e2fsprogs dosfstools \
  parted gdisk util-linux kmod rsync cpio bc xxd \
  abootimg cpp uuid-runtime zstd sshpass whois openssh-client perl \
  iproute2 iputils-ping' \
  && apt-get update \
  && apt-get install -y --no-install-recommends \
     $(for p in $pkgs; do apt-cache show "$p" >/dev/null 2>&1 && echo "$p"; done) \
  && rm -rf /var/lib/apt/lists/*
WORKDIR /workspace
CMD ["/bin/bash"]
