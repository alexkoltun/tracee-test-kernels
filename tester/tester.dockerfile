FROM ubuntu:impish

# install needed environment

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get dist-upgrade -y && \
    apt-get install -y --no-install-recommends coreutils findutils && \
    apt-get install -y --no-install-recommends bash git curl rsync && \
    apt-get install -y --no-install-recommends strace && \
    apt-get install -y --no-install-recommends ssl-cert ca-certificates && \
    apt-get install -y --no-install-recommends pkg-config && \
    apt-get install -y --no-install-recommends llvm clang golang make gcc && \
    apt-get install -y --no-install-recommends linux-headers-generic && \
    apt-get install -y --no-install-recommends qemu-system-x86 && \
    apt-get install -y --no-install-recommends libelf-dev && \
    apt-get install -y --no-install-recommends zlib1g-dev && \
    curl -L -o /usr/bin/opa https://github.com/open-policy-agent/opa/releases/download/v0.35.0/opa_linux_amd64_static && \
    chmod 755 /usr/bin/opa

RUN mkdir -p /tracee && \
    mkdir -p /tester && \
    rm -f /root/.profile && \
    rm -f /root/.bashrc && \
    echo "export PS1=\"\u@\h[\w]$ \"" > /root/.bashrc && \
    echo "alias ls=\"ls --color\"" >> /root/.bashrc && \
    ln -s /root/.bashrc /root/.profile && \
    git config --global --add safe.directory /tracee

COPY . /tester/

ENTRYPOINT ["/tester/entrypoint.sh"]

USER root
ENV HOME /root
WORKDIR /tracee
