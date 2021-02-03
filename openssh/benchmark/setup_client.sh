#!/bin/bash

DIR=${0%/*}

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
# TODO: Remove oqs-net 
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
# Get list of signature algorithms
SIGS=()
while IFS="" read -r SIG; do 
    [[ $SIG == "" ]] || [[ $SIG =~ ^#.* ]] && continue # This looks weird I know, but it works (=~ takes regex, but not as string)
    SIGS+=("$SIG")
done < "$DIR/listofsigs.conf"

echo ""

SSH_ID_PATH="/home/oqs/.ssh"
echo -n "Generating id keys: "
for SIG in ${SIGS[@]}; do 
    SIG=${SIG//-/_}
    echo -n "${SIG^^} "
    evaldbg "docker exec --user oqs -t ${CONTAINER} ssh-keygen -t ${SIG} -f ${SSH_ID_PATH}/id_${SIG} -N \"\" -q"
done
echo ""

# TODO Copy all .ssh/*.pub to server --> Need server IP
FIRST_KEY="p384-dilithium4"
PASSWORD="oqs.pw"
OQS_USER="oqs"
PORT=2222
# First run: Password authentication
SSH_OPTS="-o StrictHostKeyChecking=no -v"
evaldbg "docker exec --user oqs -t ${CONTAINER} bash -c \"cat ${SSH_ID_PATH}/id_${FIRST_KEY//-/_}.pub | sshpass -p ${PASSWORD} ssh ${OQS_USER}@${SERVER} ${SSH_OPTS} 'cat >> .ssh/authorized_keys; exit 0'\""

# Other runs: Authentication with first run's key
echo ""
echo -n "Sending public keys to server: "
for SIG in ${SIGS[@]}; do
    if [[ ${SIG//-/_} != ${FIRST_KEY//-/_} ]]; then
        SSH_OPTS="-o Batchmode=yes -o StrictHostKeyChecking=no -i ${SSH_ID_PATH}/id_${FIRST_KEY//-/_}"
        evaldbg "docker exec --user oqs -t ${CONTAINER} bash -c \"cat ${SSH_ID_PATH}/id_${SIG//-/_}.pub | ssh ${OQS_USER}@${SERVER} ${SSH_OPTS} 'cat >> .ssh/authorized_keys; exit 0'\""
        if [[ $? -eq 0 ]]; then
            echo -n "${SIG^^} "
        else
            echo -n "[FAILED: ${SIG^^}] "
        fi
    fi
done

echo ""
echo ""
# sleep 1 #FIXME

# FIXME: p384 and p521 keys fail --> Maybe decode and check with ssh-keygen?
echo "Testing pubkeys: "

for SIG in ${SIGS[@]}; do
    SSH_OPTS="-i ${SSH_ID_PATH}/id_${SIG//-/_} -o Batchmode=yes -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=ssh-${SIG//_/-} -o ConnectTimeout=60 -v"
    # SSH_OPTS="-o Batchmode=yes -o StrictHostKeyChecking=no -i ${SSH_ID_PATH}/id_${SIG//-/_}"
    evaldbg "docker exec --user oqs -it ${CONTAINER} ssh ${SSH_OPTS} ${OQS_USER}@${SERVER} 'exit 0'"
    if [[ $? -eq 0 ]]; then
        echo "${SIG^^} "
    else
        echo "[FAILED: ${SIG^^}] "
    fi
    echo ""
done

# docker exec --user oqs -t ${CONTAINER} ls "/home/oqs/" -al
# echo "Decoded private key:"
# docker exec --user oqs -t ${CONTAINER} ssh-keygen -y ${SSH_ID_PATH}/id_${SIG//-/_}

#evaldbg "docker exec --user oqs -t ${CONTAINER} ssh ${OQS_USER}@${SERVER} -o StrictHostKeyChecking=no -o PubKeyAcceptedKeyTypes=ssh-${FIRST_KEY//_/-} -i ${SSH_ID_PATH}/id_${FIRST_KEY//-/_} \"exit 0\""
# DOCKER EXEC: cat .ssh/id_p384_dilithium4.pub | sshpass -p "oqs.pw" ssh -o StrictHostKeyChecking=no oqs@172.18.0.2 "cat >> authorized_keys"

# echo "vvv"
# evaldbg "docker exec --user oqs -it ${CONTAINER} vi ${SSH_ID_PATH}/id_${SIG//-/_}"
# evaldbg "docker exec --user oqs -it ${CONTAINER} ls -al ${SSH_ID_PATH}"
# echo "^^^"

# if [[ $? -eq 0 ]]; then
#     echo ""
#     echo "SUCCESS!"
# fi

