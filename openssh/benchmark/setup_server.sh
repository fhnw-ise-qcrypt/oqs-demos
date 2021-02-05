#!/bin/bash

DIR=${0%/*}

echo "Debug level set to ${DEBUGLVL:=0}"

CONTAINER=${CONTAINER:="oqs-client"}
DOCKER_IMG=${DOCKER_IMG:="oqs-openssh-img"}
PORT=${PORT:=2222}

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

# Start docker image
echo ""
echo "Starting ${CONTAINER}:"
evaldbg "docker run
    --name ${CONTAINER} \
    -dit \
    --publish ${PORT}:${PORT} \
    --rm \
    -e SKIP_KEYGEN=YES \
    ${DOCKER_IMG}"

# Get list of host key algorithms
SIGS=()
while IFS="" read -r SIG; do 
    [[ $SIG == "" ]] || [[ $SIG =~ ^#.* ]] && continue # If this looks weird: No worries, it works (=~ takes regex, but not as string)
    SIGS+=("$SIG")
done < "$DIR/listofsigs.conf"

echo ""

SIG_LIST=""
for SIG in ${SIGS[@]}; do 
    if [[ "${SIG,,}" == "*ecdsa*" ]] || [[ "${SIG,,}" == "*dsa*" ]]; then
        SIG_LIST="$SIG_LIST,$SIG"
    else
        SIG_LIST="$SIG_LIST,ssh-$SIG"
    fi
done
SIG_LIST=${SIG_LIST#,}

# Start sshd with all algorithms enabled
evaldbg "docker exec -t ${CONTAINER} /opt/oqs-ssh/sbin/sshd -o PubkeyAcceptedKeyTypes=${SIG_LIST}"

if [[ $? -eq 0 ]]; then
    echo "### [ OK ] ### Server set up successfully! Now set up the client."
else
    echo "### [FAIL] ### Error while setting up server!"
fi