#!/bin/bash

SDIR="$( cd "$( dirname "$0" )" && pwd )"

if [ "$#" -lt "2" ]; then
    echo "usage: S1Seq/pipe.sh GENOME MAPPING_FILE"
    echo
    $SDIR/PEMapper/pipe.sh -g
    echo
    exit
fi

GENOME=$1
MAPPING_FILE=$2

$SDIR/PEMapper/runPEMapperMultiDirectories.sh $GENOME $MAPPING_FILE

