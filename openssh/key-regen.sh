#!/bin/bash
# set -ex
# Defaults
REGEN_IDS=${REGEN_IDS:=yes}
REGEN_HOST_KEYS=${REGEN_HOST_KEYS:=yes}

if [ "x${EUID}" != "x0" ]; then
    echo "Must be root! Aborting..."
    exit 1
fi

# Check if identities should be re-generated
if [ "x${REGEN_IDS^^}" == "xYES" ] || [ "x${REGEN_IDS^^}" == "xON" ]; then
    # Get all active identity files from ssh_config and generate a file for each
    ID_DIR="/home/${OQS_USER}/.ssh"
    readarray ID_ALGS <<< $(sed -n "s:^identityfile.*/id_::Ip" ${OQS_INSTALL_DIR}/ssh_config)
    echo -n "Generating identity files as configured in ${OQS_INSTALL_DIR}/ssh_config:"
    for alg in ${ID_ALGS[@]}; do
        echo -n " ${alg^^}"
        if [ $alg == "rsa" ] || [ $alg == "dsa" ] || [ $alg == "ecdsa*" ] || [ $alg == "ed25519*" ]; then
            alg_pre=''
        else
            alg_pre='ssh-'
        fi
        ID_FILE=${ID_DIR}/id_${alg}
        if [ -e $ID_FILE ]; then
            rm $ID_FILE
        fi
        CMD="su ${OQS_USER} -c \"${OQS_INSTALL_DIR}/bin/ssh-keygen -t $alg_pre$(echo $alg | sed 's/_/-/g') -f $ID_FILE -N '' -q\""
        # echo $CMD
        eval $CMD
    done
    echo " done!"

    # Clear authorized_keys
    echo -n "Clearing ${ID_DIR}/authorized_keys ..."
    echo "" > ${ID_DIR}/authorized_keys
    echo " done!"
fi

# Check if host-keys should be re-generated
if [ "x${REGEN_HOST_KEYS^^}" == "xYES" ] || [ "x${REGEN_HOST_KEYS^^}" == "xON" ]; then
    # Regenerate existing host keys
    HOST_KEY_DIR=$(echo $OQS_INSTALL_DIR | sed 's:/*$::')
    echo -n "Re-generating host key files so they match the listed HostKeyAlgorithms in $OQS_INSTALL_DIR/sshd_config as only those will be offered: "

    # Get algorithms from sshd_config
    IFS=',' read -ra HOST_KEY_ALGS <<< $(sed -n "s/^hostkeyalgorithms[ \t=]*//Ip" ${OQS_INSTALL_DIR}/sshd_config)

    rm -f $OQS_INSTALL_DIR/ssh_host_*
    # Generate new host key for each found host key algorithm
    for alg in "${HOST_KEY_ALGS[@]}"; do
        echo -n "${alg^^} "
        ${OQS_INSTALL_DIR}/bin/ssh-keygen  -t $alg -f "${HOST_KEY_DIR}/ssh_host_$(echo $alg | sed 's/^ssh-//;s/-/_/g')_key" -N '' -q -h
    done
    echo " done!"
fi

rc-service sshd restart