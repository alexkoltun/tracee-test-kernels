#!/bin/bash

##
## CREATE QEMU IMG (able to run alle existing kernels, tracee and docker containers)
##

## configurable variables

. config

## functions

error_exit() {
  echo -n "ERROR: "
  echo $@
  exit 1
}

create_tmpdir() {
  cd /tmp
  tmpdir=/tmp/$(mktemp -d XXXXXX)
  cd - >/dev/null 2>&1
  [ "$tmpdir" != "" ] || error_exit "tmpdir is empty"
}

remove_tmpdir() {
  rmdir $tmpdir
}

bootstrap_ubuntu() {
  # relying in specific ubuntu version (because of toolchain versioning)
  repository="http:/$APT_CACHER/archive.ubuntu.com/ubuntu/"
  components="main,restricted,universe,multiverse"
  packages="locales,ifupdown"
  arch=$(dpkg-architecture -qDEB_HOST_ARCH || error_exit "arch")
  distro=impish

  debootstrap \
    --components=$components \
    --include="$packages" \
    --arch="$arch" \
    $distro \
    $tmpdir \
    "$repository" || error_exit "bootstrap"
}

bootstrap_mount() {
  mount -o bind /proc $tmpdir/proc
  mount -o bind /sys $tmpdir/sys
  mount -o bind /dev $tmpdir/dev
  mount -o bind /dev/pts $tmpdir/dev/pts
}

bootstrap_umount() {
  umount $tmpdir/dev/pts
  umount $tmpdir/dev
  umount $tmpdir/sys
  umount $tmpdir/proc
}

bootstrap_run() {
  chroot $tmpdir /bin/bash -c "$1"
}

bootstrap_create_files() {

echo "/dev/vda / ext4 errors=remount-ro 0 1" \
| tee $tmpdir/etc/fstab

#--

echo """auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
""" \
| tee $tmpdir/etc/network/interfaces

#--

echo """virtio_balloon
virtio_blk
virtio_net
virtio_pci
virtio_ring
virtio
ext4
""" \
| tee $tmpdir/etc/modules

#--

echo > $tmpdir/etc/motd
echo > $tmpdir/etc/issue
echo > $tmpdir/etc/issue.net

#--

mkdir -p $tmpdir/tracee
mkdir -p $tmpdir/etc/systemd/system/serial-getty@ttyS0.service.d/
echo """[Service]
User=root
Environment=HOME=/
WorkingDirectory=/
ExecStart=
ExecStart=-/init
StandardInput=tty
StandardOutput=tty
Restart=always
[Install]
WantedBy=getty.target
""" \
| tee $tmpdir/etc/systemd/system/serial-getty@ttyS0.service.d/override.conf

#--

cp ./qemu-entrypoint.sh $tmpdir/init || error_exit "could not copy qemu-entrypoint into temp dir"
chmod +x $tmpdir/init

#--

echo """# ubuntu
deb http://archive.ubuntu.com/ubuntu $distro main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu $distro-updates main restricted universe multiverse
# docker
deb [trusted=yes] https://download.docker.com/linux/ubuntu $distro stable
""" \
| tee $tmpdir/etc/apt/sources.list

}


bootstrap_create_files_late() {

mkdir -p $tmpdir/etc/docker
echo """{
  \"storage-driver\": \"overlay2\"
}""" \
| tee $tmpdir/etc/docker/daemon.json

}

## cleanup

cleanup() {
  if [ "$tmpdir" != "" ]; then
    bootstrap_umount
    umount $tmpdir
    remove_tmpdir
  fi

  if [[ $finished -eq 1 && $COMPRESS -eq 1 ]]; then
    echo "compressing img into qcow2"
    qemu-img convert -c -O qcow2 $IMG_NAME temp
    mv temp $IMG_NAME
  fi
}

## main

[ $UID -eq 0 ] || error_exit "$0 needs root permissions"

trap cleanup EXIT

# sanity check
if [[ $INSTALL_LINUX -eq 1 ]]; then
  [ ! -f $IMG_NAME ] || error_exit "$IMG_NAME already exists"
fi

# sanity check
if [[ $INSTALL_KERNEL -eq 1 ]]; then
  if [[ "$(ls -1 ./kernels/ | wc -l)" == "0" ]]; then
    error_exit "remove files from kernels/ before"
  fi
fi

# create loopback filesystem
if [[ $INSTALL_LINUX -eq 1 ]]; then
  # create the loopback file for the ext4 filesystem
  truncate -s $IMG_SIZE $IMG_NAME
  # create ext4 filesystem
  mkfs.ext4 $IMG_NAME
fi # INSTALL_LINUX

# create temp bootstrap dir
create_tmpdir

# mount ext4 filesystem into temp bootstrap dir
mount $IMG_NAME $tmpdir || error_exit "could not mount $IMG_NAME"

# bootstrap ubuntu
[[ $INSTALL_LINUX -eq 1 ]] && bootstrap_ubuntu

# bootstrap mount
bootstrap_mount

# adjust hostname
echo $IMG_HOSTNAME | tee "$tmpdir/etc/hostname"

# adjust locales
bootstrap_run "echo en_US.UTF-8 > /etc/locale.gen"
bootstrap_run "locale-gen \"en_US.UTF-8\""

# remove root password
bootstrap_run "passwd -d root"

if [[ $INSTALL_FILES -eq 1 ]]; then
  # create needed files
  bootstrap_create_files
fi

if [[ $INSTALL_PKGS -eq 1 ]]; then
  # customize image
  prefix="DEBIAN_FRONTEND=noninteractive"
  bootstrap_run "$prefix apt-get update"
  bootstrap_run "$prefix apt-get dist-upgrade -y"
  bootstrap_run "$prefix apt-get -y install --no-install-recommends debconf"
  bootstrap_run "echo debconf debconf/priority select low | debconf-set-selections"
  bootstrap_run "$prefix dpkg-reconfigure debconf"
  bootstrap_run "$prefix apt-get -y install --no-install-recommends tzdata"
  bootstrap_run "$prefix dpkg-reconfigure tzdata"
  bootstrap_run "$prefix apt-get -y install --no-install-recommends linux-headers-generic"
  bootstrap_run "$prefix apt-get -y install --no-install-recommends initramfs-tools"
  bootstrap_run "$prefix apt-get -y install --no-install-recommends bash-completion"
  bootstrap_run "$prefix apt-get -y install --no-install-recommends ca-certificates"
  bootstrap_run "$prefix apt-get -y install --no-install-recommends curl ncat"
  # (https://github.com/aquasecurity/tracee/tree/main/tests/tracee-tester) dependencies
  #bootstrap_run "$prefix apt-get -y install --no-install-recommends strace"
  #bootstrap_run "$prefix apt-get -y install --no-install-recommends ncat gcc"
  #bootstrap_run "$prefix apt-get -y install --no-install-recommends upx"
  #bootstrap_run "$prefix apt-get -y install --no-install-recommends python2"
  # docker repository
  bootstrap_run "$prefix apt-get -y install --no-install-recommends docker-ce docker-ce-cli containerd.io"
  # clean cache
  bootstrap_run "$prefix apt-get --purge autoremove -y"
  bootstrap_run "$prefix apt-get autoclean"
fi

if [[ $INSTALL_FILES -eq 1 ]]; then
  # create needed files (after pkg installation)
  bootstrap_create_files_late
fi

if [[ $INSTALL_KERNELS -eq 1 ]]; then
  bootstrap_run "sed -Ei 's:COMPRESS=.*:COMPRESS=gzip:g' /etc/initramfs-tools/initramfs.conf"
  # install available kernels
  mkdir -p $tmpdir/temp || error_exit "could not create temp dir"
  # files=$(find ../ ! -name *dbg* ! -name *libc* -name *.deb | xargs) # original
  files=$(find ../ ! -name *dbg* ! -name *libc* -name *ubuntu*.deb | xargs) # debug
  cp $files $tmpdir/temp || error_exit "could not copy $files into temp dir"
  bootstrap_run "$prefix dpkg -i /temp/*.deb"
  rm -rf $tmpdir/temp
  # organize existing btf files
  rm -f ./kernels/*.btf
  files=$(find ../ -name *.btf | xargs)
  cp -f $files ./kernels || error_exit "could not copy $files into ./kernels"
  # update-initramfs
  bootstrap_run "update-initramfs -k all -c"
  # bring installed kernel files to outside
  cp $tmpdir/boot/*initrd.img* ./kernels/
  cp $tmpdir/boot/*vmlinuz* ./kernels/
  # take existing btf files inside the image
  cp ./kernels/*.btf $tmpdir/boot/
fi # INSTALL_KERNELS

finished=1

# debug
#bootstrap_run "bash"

# vi:syntax=sh:expandtab:smarttab:tabstop=2:shiftwidth=2:softtabstop=2
