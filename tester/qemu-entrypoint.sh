#!/bin/bash -e

##
## QEMU BOOTS LINUX, EXECUTES THIS AND SHUTSDOWN
##

## functions

info() {
  echo -n "VM INFO: "
  echo $@
}

error_exit() {
  echo -n "VM ERROR: "
  echo $@
  exit 1
}

endhook() {
  # umount 9p filesystem
  /bin/umount -f /tracee > /dev/null 2>&1 || true
  /sbin/shutdown -h now
}

cleanup() {
  endhook
}

beginhook() {
  dmesg --console-off
  trap cleanup EXIT
  # mount 9p tracee filesystem into /tracee
  sleep 1 # this is needed for very quick boots orelse mount might fail due to 9p modules
  /bin/mount -t 9p -o trans=virtio,msize=104857600 tracee /tracee
}

## main

# begin hook
beginhook

# prepare test dependencies
# test_dependencies

# debug1
#/bin/bash
#exit

# prepare for tests

rm -rf /tracee-tester

info "pulling aquasec/tracee-tester:latest docker image"
docker image pull aquasec/tracee-tester:latest

# check given testname
testname=$(cat /proc/cmdline | sed 's: :\n:g' | grep testname | cut -d'=' -f2)

info "selected test: $testname"

# some kernels might need external BTF files

kern_version=$(uname -r | cut -d'-' -f1 | cut -d'.' -f1,2)

if [ "$kern_version" == "4.19" ]; then
  if [ -f /boot/$(uname -r).btf ]; then
  export TRACEE_BTF_FILE=/boot/$(uname -r).btf
  fi
fi

info "running kernel: $(uname -r)"

# prepare for tracee

rm -rf /tmp/tracee/*
cd /tracee

if [[ ! -x ./dist/tracee-ebpf || ! -x ./dist/tracee-rules ]]; then
  error_exit "could not find tracee executables"
fi

events=$(./dist/tracee-rules --rules $testname --list-events)

# start tracee-ebpf & tracee-rules

./dist/tracee-ebpf \
  -o format:gob \
  -o option:parse-arguments \
  -o option:detect-syscall \
  -trace event=$events \
  | \
./dist/tracee-rules \
  --input-tracee=file:stdin \
  --input-tracee format:gob \
  --rules $testname &

# debug2
#bash
#exit

# wait tracee-ebpf to be started (30 sec most)

times=0
while true; do
  times=$(($times + 1))
  sleep 1
  if [[ -f /tmp/tracee/out/tracee.pid ]]; then
    info "tracee is up"
    break
  fi
  if [[ $times -gt 30 ]]; then
    error_exit "time out waiting for tracee initialization"
  fi
done

# run testname script/binary (according to given argument from /proc/cmdline)

docker run --rm aquasec/tracee-tester $testname > /dev/null 2>&1

# give it 5 seconds so event can be processed
sleep 5

# cleanup (avoid pipe write errors and things alike)
exec 0<&-
exec 1<&-
exec 2<&-

pkill tracee-rules
pkill tracee-ebpf

## end hook executed by EXIT trap

exit

# vi:syntax=sh:expandtab:smarttab:tabstop=2:shiftwidth=2:softtabstop=2
