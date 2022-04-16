#!/bin/bash -e

## functions

info() {
  echo -n "ENTRYPOINT: "
  echo "$@"
}

## main

# list available kernels (to be given as arguments) instead of running tracee

if [[ "$1" == "list-kernels" ]]; then
  kernel_list=$(find /tester/kernels/*vmlinuz* | xargs)
  for k in $kernel_list; do
    basename $k | sed 's:vmlinuz-::g'
  done
  exit
fi

# same, but listing tests now

if [[ "$1" == "list-tests" ]]; then
  test_list=$(find /tracee/tests/tracee-tester/*.sh | xargs)
  for k in $test_list; do
    basename $k
  done
  exit
fi

# run tracee

cd /tracee

if [[ ! -f .check-coretests ]]; then
  info "dynamically compiling tracee for tester userland"
  make clean > /dev/null 2>&1
  make all -j8 > /dev/null 2>&1
  touch .check-coretests
fi

info "running tracee inside virtualized environment"

cd /tester && ./run-qemu.sh

# vi:syntax=sh:expandtab:smarttab:tabstop=2:shiftwidth=2:softtabstop=2
