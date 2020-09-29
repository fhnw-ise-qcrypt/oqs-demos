#!/bin/sh


# Correct id file exists? Create it if not

SSH_DIR="/home/oqs/.ssh"
SIG_ID_FILE="${SSH_DIR}/id_${SIG/-/_}"
if [ "x${SIG}" != "x" ] && [ ! -e ~/.ssh/id_${SIG} ]; then
    su oqs -c "/opt/oqssa/bin/ssh-keygen -t ssh-${SIG} -f ${SIG_ID_FILE} -N \"\" -q"
    cat ${SIG_ID_FILE}.pub >> ${SSH_DIR}/authorized_keys
    # echo "New key '${SIG_ID_FILE}(.pub)' created!"
fi

eval "export CONNECT_TEST=true; serverstart.sh"

# Evaluate if called as root
if [ "x${USER}" == "x" ]; then
    SSH="su oqs -c "
fi

# See if TEST_HOST was set, if not use default
if [ "x${TEST_HOST}" == "x" ]; then
    TEST_HOST="localhost"
fi

# default options
OPTIONS="-q -o BatchMode=yes -o StrictHostKeyChecking=no"

# See if TEST_TIME was set, if not use default
if [ "x${TEST_TIME}" == "x" ]; then
    TEST_TIME=3
fi
OPTIONS="${OPTIONS} -o ConnectTimeout=${TEST_TIME}"

# Optionally set port
# if left empty, the options defined in sshd_config will be used
if [ "x$SERVER_PORT" != "x" ]; then
    OPTIONS="${OPTIONS} -p ${SERVER_PORT}"
fi

# Optionally set KEM to one defined in https://github.com/open-quantum-safe/openssh#key-exchange
# if left empty, the options defined in sshd_config will be used
if [ "x$KEM" != "x" ]; then
    OPTIONS="${OPTIONS} -o KexAlgorithms=${KEM}-sha384@openquantumsafe.org"
fi

# Optionally set SIG to one defined in https://github.com/open-quantum-safe/openssh#digital-signature
# if left empty, the options defined in sshd_config will be used
if [ "x$SIG" != "x" ]; then
    OPTIONS="${OPTIONS} -o HostKeyAlgorithms=ssh-${SIG} -o PubkeyAcceptedKeyTypes=ssh-${SIG}"
fi

CMD="${SSH}\"ssh ${OPTIONS} ${TEST_HOST} 'exit 0'\""
# echo $CMD
eval $CMD

if [ $? -eq 0 ]; then
    echo "Successfully connected to ${TEST_HOST}!"
    exit 0
else
    echo "Failed connecting to ${TEST_HOST}!"
    exit 1
fi