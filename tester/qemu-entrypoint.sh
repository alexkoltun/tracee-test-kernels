#!/bin/bash -e

## functions

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
  #trap -- '' PIPE
  #trap -- '' BUS
  # mount 9p tracee filesystem into /tracee
  sleep 1 # this is needed for very quick boots orelse mount might fail due to 9p modules
  /bin/mount -t 9p -o trans=virtio,msize=104857600 tracee /tracee
}

test_dependencies() {
  # placed here because some dirs are not be available during img creation
  mkdir -p "/var/run/secrets/kubernetes.io/serviceaccount"
  mkdir -p "/etc/kubernetes/pki"
  echo test | tee "/var/run/secrets/kubernetes.io/serviceaccount/token" > /dev/null 2>&1
  echo test | tee "/etc/kubernetes/pki/token" > /dev/null 2>&1
  echo test | tee "/authorized_keys" > /dev/null 2>&1
}

## main

# begin hook
beginhook

# prepare test dependencies
test_dependencies

# uname
uname -a

# debug
#bash
#exit

# prepare for tests

rm -rf /tracee-tester
mkdir -p /tracee-tester
cp /tracee/tests/tracee-tester/* /tracee-tester
cd /tracee-tester
chmod +x *

# check given testname
testname=$(cat /proc/cmdline | sed 's: :\n:g' | grep testname | cut -d'=' -f2)

if [[ ! -x /tracee-tester/$testname ]]; then
  error_exit "test file '$testname' was not found"
fi

# some kernels might need external BTF files

kern_version=$(uname -r | cut -d'-' -f1 | cut -d'.' -f1,2)

if [ "$kern_version" == "4.19" ]; then
  if [ -f /boot/$(uname -r).btf ]; then
  export TRACEE_BTF_FILE=/boot/$(uname -r).btf
  fi
fi

# prepare for tracee

rm -rf /tmp/tracee/*
cd /tracee

if [[ ! -x ./dist/tracee-ebpf || ! -x ./dist/tracee-rules ]]; then
  error_exit "could not find tracee executables"
fi

events=$(./dist/tracee-rules --list-events)

# start tracee-ebpf & tracee-rules

./dist/tracee-ebpf \
  -o format:json \
  -o option:parse-arguments \
  -o option:detect-syscall \
  -trace event=$events \
  | \
./dist/tracee-rules \
  --input-tracee=file:stdin \
  --input-tracee format:json &

# wait tracee-ebpf to be started (30 sec most)

times=0
while true; do
  times=$(($times + 1))
  sleep 1 && [[ -f /tmp/tracee/out/tracee.pid ]] && break
  if [[ $times -gt 30 ]]; then
	  break
  fi
done

# run testname script/binary (according to given argument from /proc/cmdline)

cd /tracee-tester
./$testname > /dev/null 2>&1

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
