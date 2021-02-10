#!/bin/bash

DIR=${0%/*}
RESULTSDIR="${DIR}/measurements"
OUTPUTDIR="${DIR}/output"

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
    [[ ! -f ${FILE} ]] && continue
    if [[ "${FILE}" == *".pcap" ]]; then
        FILENAME=${FILE##*/}
        FILENAME=${FILENAME:: -5}
        DATETIME=${FILENAME::19}
        if [[ ! -d ${OUTPUTDIR}/${DATETIME} ]]; then
            mkdir -p "${OUTPUTDIR}/${DATETIME}"
        fi
        echo -n "Evaluating ${FILE}..."
        evaldbg ${DIR}/handshake_time_ssh --file ${FILE} --port ${PORT}
        if [[ $? -eq 0 ]]; then
            mv ${RESULTSDIR}/${FILENAME}.csv ${OUTPUTDIR}/${DATETIME}/${FILENAME:20}.csv
            echo " [ OK ]"
            echo "↳ Results in ${OUTPUTDIR}/${DATETIME}/${FILENAME:20}.csv"
        else
            echo " [FAIL]"
        fi
    fi
done

echo ""
echo "### [ OK ] ###"