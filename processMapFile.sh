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
        | xargs bsub -o LSF.CONTROL/ -J S1Seq__${sample}__$(basename $MAPPING | sed 's/_sample_map.*//') \
            -R "rusage[iounits=0,mem=1]" \
            $SDIR/pipe.sh $sample
done
