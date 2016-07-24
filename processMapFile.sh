#!/bin/bash

SDIR="$( cd "$( dirname "$0" )" && pwd )"
MAPPING=$1

if [ "$#" -ne 1 ]; then
    echo "usage processMapFile.sh MAPPING_FILE"
    exit
fi

for sample in $(cat $MAPPING | cut -f2 | sort | uniq); do
    echo $sample;
    cat $MAPPING | awk -v S=$sample '$2==S{print $4}' \
        | xargs echo $SDIR/pipe.sh $sample
done
