#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Provide the server's IP address!"
    echo "Aborting..."
    exit 1
else
    SERVER=$1
fi

echo "Debug level set to ${DEBUGLVL:=0}"

CONTAINER="oqs-client"
DOCKER_IMG="oqs-openssh-img"

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
    --net oqs-net \
    --name ${CONTAINER} \
    -dit \
    --rm \
    -e SKIP_KEYGEN=YES \
    ${DOCKER_IMG}"

# For each host key generate a new id key
echo ""
SSH_ID_PATH="/home/oqs/.ssh"
files=$(evaldbg "docker exec -it ${CONTAINER} bash -c 'ls /opt/oqs-ssh/ssh_host_*_key'")
echo -n "Generating id keys: "
for file in $files; do 
    SIG=$(echo ${file} | sed -n "s:.*ssh_host_::p" | sed -n "s:_key.*::p")
    if [ ${#SIG} -gt 0 ] && [ ${SIG} != "\*" ]; then
        echo -n "${SIG/_/-},"
        evaldbg "docker exec --user oqs -it ${CONTAINER} ssh-keygen -f ${SSH_ID_PATH}/id_${SIG} -t ${SIG} -N '' -q"
    fi
done

# TODO Copy all .ssh/*.pub to server --> Need server IP
FIRST_KEY="p384_dilithium4"
PASSWORD="oqs.pw"
OQS_USER="oqs"
PORT=2222
# First run: Password authentication
# evaldbg "echo $PASSWORD | sshpass | ssh -o StrictHostKeyChecking=no ${OQS_USER}@${SERVER} "
# Other runs: Authentication with first run's key