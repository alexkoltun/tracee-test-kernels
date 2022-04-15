#!/bin/bash

# vi:syntax=sh:expandtab:smarttab:tabstop=2:shiftwidth=2:softtabstop=2

## configurable variables

. config

## settings

QEMU_ACCEL=tcg
#QEMU_ACCEL=kvm

## arguments

vmlinuz=$1
initrd=$2

## functions

exit_syntax() {
  echo "syntax:"
  echo "$0 [vmlinuz] [initrd]       or "
  echo "kern_version=X $0"
  exit 1
}

error_syntax() {
  echo -n "ERROR: "
  echo $@
  exit_syntax
}

error_exit() {
  echo -n "ERROR: "
  echo $@
  exit 1
}

check_args() {
  if [[ "$kern_version" != "" ]]; then
    vmlinuz=$(find ./kernels/ -name "vmlinuz-$kern_version*")
    initrd=$(find ./kernels/ -name "initrd.img-$kern_version*")
  fi
  [[ "$vmlinuz" != "" && -f $vmlinuz ]] || error_syntax "vmlinuz: $vmlinux does not exist"
  [[ "$initrd" != "" && -f $initrd ]] || error_syntax "initrd: $initrd does not exist"
  vmlinuz_ver=$(basename $vmlinuz | cut -d '-' -f2)
  initrd_ver=$(basename $initrd | cut -d '-' -f2)
  [[ "$vmlinuz_ver" == "$initrd_ver" ]] || error_exit "vmlinuz and initrd from different versions"
}

## main

[[ "$1" != "-h" && "$1" != "--help" ]] || exit_syntax

# sanity checks
[ $UID -eq 0 ] || error_exit "$0 needs root permissions"
check_args

# run qemu
qemu-system-x86_64 \
  -name guest=$IMG_HOSTNAME \
  -machine accel=$QEMU_ACCEL \
  --cpu max \
  -m 4096 \
  -boot c \
  -display none \
  -serial stdio \
  -kernel $vmlinuz \
  -initrd $initrd \
  -append "root=/dev/vda console=ttyS0 systemd.unified_cgroup_hierarchy=false quiet" \
  -drive file=$IMG_NAME,if=virtio,format=raw \
  -virtfs local,path=$SHARED_DIR,mount_tag=tracee,security_model=passthrough

