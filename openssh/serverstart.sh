#!/bin/sh

OPTIONS=""

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
    SSH_DIR="/opt/oqssa/"
    HOST_KEY_FILE="${SSH_DIR}/ssh_host_${SIG//-/_}_key"
    OPTIONS="${OPTIONS} -h ${HOST_KEY_FILE}"
fi


# Start the OQS SSH Daemon with the configuration as in /opt/oqssa/sshd_config
/opt/oqssa/sbin/sshd ${OPTIONS}

# Open a shell for local experimentation if not testing the connection
if [ "x${CONNECT_TEST}" == "x" ]; then
    sh
fi

