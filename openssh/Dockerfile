# Multi-stage build: First the full builder image:

# Default location where all binaries wind up:
ARG INSTALL_DIR=/opt/oqssa

# liboqs build defines (https://github.com/open-quantum-safe/liboqs/wiki/Customizing-liboqs)
ARG LIBOQS_BUILD_DEFINES=

# openssh build defines (https://github.com/open-quantum-safe/openssh#step-2-build-the-fork)
ARG OPENSSH_BUILD_OPTIONS=

# Define the degree of parallelism when building the image; leave the number away only if you know what you are doing
ARG MAKE_DEFINES="-j2"

# Define the username of the normal user
ARG OQS_USER="oqs"
ARG OQS_PASSWORD="oqs.pw"

FROM alpine:3.11 as intermediate
# Take in all global args
ARG INSTALL_DIR
ARG LIBOQS_BUILD_DEFINES
ARG OPENSSH_BUILD_OPTIONS
ARG MAKE_DEFINES
ARG OQS_USER

LABEL version="2"

ENV DEBIAN_FRONTEND noninteractive

RUN apk update && apk upgrade

# Get all software packages required for builing all components:
# Note: build-base cannot be used due to the fortify-headers package throwing an error
RUN apk add gcc musl-dev linux-headers \
            libtool automake autoconf cmake \
            make \
            openssl openssl-dev \
            git docker \
            zlib-dev

# get all sources
WORKDIR /opt
RUN git clone --depth 1 --branch 0.4.0 https://github.com/open-quantum-safe/liboqs && \
    git clone --depth 1 --branch OQS-OpenSSH-snapshot-2020-08 https://github.com/open-quantum-safe/openssh ossh-src;

# build liboqs static (does not work with shared lib!)
WORKDIR /opt/liboqs
# RUN mkdir build && cd build && cmake .. ${LIBOQS_BUILD_DEFINES} -DBUILD_SHARED_LIBS=ON -DCMAKE_INSTALL_PREFIX=/opt/ossh-src/oqs && make ${MAKE_DEFINES} && make install
RUN mkdir build-static && cd build-static && cmake .. ${LIBOQS_BUILD_DEFINES} -DCMAKE_BUILD_TYPE=${LIBOQS_BUILD_TYPE} -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=/opt/ossh-src/oqs && make ${MAKE_DEFINES} && make install

# build OQS-OpenSSH, this will automatically generate host keys for all SIG algorithms
WORKDIR /opt/ossh-src
RUN autoreconf && ./configure \
    --with-libs=-lm \
    --prefix=${INSTALL_DIR} \
    --sysconfdir=${INSTALL_DIR} \
    --with-liboqs-dir=/opt/ossh-src/oqs \
    --with-mantype=man \
    ${OPENSSH_BUILD_OPTIONS}
RUN make ${MAKE_DEFINES} && \
    make install-nokeys

CMD ["sh"]
STOPSIGNAL SIGTERM

## second stage: Only create minimal image without build tooling and intermediateUSER root build results generated above:
FROM alpine:3.11 as dev
# Take in all global args
ARG INSTALL_DIR
ARG OQS_USER
ARG OQS_PASSWORD

RUN apk update \
    && apk upgrade \
    && apk add man bash

# Only retain the ${INSTALL_DIR} contents in the final image
COPY --from=intermediate ${INSTALL_DIR} ${INSTALL_DIR}

# Create a normal user to be able to log into the system via ssh
RUN addgroup --gid 1000 --system ${OQS_USER} && adduser --uid 1000 --system ${OQS_USER} --ingroup ${OQS_USER} --shell /bin/sh && echo -e -e "${OQS_PASSWORD}\n${OQS_PASSWORD}" | passwd ${OQS_USER}

# Set up login shell: Add ssh-binaries to path for ssh login shell, fix /etc/profile not executing /etc/profile.d/*
RUN sed -i "s|PATH=|PATH=${INSTALL_DIR}/bin:|;s|/etc/profile.d/\*\.sh|/etc/profile.d/\*|" /etc/profile

# Create identity file for $OQS_USER and add public key to $OQS_USER's authorized keys for a localhost connection
WORKDIR /home/${OQS_USER}/.ssh
RUN chown ${OQS_USER}:${OQS_USER} .

# Pass some potentionally useful variables to environment
ENV OQS_INSTALL_DIR=${INSTALL_DIR}
ENV OQS_USER=$OQS_USER

# Enable ssh deamon to start at boot
COPY sshd /etc/init.d/
RUN apk add openrc \
    && mkdir -p /run/openrc \
    && touch /run/openrc/softlevel \
    && rc-update add sshd \
    && rc-status

# Fix error "/lib/rc/sh/openrc-run.sh: line 100: can't create /sys/fs/cgroup/*/*: Read-only file system"
RUN sed -ri '269 s/cgroup_add_service/#cgroup_add_service/' /lib/rc/sh/openrc-run.sh

# Copy scripts
COPY sshd_config ${INSTALL_DIR}
COPY ssh_config ${INSTALL_DIR}
COPY serverstart.sh ${INSTALL_DIR}/test/
COPY connect-test.sh ${INSTALL_DIR}/test/
COPY key-regen.sh ${INSTALL_DIR}/scripts/

# set path to use 'new' openssh
ENV PATH="${INSTALL_DIR}/bin:${PATH}"
ENV PATH="${INSTALL_DIR}/test:${PATH}"
ENV PATH="${INSTALL_DIR}/scripts:${PATH}"

STOPSIGNAL SIGTERM

# Expose port 2222 as this is the chosen ssh port for oqs-ssh
EXPOSE 2222

# Re-generate the host keys and start a shell
WORKDIR /home/${OQS_USER}/
CMD ["sh", "-c", "RESTART_SSHD=yes key-regen.sh; /bin/sh"]