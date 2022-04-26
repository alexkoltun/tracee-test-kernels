#!/bin/bash -e

##
## DOCKER IMAGE ENTRY POINT (executing qemu at the end)
##

## functions

info() {
  echo -n "ENTRYPOINT: "
  echo "$@"
}

error_exit() {
  echo -n "ENTRYPOINT ERROR: "
  echo $@
  exit 1
}

## main

# list available kernels (to be given as arguments) instead of running tracee

if [[ "$1" == "list-kernels" ]]; then
  kernel_list=$(find /tester/kernels/*vmlinuz* | sort | xargs)
  for k in $kernel_list; do
    basename $k | sed 's:vmlinuz-::g'
  done
  exit
fi

# list available tests (from shared tracee src tree) instead of running tracee

if [[ "$1" == "list-tests" ]]; then
  if [[ ! -d /tracee/tests ]]; then
    error_exit "/tracee does not seem to be mounted"
  fi
  for test in $(find /tracee/tests/tracee-tester -name trc*.sh -exec basename {} \;); do
    echo ${test/\.sh/};
  done | sed 's:trc:TRC-:g' | sort
  exit
fi

# cleanup

cleanup() {
  cat /tmp/qemu.log | sed 's:::g'

  found=0
  cat /tmp/qemu.log | grep "Signature ID: $test_name" -B2 | head -3 | grep -q "\*\*\* Detection" && found=1
  if [[ $found -eq 1 ]]; then
    echo "TEST: SUCCESS"
    exit 0
  else
    echo "TEST: FAILED"
    exit 1
  fi
}

# trap exit

echo > /tmp/qemu.log

trap cleanup EXIT

# check if given kernel exists

kfound=0
kernel_list=$(find /tester/kernels/*vmlinuz* | sort | xargs)
for k in $kernel_list; do
  kname=$(basename $k | sed 's:vmlinuz-::g')
  if [[ "$kern_version" == "$kname" ]]; then
    kfound=1
  fi
done

if [[ $kfound -eq 0 ]]; then
  error_exit "could not find kernel $kern_version"
fi

# run tracee inside qemu virtual machine

cd /tracee

if [[ ! -d ./3rdparty ]]; then
  error_exit "/trace directory doesn't seem to be tracee source directory"
fi

info "dynamically compiling tracee for testing image"
if [[ ! -f .check-coretests ]]; then
  make clean > /dev/null 2>&1 # make sure tracee is compiled for qemu img userland
  make all -j8 > /dev/null 2>&1
  touch .check-coretests
else
  make all -j8 > /dev/null 2>&1 # make sure tracee binaries are latest
fi

cd /tester || error_exit "could not enter /tester directory"

info "running tracee inside virtualized environment"
info "(will take time: output is only printed at the end of each test)"

# check if test was successful
#
# example:
#
#   *** Detection ***
#   Time: 2022-04-22T20:26:52Z
#   Signature ID: TRC-4
#   Signature: Dynamic Code Loading
#   Data: map[]
#   Command: packed_ls
#   Hostname: 508e2630653b

./run-qemu.sh 2>&1 > /tmp/qemu.log 2>&1

# vi:syntax=sh:expandtab:smarttab:tabstop=2:shiftwidth=2:softtabstop=2
