# Multi-stage build: First the full builder image:

# Default location where all binaries wind up:
ARG INSTALLDIR=/opt/oqssa

# liboqs build defines (https://github.com/open-quantum-safe/liboqs/wiki/Customizing-liboqs)
ARG LIBOQS_BUILD_DEFINES=

# Default id and host key algorithm; can be set to any listed at https://github.com/open-quantum-safe/openssh#digital-signature
ARG SIG="p256-dilithium2"

# Define the degree of parallelism when building the image; leave the number away only if you know what you are doing
ARG MAKE_DEFINES="-j 2"

# Define the username of the normal user
ARG USER="oqs"
ARG PASSWORD="oqs.pw"

FROM alpine:3.11 as intermediate
# Take in all global args
ARG INSTALLDIR
ARG LIBOQS_BUILD_DEFINES
ARG OPENSSH_BUILD_DEFINES
ARG SIG
ARG MAKE_DEFINES
ARG USER

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
RUN autoreconf && ./configure --with-libs=-lm --prefix=${INSTALLDIR} --sysconfdir=${INSTALLDIR} --with-liboqs-dir=/opt/ossh-src/oqs && make ${MAKE_DEFINES} && make install

# set path to use 'new' openssh. Dyn libs have been properly linked in to match
ENV PATH="${INSTALLDIR}/bin:${PATH}"
ENV PATH="${INSTALLDIR}/sbin:${PATH}"
ENV PATH="${INSTALLDIR}:${PATH}"

# Create a normal user to be able to log into the system via ssh
RUN addgroup --gid 1000 --system ${USER} && adduser --uid 1000 --system ${USER} --ingroup ${USER} --shell /bin/sh && passwd -d ${USER}

# Create identity file for $USER and add public key to $USER's authorized keys for a localhost connection
WORKDIR /home/${USER}/.ssh
RUN chown ${USER}:${USER} .
USER ${USER}
RUN chmod 700 . && ${INSTALLDIR}/bin/ssh-keygen -t ssh-${SIG} -f id_${SIG//-/_} -N "" -q && cat id_${SIG//-/_}.pub > authorized_keys && chmod 600 authorized_keys

USER root   
# WORKDIR ${INSTALLDIR}/test
# ENV PATH="${INSTALLDIR}/test:${PATH}"

# CMD [ "serverstart.sh" ]
# STOPSIGNAL SIGTERM



## second stage: Only create minimal image without build tooling and intermediate build results generated above:
FROM alpine:3.11 as dev
# Take in all global args
ARG INSTALLDIR
ARG USER
ARG PASSWORD
ARG SIG

RUN apk update \
    && apk upgrade \
    && apk add bash

# Only retain the ${INSTALLDIR} contents in the final image
COPY --from=intermediate ${INSTALLDIR} ${INSTALLDIR}

# Create a normal user to be able to log into the system via ssh
RUN addgroup --gid 1000 --system ${USER} && adduser --uid 1000 --system ${USER} --ingroup ${USER} --shell /bin/sh && echo -e -e "${PASSWORD}\n${PASSWORD}" | passwd ${USER}

# Create identity file for $USER and add public key to $USER's authorized keys for a localhost connection
WORKDIR /home/${USER}/.ssh
RUN chown ${USER}:${USER} .
USER ${USER}
RUN chmod 700 . && ${INSTALLDIR}/bin/ssh-keygen -t ssh-${SIG} -f id_${SIG//-/_} -N "" -q && cat id_${SIG//-/_}.pub > authorized_keys && chmod 600 authorized_keys

# Pass some potentionally useful variables to environment
USER root
ENV OQS_SIG_DEFAULT=${SIG}
ENV OQS_INSTALL_DIR=${INSTALLDIR}
ENV OQS_USER=${USER}

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
COPY sshd_config ${INSTALLDIR}
COPY ssh_config ${INSTALLDIR}
COPY serverstart.sh ${INSTALLDIR}/test/
COPY connect-test.sh ${INSTALLDIR}/test/
COPY key-regen.sh ${INSTALLDIR}/scripts/

# set path to use 'new' openssh
ENV PATH="${INSTALLDIR}/bin:${PATH}"
ENV PATH="${INSTALLDIR}/test:${PATH}"
ENV PATH="${INSTALLDIR}/scripts:${PATH}"

STOPSIGNAL SIGTERM

# Expose port 2222 as this is the chosen ssh port for oqs-ssh
EXPOSE 2222

# Re-generate the host keys and start a shell
WORKDIR /home/${OQS_USER}/
CMD ["sh", "-c", "key-regen.sh; /bin/sh"]