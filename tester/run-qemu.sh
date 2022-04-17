#!/bin/bash

##
## RUN QEMU INSIDE DOCKER
## (booting selected kernel in either kvm or tcg emulation mode)
## (will run tracee from /tracee and selected test)
##

# vi:syntax=sh:expandtab:smarttab:tabstop=2:shiftwidth=2:softtabstop=2

## configurable variables

. config

## arguments

kvmaccel=$1
vmlinuz=$2
initrd=$3
testname=$4

## functions

exit_syntax() {
  echo "syntax:"
  echo "$0 [kvm|tcg] [vmlinuz] [initrd] [testname] or "
  echo "kern_version=X test_name=Y kvm_accel=tcg|kvm $0"
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
  if [[ "$kern_version" == "" && "$vmlinuz" == "" ]]; then
    error_syntax "must specify kern_version OR vmlinuz & initrd file"
  fi
  if [[ "$kern_version" == "" && "$initrd" == "" ]]; then
    error_syntax "must specify kern_version OR vmlinuz & initrd file"
  fi
  if [[ "$test_name" != "" && "$testname" == "" ]]; then
    testname=$test_name
  elif [[ "$test_name" == "" && "$testname" == "" ]]; then
    testname=$DEFAULT_TEST # default test to use
  fi
  if [[ "$kvm_accel" == "tcg" || "$kvm_accel" == "kvm" ]]; then
    kvmaccel=$kvm_accel
  else
    error_syntax "kvm_accel must be tcg or kvm"
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
cmdline="root=/dev/vda console=ttyS0 testname=$testname systemd.unified_cgroup_hierarchy=false quiet loglevel=0 systemd.log_level=0 net.ifnames=0"

# run qemu
qemu-system-x86_64 \
  -name guest=$IMG_HOSTNAME \
  -machine accel=$kvmaccel \
  --cpu max \
  -m 4096 \
  -boot c \
  -display none \
  -serial stdio \
  -kernel $vmlinuz \
  -initrd $initrd \
  -append "$cmdline" \
  -netdev user,id=mynet,net=192.168.76.0/24,dhcpstart=192.168.76.9 \
  -device virtio-net-pci,netdev=mynet \
  -drive file=$IMG_NAME,if=virtio,format=$img_format \
  -virtfs local,path=$SHARED_DIR,mount_tag=tracee,security_model=passthrough

