#!/bin/bash -e

##
## CREATE DOCKER IMAGE CONTAINING QEMU (qemu img contains all needed kernels)
##

## configurable variables

. config

## functions

error_exit() {
  echo -n "ERROR: "
  echo $@
  exit 1
}

## main

[[ -f $IMG_NAME ]] || error_exit "you have to create the qemu img first"

docker build -f ./tester.dockerfile -t tester:latest .

# vi:syntax=sh:expandtab:smarttab:tabstop=2:shiftwidth=2:softtabstop=2
