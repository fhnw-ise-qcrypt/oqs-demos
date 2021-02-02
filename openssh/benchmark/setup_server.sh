#!/bin/bash

echo "Debug level set to ${DEBUGLVL:=0}"

CONTAINER="oqs-server"
DOCKER_IMG="oqs-openssh-img"

function evaldbg {
    if [ $DEBUGLVL -ge 2 ]; then
        echo "Debug: Executing '${1}'"
    fi
    eval $1
    return $?
}

# Stop server if running
evaldbg "docker ps | grep ${CONTAINER}"
if [ $? -eq 0 ]; then
    echo "Stopping container: ${CONTAINER}"
    evaldbg "docker stop ${CONTAINER} -t 0"
fi

# TODO Start docker image
echo ""
echo "Starting ${CONTAINER}:"
evaldbg "docker run
    --net oqs-net \
    --name ${CONTAINER} \
    -dit \
    --rm \
    -e SKIP_KEYGEN=YES \
    ${DOCKER_IMG}"

# TODO get list of host key algorithms
echo ""
files=$(evaldbg "docker exec -it ${CONTAINER} bash -c 'ls /opt/oqs-ssh/ssh_host_*_key'")
echo -n "Finding all host key algorithms: "
SIG_LIST=""
for file in $files; do 
    SIG=$(echo ${file} | sed -n "s:.*ssh_host_::p" | sed -n "s:_key.*::p")
    if [ ${#SIG} -gt 0 ] && [ ${SIG} != "\*" ]; then
        SIG_LIST="$SIG_LIST,${SIG/_/-}"
    fi
done

echo $SIG_LIST

# TODO Start sshd with all algorithms enabled
evaldbg "/opt/oqs-ssh/sbin/sshd -o PubkeyAcceptedKeyTypes=${SIG_LIST}"