#!/bin/bash -e

## functions

info() {
  echo -n "ENTRYPOINT: "
  echo "$@"
}

## main

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
