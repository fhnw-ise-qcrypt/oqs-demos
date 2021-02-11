#!/bin/bash

DIR=${0%/*}
RESULTSDIR="${DIR}/measurements"
OUTPUTDIR="${DIR}/output"

PORT=${PORT:=2222}
DEBUGLVL=${DEBUGLVL:=0}

if [ $# -lt 1 ]; then
    echo "Provide the path to the *.pcap files you want to evaluate!"
    echo "Aborting..."
    exit 1
else
    PCAPDIR=${1%%/}
fi

function evaldbg {
    if [ $DEBUGLVL -ge 2 ]; then
        echo "Debug: Executing '$@'"
    fi
    eval $@
    return $?
}

echo "### Evaluation ###"
for FILE in ${PCAPDIR}/*; do
    [[ ! -f ${FILE} ]] && continue
    if [[ "${FILE}" == *".pcap" ]]; then
        FILENAME=${FILE##*/}
        FILENAME=${FILENAME:: -5}
        if [[ ! -d ${PCAPDIR}/csv ]]; then
            mkdir -p "${PCAPDIR}/csv"
        fi
        echo -n "Evaluating ${FILE}..."
        evaldbg ${DIR}/handshake_time_ssh --file ${FILE} --port ${PORT}
        if [[ $? -eq 0 ]]; then
            mv ${PCAPDIR}/${FILENAME}.csv ${PCAPDIR}/csv/${FILENAME}.csv
            echo " [ OK ]"
            echo "↳ Results in ${PCAPDIR}/csv/${FILENAME}.csv"
        else
            echo " [FAIL]"
        fi
    fi
done

echo ""
echo "### [ OK ] ###"