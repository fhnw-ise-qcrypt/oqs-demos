#!/bin/bash

DIR=${0%/*}

CONTAINER=${CONTAINER:="oqs-client"}
DOCKER_IMG=${DOCKER_IMG:="oqs-openssh-img"}
DOCKER_OPTS=${DOCKER_OPTS:=""}
PORT=${PORT:=2222}

if [ $# -lt 1 ]; then
    echo "Provide the server's IP address!"
    echo "Aborting..."
    exit 1
else
    SERVER=$1
fi

echo "Debug level set to ${DEBUGLVL:=0}"

function evaldbg {
    if [ $DEBUGLVL -ge 2 ]; then
        echo "Debug: Executing '${1}'"
    fi
    eval $1
    return $?
}

# Stop client if running
evaldbg "docker ps | grep ${CONTAINER}"
if [ $? -eq 0 ]; then
    echo "Stopping container: ${CONTAINER}"
    evaldbg "docker stop ${CONTAINER} -t 0"
fi

# Run client
echo ""
echo "Starting ${CONTAINER}:"
evaldbg "docker run \
    --user oqs \
    --name ${CONTAINER} \
    -dit \
    --rm \
    -e SKIP_KEYGEN=YES \
    ${DOCKER_OPTS} \
    ${DOCKER_IMG}"

# Get list of signature algorithms
SIGS=()
while IFS="" read -r SIG; do 
    [[ $SIG == "" ]] || [[ $SIG =~ ^#.* ]] && continue # If this looks weird: No worries, it works (=~ takes regex, but not as string)
    SIGS+=("$SIG")
done < "$DIR/listofsigs.conf"

for i in ${!SIGS[@]}; do
    echo -n "${SIGS[i]} --> "
    if [[ ${SIGS[i],,} == *"@openssh.com" ]]; then
        echo "[FAIL] Use an algorithm without the '@openssh.com' postfix, they are not supported at the moment."
        echo "Use one of the following: ssh-ed25519, ecdsa-sha2-nistp256, ecdsa-sha2-nistp384, ecdsa-sha2-nistp521"
        exit 1
    elif [[ ${SIGS[i],,} == *"rsa"* ]] && [[ ${SIGS[i],,} != *"rsa3072"* ]]; then
        echo "[FAIL] No support for any rsa algorithm."
        echo "Use one of the following: ssh-ed25519, ecdsa-sha2-nistp256, ecdsa-sha2-nistp384, ecdsa-sha2-nistp521"
        exit 1
    elif [[ ${SIGS[i],,} != "ecdsa-sha2-nistp"* ]] && [[ ${SIGS[i],,} != "ssh-ed25519" ]]; then
        # Add Prefix
        if [[ ${SIGS[i],,} != "ssh-"* ]]; then
            SIGS_FULL[i]="ssh-${SIGS[i],,}"
        fi
    else
        SIGS_FULL[i]="${SIGS[i],,}"
    fi
    echo "${SIGS_FULL[i]}"
done

echo ""

# For each enabled signature algorithm generate a new id key
SSH_ID_PATH="/home/oqs/.ssh"
echo "### Generating identity keys ###"
for i in ${!SIGS[@]}; do 
    # SIG=${SIGS[i],,}
    echo -n "${SIGS[i]^^} "
    evaldbg "docker exec --user oqs -t ${CONTAINER} ssh-keygen -t ${SIGS_FULL[i]//_/-} -f ${SSH_ID_PATH}/id_${SIGS[i]//-/_} -N \"\" -q"
done
echo ""; echo ""

### Copy all .ssh/*.pub to server --> Need server IP
GLOBAL_SSH_OPTS="-p ${PORT} -o StrictHostKeyChecking=no"
if [[ $DEBUGLVL -eq 0 ]]; then
    GLOBAL_SSH_OPTS="$GLOBAL_SSH_OPTS -q"
elif [[ $DEBUGLVL -ge 2 ]]; then
    GLOBAL_SSH_OPTS="$GLOBAL_SSH_OPTS -v"
fi

FIRST_KEY=${SIGS[0]}
FIRST_KEY_FULL=${SIGS_FULL[0]}
PASSWORD="oqs.pw"
OQS_USER="oqs"
PORT=2222

echo "### Sending public keys to server ###"
# First run: Password authentication
SSH_OPTS="${GLOBAL_SSH_OPTS}"
evaldbg "docker exec --user oqs -t ${CONTAINER} bash -c \"cat ${SSH_ID_PATH}/id_${FIRST_KEY//-/_}.pub | sshpass -p ${PASSWORD} ssh ${OQS_USER}@${SERVER} ${SSH_OPTS} 'cat >> .ssh/authorized_keys; exit 0'\""
if [[ $? -eq 0 ]]; then
    echo -n "${FIRST_KEY^^} "
else
    echo -n "[FAILED: ${FIRST_KEY^^}] "
fi

# Other runs: Authentication with first run's key
KEYSET_FAIL=0
for i in ${!SIGS[@]}; do
    if [[ ${SIGS[i]//-/_} != ${FIRST_KEY//-/_} ]]; then
        SSH_OPTS="${GLOBAL_SSH_OPTS} -o Batchmode=yes -i ${SSH_ID_PATH}/id_${FIRST_KEY//-/_} -o PubKeyAcceptedKeyTypes=${FIRST_KEY_FULL//_/-}"
        evaldbg "docker exec --user oqs -t ${CONTAINER} bash -c \"cat ${SSH_ID_PATH}/id_${SIGS[i]//-/_}.pub | ssh ${OQS_USER}@${SERVER} ${SSH_OPTS} 'cat >> .ssh/authorized_keys; exit 0'\""
        if [[ $? -eq 0 ]]; then
            echo -n "${SIGS[i]^^} "
        else
            echo -n "[FAILED: ${SIGS[i]^^}] "
        fi
    fi
done
echo ""; echo ""


# Test public keys
echo "### Testing pubkeys ###"
TEST_FAIL=0
SIG_FAIL=()
for i in ${!SIGS[@]}; do
    SSH_OPTS="${GLOBAL_SSH_OPTS} -i ${SSH_ID_PATH}/id_${SIGS[i]//-/_} -o Batchmode=yes -o PubkeyAcceptedKeyTypes=${SIGS_FULL[i]//_/-} -o ConnectTimeout=60"
    evaldbg "docker exec --user oqs -it ${CONTAINER} ssh ${SSH_OPTS} ${OQS_USER}@${SERVER} 'exit 0'"
    if [[ $? -eq 0 ]]; then
        echo -n "${SIGS[i]^^} "
    else
        echo -n "[FAILED: ${SIGS[i]^^}] "
        TEST_FAIL=1
        SIG_FAIL+=(${SIGS[i]^^})
    fi
done
echo ""; echo ""

if [[ TEST_FAIL -gt 0 ]]; then
    echo -n "### [FAIL] ### with "
    for FAIL in ${SIG_FAIL[@]}; do
        echo -n "${FAIL} "
    done
    echo ""
    echo " ### [Note] ### The problem could also be server side!"
    exit 1
else
    echo "### [ OK ] ### Client (and thus the server) set up successfully! The testing may begin!"
    exit 0
fi
