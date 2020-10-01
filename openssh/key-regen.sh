#!/bin/bash


if [ "x${EUID}" != "x0" ]; then
    echo "Must be root! Aborting..."
    exit 1
fi


# Experimental: ALL_PUBS=$(ls ~/.ssh/ | sed -n '/id_.*.pub/p')
# Regenerate existing IDs
ID_DIR="/home/${OQS_USER}/.ssh"
echo -n "Re-generate existing ${ID_DIR}/id_* files ..."
rm ${ID_DIR}/*.pub
for FILE in ${ID_DIR}/id_*; do
    echo -n "."
    ALG=${FILE/#${ID_DIR}}
    ALG=${ALG//"/"}
    ALG=${ALG/#"id_"}
    ALG="ssh-${ALG//_/-}"
    rm ${FILE}
    CMD="su oqs -c \"ssh-keygen -q -t $ALG -f $FILE -N ''\""
    # echo $CMD
    eval $CMD
done
echo " done!"

# Clear authorized_keys
echo -n "Clearing ${ID_DIR}/authorized_keys ..."
echo "" > ${ID_DIR}/authorized_keys
echo " done!"

# Regenerate existing host keys
HOST_KEY_DIR=$(echo $OQS_INSTALL_DIR | sed 's:/*$::')
echo -n "Re-generate host key files (in $OQS_INSTALL_DIR/) so they match the listed HostKeyAlgorithms in $OQS_INSTALL_DIR/sshd_config as only those will be offered..."

# Get algorithms from ssh_config
IFS=',' read -ra HOST_KEY_ALGS <<< $(sed -n "s/^hostkeyalgorithms[ \t=]//Ip" ${OQS_INSTALL_DIR}/sshd_config)

rm -f $OQS_INSTALL_DIR/ssh_host_*
# Generate new host key for each found host key algorithm
for alg in "${HOST_KEY_ALGS[@]}"; do
    echo -n "."
    ${OQS_INSTALL_DIR}/bin/ssh-keygen  -t $alg -f "${HOST_KEY_DIR}/ssh_host_$(echo $alg | sed 's/^ssh-//;s/-/_/g')_key" -N '' -q
done
echo " done!"

rc-service sshd restart