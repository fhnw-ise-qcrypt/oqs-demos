#!/bin/bash

[[ $DEBUGLVL -gt 1 ]] && set -ex

# Stop the sshd service that may was started before, otherwise it won't work with others than the default algorithms
rc-service oqs-sshd stop

# default options
OPTIONS=${OPTIONS:="-q -o BatchMode=yes -o StrictHostKeyChecking=no"}

SIG=${SIG:="p384-dilithium4"}
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

# Generate new identity keys, overwrite old keys
SSH_DIR="/home/${OQS_USER}/.ssh"
SIG_ID_FILE="${SSH_DIR}/id_${SIG//-/_}"
if [[ -f ${SIG_ID_FILE} ]]; then
    rm -f "${SIG_ID_FILE}*"
fi
su ${OQS_USER} -c "${OQS_INSTALL_DIR}/bin/ssh-keygen -t ssh-${SIG//_/-} -f ${SIG_ID_FILE} -N \"\" -q"
echo ""
cat ${SIG_ID_FILE}.pub >> ${SSH_DIR}/authorized_keys
[[ $DEBUGLVL -gt 0 ]] && echo "Debug1: New identity key '${SIG_ID_FILE}(.pub)' created!"
OPTIONS="${OPTIONS} -i ${SIG_ID_FILE}"

eval "KEM=$KEM SIG=$SIG CONNECT_TEST=true serverstart.sh"

# Evaluate if called as root
if [ ${EUID} -eq 0 ]; then
    SSH_PREFIX="su ${OQS_USER} -c "
fi

# See if TEST_HOST was set, if not use default
TEST_HOST=${TEST_HOST:="localhost"}

# See if TEST_TIME was set, if not use default
TEST_TIME=${TEST_TIME:=60}
OPTIONS="${OPTIONS} -o ConnectTimeout=${TEST_TIME}"

# Optionally set port
# if left empty, the options defined in sshd_config will be used
if [ "x$SERVER_PORT" != "x" ]; then
    OPTIONS="${OPTIONS} -p ${SERVER_PORT}"
fi

# Optionally set KEM to one defined in https://github.com/open-quantum-safe/openssh#key-exchange
# if left empty, the options defined in sshd_config will be used
if [ "x$KEM" != "x" ]; then
    OPTIONS="${OPTIONS} -o KexAlgorithms=${KEM//_/-}"
fi

# Optionally set SIG to one defined in https://github.com/open-quantum-safe/openssh#digital-signature
# if left empty, the options defined in sshd_config will be used
if [ "x$SIG" != "x" ]; then
    OPTIONS="${OPTIONS} -o HostKeyAlgorithms=ssh-${SIG//_/-} -o PubkeyAcceptedKeyTypes=ssh-${SIG//_/-}"
fi

CMD="ssh ${OPTIONS} ${TEST_HOST} 'exit 0'"
[[ $DEBUGLVL -gt 0 ]] && echo "Debug1: $SSH_PREFIX\"$CMD\""
eval "$SSH_PREFIX\"$CMD\""

if [ $? -eq 0 ]; then
    echo ""
    echo "[ OK ] Connected to ${TEST_HOST} using ${KEM//_/-} and ${SIG//_/-}!"
    exit 0
else
    echo ""
    echo "[FAIL] Could not connect to ${TEST_HOST} using ${KEM//_/-} and ${SIG//_/-}!"
    exit 1
fi
