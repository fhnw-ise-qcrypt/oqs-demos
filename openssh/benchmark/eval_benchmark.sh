#!/bin/bash

DIR=${0%/*}
RESULTSDIR="${DIR}/results"

PORT=${PORT:=2222}
DEBUGLVL=${DEBUGLVL:=0}

function evaldbg {
    if [ $DEBUGLVL -ge 2 ]; then
        echo "Debug: Executing '$@'"
    fi
    eval $@
    return $?
}

echo "### Evaluation ###"
for FILE in ${RESULTSDIR}/*; do
    if [[ "${FILE}" == *".pcap" ]]; then
        echo -n "Evaluating ${FILE}..."
        evaldbg ${DIR}/handshake_time_ssh --file ${FILE} --port $PORT
        if [[ $? -eq 0 ]]; then
            echo " [ OK ]"
            echo "↳ Results in ${FILE:: -5}.csv"
        else
            echo " [FAIL]"
        fi
    fi
done

echo ""
echo "### [ OK ] ###"