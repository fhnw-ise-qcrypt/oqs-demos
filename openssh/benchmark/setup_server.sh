#!/bin/bash

DIR=${0%/*}


CONTAINER=${CONTAINER:="oqs-server"}
DOCKER_IMG=${DOCKER_IMG:="oqs-openssh-img"}
DOCKER_OPTS=${DOCKER_OPTS:=""}
PORT=${PORT:=2222}
DEBUGLVL=${DEBUGLVL:=0}

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
    ${DOCKER_OPTS} \
    ${DOCKER_IMG}"

# Get a list of key exchange algorithms
KEMS=()
while IFS="" read -r KEM; do
    [[ $KEM == "" ]] || [[ $KEM =~ ^#.* ]] && continue # If this looks weird: No worries, it works (=~ takes regex, but not as string)
    KEMS+=("$KEM")
done < "$DIR/listofkems.conf"

# Get list of signature algorithms
SIGS=()
while IFS="" read -r SIG; do 
    [[ $SIG == "" ]] || [[ $SIG =~ ^#.* ]] && continue # If this looks weird: No worries, it works (=~ takes regex, but not as string)
    SIGS+=("$SIG")
done < "$DIR/listofsigs.conf"

# Add pre and postfixes to algorithm names if needed
# KEM: ecdh-nistp384-<KEM>-sha384@openquantumsafe.org if PQC algorithm, else <KEM>
[[ $DEBUGLVL -ge 1 ]] &&
    echo "" &&
    echo "### Renaming KEMs ###"
for i in ${!KEMS[@]}; do
    [[ $DEBUGLVL -ge 1 ]] &&
        echo -n "${KEMS[i]} --> "
    if [[ ${KEMS[i],,} != "curve25519-sha256"* ]] && [[ ${KEMS[i],,} != "ecdh-sha2-nistp"* ]] && [[ ${KEMS[i],,} != "diffie-hellman-group"* ]]; then
        # Add postfix
        if [[ ${KEMS[i],,} != *"-sha384@openquantumsafe.org" ]]; then
            KEMS_FULL[i]="${KEMS[i],,}-sha384@openquantumsafe.org"
        fi
    else
        KEMS_FULL[i]="${KEMS[i],,}"
    fi
    [[ $DEBUGLVL -ge 1 ]] &&
        echo "${KEMS_FULL[i]}"
done
# SIG: ssh-<SIG> if PQC algorithm, else <SIG>
[[ $DEBUGLVL -ge 1 ]] &&
    echo "" &&
    echo "### Renaming SIGs ###"
for i in ${!SIGS[@]}; do
    [[ $DEBUGLVL -ge 1 ]] &&
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
    [[ $DEBUGLVL -ge 1 ]] &&
        echo "${SIGS_FULL[i]}"
done

# Make comma separated lists
SIG_LIST=${SIGS_FULL[@]}
SIG_LIST=${SIG_LIST// /,}
KEM_LIST=${KEMS_FULL[@]}
KEM_LIST=${KEM_LIST// /,}

echo ""

# Start sshd with all algorithms enabled
evaldbg "docker exec -t ${CONTAINER} /opt/oqs-ssh/sbin/sshd -o PubkeyAcceptedKeyTypes=${SIG_LIST} -o KexAlgorithms=${KEM_LIST} -p ${PORT}"

if [[ $? -eq 0 ]]; then
    echo "### [ OK ] ### Server set up successfully! Now set up the client."
else
    echo "### [FAIL] ### Error while setting up server!"
fi