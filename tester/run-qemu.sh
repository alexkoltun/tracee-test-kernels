#!/bin/bash

# vi:syntax=sh:expandtab:smarttab:tabstop=2:shiftwidth=2:softtabstop=2

## configurable variables

. config

## arguments

vmlinuz=$1
initrd=$2
testname=$3

## functions

exit_syntax() {
  echo "syntax:"
  echo "$0 [vmlinuz] [initrd] [testname] or "
  echo "kern_version=X test_name=Y $0"
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
  if [[ "$test_name" != "" && "$testname" == "" ]]; then
    testname=$test_name
  elif [[ "$test_name" == "" && "$testname" == "" ]]; then
    testname=$DEFAULT_TEST # default test to use
  fi
  [[ "$vmlinuz" != "" && -f $vmlinuz ]] || error_syntax "vmlinuz: $vmlinux does not exist"
  [[ "$initrd" != "" && -f $initrd ]] || error_syntax "initrd: $initrd does not exist"
  vmlinuz_ver=$(basename $vmlinuz | sed 's:vmlinuz-::g')
  initrd_ver=$(basename $initrd | sed 's:initrd.img-::g')
  [[ "$vmlinuz_ver" == "$initrd_ver" ]] || error_exit "vmlinuz and initrd from different versions"
}

## main

[[ "$1" != "-h" && "$1" != "--help" ]] || exit_syntax

# sanity checks
[ $UID -eq 0 ] || error_exit "$0 needs root permissions"
check_args

img_format=raw
if [ $COMPRESS -eq 1 ]; then
  img_format=qcow2
fi

# kernel cmdline
cmdline="root=/dev/vda console=ttyS0 testname=$testname systemd.unified_cgroup_hierarchy=false quiet loglevel=0 systemd.log_level=0 vt.global_cursor_default=0"

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
  -append "$cmdline" \
  -drive file=$IMG_NAME,if=virtio,format=$img_format \
  -virtfs local,path=$SHARED_DIR,mount_tag=tracee,security_model=passthrough

