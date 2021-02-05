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
        KEM_INTERMEDIATE="ecdh-nistp384-${KEM,,}"
    else
        KEM_INTERMEDIATE=${KEM,,}
    fi

    if [[ ${KEM_INTERMEDIATE,,} != *"-sha384@openquantumsafe.org" ]]; then
        KEM_FULL="${KEM_INTERMEDIATE}-sha384@openquantumsafe.org"
    else
        KEM_FULL=${KEM_INTERMEDIATE}
    fi
else
    KEM_FULL=${KEM,,}
fi

if [[ ${SIG,,} == *"@openssh.com" ]]; then
    echo "[FAIL] Use an algorithm without the '@openssh.com' postfix, they are not supported at the moment."
    echo "Use one of the following: ssh-ed25519, ecdsa-sha2-nistp256, ecdsa-sha2-nistp384, ecdsa-sha2-nistp521"
    exit 1
elif [[ ${SIG,,} == *"rsa"* ]]; then
    echo "[FAIL] No support for any rsa algorithm."
    echo "Use one of the following: ssh-ed25519, ecdsa-sha2-nistp256, ecdsa-sha2-nistp384, ecdsa-sha2-nistp521"
    exit 1
elif [[ ${SIG,,} != "ecdsa-sha2-nistp"* ]] && [[ ${SIG,,} != "ssh-ed25519" ]]; then
    # Prefix
    if [[ ${SIG,,} != "ssh-"* ]]; then
        SIG_FULL="ssh-${SIG,,}"
    fi
else
    SIG_FULL=${SIG,,}
fi


SERVER_PORT=${SERVER_PORT:=2222}

# Host key file
HOST_KEY_FILE="${OQS_INSTALL_DIR}/ssh_host_${SIG//-/_}_key"

# Port options
OPTIONS="${OPTIONS} -p ${SERVER_PORT}"

# KEM options
OPTIONS="${OPTIONS} -o KexAlgorithms=${KEM_FULL//_/-}"

# SIG options
OPTIONS="${OPTIONS} -o HostKeyAlgorithms=${SIG_FULL//_/-} -o PubkeyAcceptedKeyTypes=${SIG_FULL//_/-}"
OPTIONS="${OPTIONS} -h ${HOST_KEY_FILE}"

# Generate host keys
if [[ -f ${HOST_KEY_FILE} ]]; then
    rm -f "${HOST_KEY_FILE}"
fi
${OQS_INSTALL_DIR}/bin/ssh-keygen -t ${SIG_FULL//_/-} -f ${HOST_KEY_FILE} -N "" -q
echo ""

[[ $DEBUGLVL -gt 0 ]] && echo "Debug1: New host key '${HOST_KEY_FILE}(.pub)' created!"

# Start the OQS SSH Daemon with the configuration as in ${OQS_INSTALL_DIR}/sshd_config
CMD="${OQS_INSTALL_DIR}/sbin/sshd ${OPTIONS}"
[[ $DEBUGLVL -gt 0 ]] && echo $CMD
eval $CMD