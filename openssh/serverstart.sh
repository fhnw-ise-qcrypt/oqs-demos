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
fi

# Start the OQS SSH Daemon with the configuration as in /opt/oqssa/sshd_config
/opt/oqssa/sbin/sshd ${OPTIONS}

# Open a shell for local experimentation
if [ "x${CONNECT_TEST}" == "x" ]; then
    su - oqs -c sh
else
# return the options configuration in case of testing so the client can adapt
    echo ${OPTIONS}
fi