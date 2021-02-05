#!/bin/bash

DIR=${0%/*}

CONTAINER=${CONTAINER:="oqs-client"}
DOCKER_IMG=${DOCKER_IMG:="oqs-openssh-img"}
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
    ${DOCKER_IMG}"

# For each host key generate a new id key
# Get list of signature algorithms
SIGS=()
while IFS="" read -r SIG; do 
    [[ $SIG == "" ]] || [[ $SIG =~ ^#.* ]] && continue # If this looks weird: No worries, it works (=~ takes regex, but not as string)
    SIGS+=("$SIG")
done < "$DIR/listofsigs.conf"

echo ""

SSH_ID_PATH="/home/oqs/.ssh"
echo "### Generating identity keys ###"
for SIG in ${SIGS[@]}; do 
    SIG=${SIG,,}
    echo -n "${SIG^^} "
    evaldbg "docker exec --user oqs -t ${CONTAINER} ssh-keygen -t ssh-${SIG//_/-} -f ${SSH_ID_PATH}/id_${SIG//-/_} -N \"\" -q"
done
echo ""; echo ""

### Copy all .ssh/*.pub to server --> Need server IP
GLOBAL_SSH_OPTS="-p ${PORT} -o StrictHostKeyChecking=no -q"

FIRST_KEY=${SIGS[0]}
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
for SIG in ${SIGS[@]}; do
    if [[ ${SIG//-/_} != ${FIRST_KEY//-/_} ]]; then
        SSH_OPTS="${GLOBAL_SSH_OPTS} -o Batchmode=yes -i ${SSH_ID_PATH}/id_${FIRST_KEY//-/_} -o PubKeyAcceptedKeyTypes=ssh-${FIRST_KEY//_/-}"
        evaldbg "docker exec --user oqs -t ${CONTAINER} bash -c \"cat ${SSH_ID_PATH}/id_${SIG//-/_}.pub | ssh ${OQS_USER}@${SERVER} ${SSH_OPTS} 'cat >> .ssh/authorized_keys; exit 0'\""
        if [[ $? -eq 0 ]]; then
            echo -n "${SIG^^} "
        else
            echo -n "[FAILED: ${SIG^^}] "
        fi
    fi
done
echo ""; echo ""


# Test public keys
echo "### Testing pubkeys ###"
TEST_FAIL=0
SIG_FAIL=()
for SIG in ${SIGS[@]}; do
    SSH_OPTS="${GLOBAL_SSH_OPTS} -i ${SSH_ID_PATH}/id_${SIG//-/_} -o Batchmode=yes -o PubkeyAcceptedKeyTypes=ssh-${SIG//_/-} -o ConnectTimeout=60"
    evaldbg "docker exec --user oqs -it ${CONTAINER} ssh ${SSH_OPTS} ${OQS_USER}@${SERVER} 'exit 0'"
    if [[ $? -eq 0 ]]; then
        echo -n "${SIG^^} "
    else
        echo -n "[FAILED: ${SIG^^}] "
        TEST_FAIL=1
        SIG_FAIL+=(${SIG^^})
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
