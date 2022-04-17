# tracee-test-kernels

This repository is meant to test [https://github.com/aquasecurity/tracee](https://github.com/aquasecurity/tracee) eBPF CO-RE features in multiple kernels. It works by creating a docker container that will receive arguments such as the kernel to run and the test to execute. This container creates a VM (fully emulated or kvm assisted), runs tracee on that VM and starts a docker container, inside created VM, that will simulate the security issue for the requested test.

> This is in the process of being integrated into tracee CI/CD pipeline within github actions.

> It might be used as a standalone tool while developing tracee.

## How to use Tracee Kernel Tester

1. First pull the container image (it is ~1.5 GB because of its internal virtual machine):

```
$ docker image pull rafaeldtinoco/tracee-test-kernels
Using default tag: latest
latest: Pulling from rafaeldtinoco/tracee-test-kernels
34031c10e7d2: Already exists
92e6fecb6269: Pull complete
152b7dc86ebf: Pull complete
4134b811a67d: Pull complete
Digest: sha256:b7f211f5e743f3df2256d9f6ab87ba027acb636edeaaa63836f87124885e353b
Status: Downloaded newer image for rafaeldtinoco/tracee-test-kernels:latest
docker.io/rafaeldtinoco/tracee-test-kernels:latest
```

2. Make sure to provide the correct bind mounts AND environment variables:

1. `-v $(pwd):/tracee:rw` (if you're currently in tracee source directory)
2. `-e kvm_accel=kvm` (or tcg if your environment doesn't support kvm)
3. `-e kern_version=5.10.111-stable` (pick one kernel from the "list-kernels" command)
4. `-e test_name=TRC-7` (pick one test from the "list-tests" command, requires "(1)")

> The tester will re-build your tree with root permissions (clean it with `sudo make clean` if needed)

> The tester will not re-build your entire tree in 2nd, 3rd and subsequent calls (will run `make all` only)

### Listing all available kernels

```
$ docker run --rm --privileged -v $(pwd):/tracee:rw -it rafaeldtinoco/tracee-test-kernels:latest list-kernels
4.19.238-stable
5.10.111-stable
5.11.22-ubuntu
5.13.19-ubuntu
5.15.30-ubuntu
5.15.34-stable
5.16.18-stable
5.4.166-ubuntu+
5.4.189-stable
5.8.18-ubuntu
```

### Listing all available tests

```
$ docker run --rm --privileged -v $(pwd):/tracee:rw -it rafaeldtinoco/tracee-test-kernels:latest list-tests
TRC-10
TRC-11
TRC-12
TRC-14
TRC-2
TRC-3
TRC-4
TRC-5
TRC-7
TRC-8
TRC-9
```

### Running tracee-test-kernels

- Run the kernel tester using:
  - kvm acceleration method: kvm
  - kernel: 5.10.111-stable
  - test_name: TRC-7

```
$ docker run --rm --privileged -v $(pwd):/tracee:rw -e kvm_accel=kvm -e kern_version=5.10.111-stable -e test_name=TRC-7 -it rafaeldtinoco/tracee-test-kernels:latest
ENTRYPOINT: dynamically compiling tracee for testing image
ENTRYPOINT: running tracee inside virtualized environment
VM INFO: pulling aquasec/tracee-tester:latest docker image
latest: Pulling from aquasec/tracee-tester
Digest: sha256:8961d1b0668c22d98e49315fbc2fff66bfbdae93103b3c4097aff99704a4e04b
Status: Image is up to date for aquasec/tracee-tester:latest
docker.io/aquasec/tracee-tester:latest
VM INFO: selected test: TRC-7
VM INFO: running kernel: 5.10.111-stable
Loaded 1 signature(s): [TRC-7]
VM INFO: tracee is up

*** Detection ***
Time: 2022-04-17T10:52:05Z
Signature ID: TRC-7
Signature: LD_PRELOAD
Data: map[]
Command: trc7.sh
Hostname: 87d55a625561

[   14.823858][    T1] reboot: Power down
```

- Run the kernel tester using:
  - kvm acceleration method: kvm
  - kernel: 5.4.166-ubuntu+
  - test_name: TRC-4

```
$ docker run --rm --privileged -v $(pwd):/tracee:rw -e kvm_accel=kvm -e kern_version=5.4.166-ubuntu+ -e test_name=TRC-4 -it rafaeldtinoco/tracee-test-kernels:latest
ENTRYPOINT: dynamically compiling tracee for testing image
ENTRYPOINT: running tracee inside virtualized environment
[    1.253353][  T198] proc: Bad value for 'hidepid'
[    1.256715][  T199] proc: Bad value for 'hidepid'
[    1.422543][  T209] proc: Bad value for 'hidepid'
VM INFO: pulling aquasec/tracee-tester:latest docker image
latest: Pulling from aquasec/tracee-tester
Digest: sha256:8961d1b0668c22d98e49315fbc2fff66bfbdae93103b3c4097aff99704a4e04b
Status: Image is up to date for aquasec/tracee-tester:latest
docker.io/aquasec/tracee-tester:latest
VM INFO: selected test: TRC-4
VM INFO: running kernel: 5.4.166-ubuntu+
Loaded 1 signature(s): [TRC-4]
VM INFO: tracee is up

*** Detection ***
Time: 2022-04-17T10:53:20Z
Signature ID: TRC-4
Signature: Dynamic Code Loading
Data: map[]
Command: packed_ls
Hostname: 0c18cafddca8
[   15.131547][    T1] reboot: Power down
```
