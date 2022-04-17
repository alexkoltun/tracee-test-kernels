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
  echo -n "VM ERROR: "
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

# run tracee

cd /tracee

info "dynamically compiling tracee for testing image"
if [[ ! -f .check-coretests ]]; then
  make clean > /dev/null 2>&1 # make sure tracee is compiled for qemu img userland
  make all -j8 > /dev/null 2>&1
  touch .check-coretests
else
  make all -j8 > /dev/null 2>&1 # make sure tracee binaries are latest
fi

info "running tracee inside virtualized environment"

cd /tester && ./run-qemu.sh

# vi:syntax=sh:expandtab:smarttab:tabstop=2:shiftwidth=2:softtabstop=2
