#!/bin/bash

[[ $DEBUGLVL -gt 1 ]] && set -ex

OPTIONS=${OPTIONS:="-q"}

# SIG to one defined in https://github.com/open-quantum-safe/openssh#digital-signature
SIG=${SIG:="p256-dilithium2"}
# Set KEM to one defined in https://github.com/open-quantum-safe/openssh#key-exchange
KEM=${KEM:="kyber-1024"}

# Check if KEM is not classical algorithm
if [[ ${KEM,,} != "curve25519-sha256"* ]] && [[ ${KEM,,} != "ecdh-sha2-nistp"* ]] && [[ ${KEM,,} != "diffie-hellman-group"* ]]; then
    if [[ ${KEM,,} != "ecdh-nistp384-"* ]]; then
        KEM="ecdh-nistp384-${KEM}"
    fi

    if [[ ${KEM,,} != *"-sha384@openquantumsafe.org" ]]; then
        KEM="${KEM}-sha384@openquantumsafe.org"
    fi
fi

SERVER_PORT=${SERVER_PORT:=2222}

# Host key file
HOST_KEY_FILE="${OQS_INSTALL_DIR}/ssh_host_${SIG//-/_}_key"

# Port options
OPTIONS="${OPTIONS} -p ${SERVER_PORT}"

# KEM options
OPTIONS="${OPTIONS} -o KexAlgorithms=${KEM//_/-}"

# SIG options
OPTIONS="${OPTIONS} -o HostKeyAlgorithms=ssh-${SIG//_/-} -o PubkeyAcceptedKeyTypes=ssh-${SIG//_/-}"
OPTIONS="${OPTIONS} -h ${HOST_KEY_FILE}"

# Generate host keys
if [[ -f ${HOST_KEY_FILE} ]]; then
    rm -f "${HOST_KEY_FILE}"
fi
${OQS_INSTALL_DIR}/bin/ssh-keygen -t ssh-${SIG//_/-} -f ${HOST_KEY_FILE} -N "" -q
echo ""

[[ $DEBUGLVL -gt 0 ]] && echo "Debug1: New host key '${HOST_KEY_FILE}(.pub)' created!"

# Start the OQS SSH Daemon with the configuration as in ${OQS_INSTALL_DIR}/sshd_config
CMD="${OQS_INSTALL_DIR}/sbin/sshd ${OPTIONS}"
[[ $DEBUGLVL -gt 0 ]] && echo $CMD
eval $CMD