#!/bin/bash

DIR=${0%/*}

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

# Start docker image
# TODO: Remove oqs-net 
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
SIGS=()
while IFS="" read -r SIG; do 
    [[ $SIG == "" ]] || [[ $SIG =~ ^#.* ]] && continue # This looks weird I know, but it works (=~ takes regex, but not as string)
    SIGS+=("$SIG")
done < "$DIR/listofsigs.conf"

echo ""

SIG_LIST=""
for SIG in ${SIGS[@]}; do 
    if [[ "${SIG,,}" == "*ecdsa*" ]] || [[ "${SIG,,}" == "*rsa*" ]] || [[ "${SIG,,}" == "*dsa*" ]] || [[ "${SIG,,}" == "*ed25519*" ]]; then
        SIG_LIST="$SIG_LIST,$SIG"
    else
        SIG_LIST="$SIG_LIST,ssh-$SIG"
    fi
done
SIG_LIST=${SIG_LIST#,}

# docker exec -t ${CONTAINER} "SIG_LIST=$SIG_LIST"
# TODO Start sshd with all algorithms enabled
evaldbg "docker exec -t ${CONTAINER} /opt/oqs-ssh/sbin/sshd -o PubkeyAcceptedKeyTypes=${SIG_LIST}"
# echo ""
# echo ""
# evaldbg "docker exec -t ${CONTAINER} /opt/oqs-ssh/sbin/sshd -o PubkeyAcceptedKeyTypes=${SIG_LIST} -ddd"