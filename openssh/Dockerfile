# Multi-stage build: First the full builder image:

# Default location where all binaries wind up:
ARG INSTALLDIR=/opt/oqssa

# liboqs build defines (https://github.com/open-quantum-safe/liboqs/wiki/Customizing-liboqs)
ARG LIBOQS_BUILD_DEFINES=

# openssl build defines (https://github.com/open-quantum-safe/openssl#build-options)
# ARG OPENSSH_BUILD_DEFINES="-DOQS_DEFAULT_GROUPS=p384_kyber768:X25519:kyber768:newhope1024cca"

# Default root CA signature algorithm; can be set to any listed at https://github.com/open-quantum-safe/openssl#authentication
ARG SIG="dilithium2"

# Define the degree of parallelism when building the image; leave the number away only if you know what you are doing
ARG MAKE_DEFINES="-j 6"

# Define the username of the normal user
ARG USER="oqs"

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
RUN chmod 700 . && ${INSTALLDIR}/bin/ssh-keygen -t ssh-${SIG} -f id_${SIG} -N "" -q && cat id_${SIG}.pub > authorized_keys && chmod 600 authorized_keys

USER root   
COPY sshd_config ${INSTALLDIR}
COPY ssh_config ${INSTALLDIR}
COPY serverstart.sh ${INSTALLDIR}/test/
COPY connect-test.sh ${INSTALLDIR}/test/
WORKDIR ${INSTALLDIR}/test
ENV PATH="${INSTALLDIR}/test:${PATH}"

CMD [ "serverstart.sh" ]
STOPSIGNAL SIGTERM



## second stage: Only create minimal image without build tooling and intermediate build results generated above:
FROM alpine:3.11 as dev
# Take in all global args
ARG INSTALLDIR
ARG USER
ARG SIG

# Only retain the ${INSTALLDIR} contents in the final image
COPY --from=intermediate ${INSTALLDIR} ${INSTALLDIR}


# Create a normal user to be able to log into the system via ssh
RUN addgroup --gid 1000 --system ${USER} && adduser --uid 1000 --system ${USER} --ingroup ${USER} --shell /bin/sh && passwd -d ${USER}

# Create identity file for $USER and add public key to $USER's authorized keys for a localhost connection
WORKDIR /home/${USER}/.ssh
RUN chown ${USER}:${USER} .
USER ${USER}
RUN chmod 700 . && ${INSTALLDIR}/bin/ssh-keygen -t ssh-${SIG} -f id_${SIG} -N "" -q && cat id_${SIG}.pub > authorized_keys && chmod 600 authorized_keys
ENV PATH="${INSTALLDIR}/bin:${PATH}"
WORKDIR /home/${USER}

USER root

# set path to use 'new' openssh
ENV PATH="${INSTALLDIR}/bin:${PATH}"
ENV PATH="${INSTALLDIR}/test:${PATH}"

# USER ${USER}
CMD [ "serverstart.sh" ]
STOPSIGNAL SIGTERM