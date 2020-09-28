# Multi-stage build: First the full builder image:

# Default location where all binaries wind up:
ARG INSTALLDIR=/opt/oqssa

# liboqs build defines (https://github.com/open-quantum-safe/liboqs/wiki/Customizing-liboqs)
# ARG LIBOQS_BUILD_DEFINES=

# openssl build defines (https://github.com/open-quantum-safe/openssl#build-options)
# ARG OPENSSH_BUILD_DEFINES="-DOQS_DEFAULT_GROUPS=p384_kyber768:X25519:kyber768:newhope1024cca"

# Default root CA signature algorithm; can be set to any listed at https://github.com/open-quantum-safe/openssl#authentication
ARG SIG="dilithium2"

# Define the degree of parallelism when building the image; leave the number away only if you know what you are doing
ARG MAKE_DEFINES="-j 6"


FROM alpine:3.11 as intermediate
# Take in all global args
ARG INSTALLDIR
ARG LIBOQS_BUILD_DEFINES
ARG OPENSSH_BUILD_DEFINES
ARG SIG
ARG MAKE_DEFINES

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
RUN mkdir build-static && cd build-static && cmake .. -DCMAKE_BUILD_TYPE=${LIBOQS_BUILD_TYPE} -DBUILD_SHARED_LIBS=OFF -DCMAKE_INSTALL_PREFIX=/opt/ossh-src/oqs && make ${MAKE_DEFINES} && make install

# build OQS-OpenSSH, this will automatically generate host keys for all SIG algorithms
WORKDIR /opt/ossh-src
RUN autoreconf && ./configure --with-libs=-lm --prefix=${INSTALLDIR} --sysconfdir=${INSTALLDIR} --with-liboqs-dir=/opt/ossh-src/oqs && make ${MAKE_DEFINES} && make install

# set path to use 'new' openssh. Dyn libs have been properly linked in to match
ENV PATH="${INSTALLDIR}/bin:${PATH}"
ENV PATH="${INSTALLDIR}/sbin:${PATH}"
ENV PATH="${INSTALLDIR}:${PATH}"

# Enable a normal user to create new server keys off set CA
ENV USER=oqs
RUN addgroup --gid 1000 --system ${USER} && adduser --uid 1000 --system ${USER} --ingroup ${USER} --shell /bin/bash

# Create identity file for $USER and add public key to $USER's authorized keys
WORKDIR /home/${USER}/.ssh
RUN chown ${USER}:${USER} .
USER ${USER}
RUN chmod 700 . && ${INSTALLDIR}/bin/ssh-keygen -t ssh-${SIG} -f id_${SIG} -N "" -q && cat id_${SIG}.pub > authorized_keys && chmod 600 authorized_keys
WORKDIR ${HOME}

USER root
COPY sshd_config ${INSTALLDIR}
COPY ssh_config ${INSTALLDIR}
COPY serverstart.sh ${INSTALLDIR}


CMD [ "serverstart.sh" ]

STOPSIGNAL SIGTERM

# WORKDIR /

# COPY serverstart.sh ${INSTALLDIR}/bin

# CMD ["serverstart.sh"]





# ## second stage: Only create minimal image without build tooling and intermediate build results generated above:
# FROM alpine:3.11 as dev
# # Take in all global args
# ARG INSTALLDIR
# ARG SIG
# ARG KEM

# # Only retain the ${INSTALLDIR} contents in the final image
# COPY --from=intermediate ${INSTALLDIR} ${INSTALLDIR}

# # set path to use 'new' openssl & curl. Dyn libs have been properly linked in to match
# ENV PATH="${INSTALLDIR}/bin:${PATH}"

# # generate certificates for openssl s_server, which is what we will test curl against
# ENV OPENSSL=${INSTALLDIR}/bin/openssl
# ENV OPENSSL_CNF=${INSTALLDIR}/ssl/openssl.cnf

# WORKDIR ${INSTALLDIR}/bin

# RUN set -x && mkdir /opt/test && \
#     # generate server CSR using pre-set CA.key & cert
#     ${OPENSSL} req -new -newkey ${SIG_ALG} -keyout /opt/test/server.key -out /opt/test/server.csr -nodes -subj "/CN=localhost" -config ${OPENSSL_CNF} && \
#     # generate server cert
#     ${OPENSSL} x509 -req -in /opt/test/server.csr -out /opt/test/server.crt -CA CA.crt -CAkey CA.key -CAcreateserial -days 365;

# COPY serverstart.sh ${INSTALLDIR}/bin
# COPY perftest.sh ${INSTALLDIR}/bin

# WORKDIR ${INSTALLDIR}

# FROM dev
# ARG INSTALLDIR

# WORKDIR /



# USER oqs
# CMD ["serverstart.sh"]
# STOPSIGNAL SIGTERM
