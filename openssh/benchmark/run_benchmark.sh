#!/bin/bash

DIR=${0%/*}

PORT=${PORT:=2222}
CONTAINER=${CONTAINER:="oqs-client"}
OQS_USER=${OQS_USER:="oqs"}
DOCKER_OPTS=${DOCKER_OPTS:=""}

if [ $# -lt 1 ]; then
    echo "Provide the server's IP address and optionally its port in the following format:"
    echo "${0##*/} <server_ip> <server_port>"
    echo "Aborting..."
    exit 1
elif [ $# -eq 1 ]; then
    SERVER=$1
    echo "Server IP:PORT is ${SERVER}:${PORT}"
elif [ $# -eq 2 ]; then
    SERVER=$1
    PORT=$2
    echo "Server IP:PORT is ${SERVER}:${PORT}"
fi

echo "Debug level is ${DEBUGLVL:=0}"

function evaldbg {
    if [ $DEBUGLVL -ge 2 ]; then
        echo "Debug: Executing '$@'"
    fi
    eval $@
    return $?
}

# read listoftests.conf
SIGS=()
KEMS=()
NUM_LOOPS=()
while read -r SIG KEM NUM_LOOP; do 
    [[ ${SIG} == "" ]] || [[ ${SIG} =~ ^#.* ]] && continue # Check if first character is '#'
    SIGS+=("${SIG}")
    KEMS+=("${KEM}")
    NUM_LOOPS+=("${NUM_LOOP}")
    # echo "i found >${SIGS[-1]}< >${KEMS[-1]}< >${NUM_LOOPS[-1]}<"
done < "$DIR/listoftests.conf"

# Add pre and postfixes to algorithm names if needed
# KEM: ecdh-nistp384-<KEM>-sha384@openquantumsafe.org if PQC algorithm, else <KEM>
for i in ${!KEMS[@]}; do
    echo -n "${KEMS[i]} --> "
    if [[ ${KEMS[i],,} != "curve25519-sha256"* ]] && [[ ${KEMS[i],,} != "ecdh-sha2-nistp"* ]] && [[ ${KEMS[i],,} != "diffie-hellman-group"* ]]; then
        # Add prefix
        if [[ ${KEMS[i],,} != "ecdh-nistp384-"* ]]; then
            KEMS_FULL[i]="ecdh-nistp384-${KEMS[i],,}"
        fi
        # Add postfix
        if [[ ${KEMS_FULL[i],,} != *"-sha384@openquantumsafe.org" ]]; then
            KEMS_FULL[i]="${KEMS_FULL[i],,}-sha384@openquantumsafe.org"
        fi
    else
        KEMS_FULL[i]="${KEMS[i],,}"
    fi
    echo "${KEMS_FULL[i]}"
done
# SIG: ssh-<SIG> if PQC algorithm, else <SIG>
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

# Create directory for storing the results
RESULTSDIR="${DIR}/results"
if [[ -d ${RESULTSDIR} ]]; then
    rm -f ${RESULTSDIR}/*
else
    mkdir ${RESULTSDIR}
fi

echo ""
echo "### Run tests ###"

# Get timestamp
evaldbg DATETIME=$(date +"%Y-%m-%d_%H-%M-%S")

# Build tshark filter (any interface, ssh and tcp, server address:port)
TSHARK_FILTER="\"tcp port ${PORT}\""

# Configure SSH options
SSH_GLOBAL_OPTS="-p ${PORT} -o BatchMode=yes -q"
if [[ $DEBUGLVL -ge 3 ]]; then
    SSH_GLOBAL_OPTS="${SSH_GLOBAL_OPTS} -v"
fi
SSH_DIR="/home/${OQS_USER}/.ssh"
# Loop over all tests
for i in ${!SIGS_FULL[@]}; do
#   Start tshark capture for <SIG>_<KEM>
    evaldbg "tshark -i any -f ${TSHARK_FILTER} -w \"${RESULTSDIR}/${DATETIME}_${SIGS[i]}_${KEMS[i]}.pcap\" -q &"
    TSHARK_PID=$!
    sleep 0.42
#   Do test n times
    SSH_OPTS="${SSH_GLOBAL_OPTS} -i ${SSH_DIR}/id_${SIGS[i]//-/_} -o PubKeyAcceptedKeyTypes=${SIGS_FULL[i]//_/-} -o KexAlgorithms=${KEMS_FULL[i]//_/-}"
    for j in $(eval echo {1..${NUM_LOOPS[i]}}); do
        evaldbg docker exec --user ${OQS_USER} -i ${DOCKER_OPTS} ${CONTAINER} ssh ${SSH_OPTS} ${OQS_USER}@${SERVER} 'exit 0'
        if [[ $? -eq 0 ]]; then
            echo "${SIGS[i]^^} and ${KEMS[i]^^}           ${j}/${NUM_LOOPS[i]} runs done "
        else
            echo "[FAIL] in run ${j}/${NUM_LOOPS[i]}"
            TEST_FAIL=1
            if [[ ${SIGKEM_FAIL[@]} != *"${SIGS[i]^^} and ${KEMS[i]^^}"* ]]; then
                SIGKEM_FAIL+=("${SIGS[i]^^} and ${KEMS[i]^^}")
            fi
        fi
    done
    pkill -9 ${TSHARK_PID}
    echo ""
done

if [ $TEST_FAIL -eq 0 ]; then
    echo "### [ OK ] ### All tests done!"
else
    echo -n "### [FAIL] ### There were problems with: "
    for FAIL in ${SIGKEM_FAIL[@]}; do
        echo "${FAIL} "
    done
    echo ""
fi