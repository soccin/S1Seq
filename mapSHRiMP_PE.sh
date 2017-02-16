#!/bin/bash

SDIR="$( cd "$( dirname "$0" )" && pwd )"

GENOME_INDEX=$1
FASTQ=$2
SAMPLENAME=$3
ODIR=$(dirname $FASTQ)

OUTSAM=$(echo $FASTQ | sed 's/.fastq/___SHR_PE.sam/')
$SDIR/bin/SHRiMP_2_1_1b/bin/gmapper-ls \
    -E -U -n 1 -Q --sam-unaligned --strata \
    -o 11 -N 24 \
    -p opp-in -I 50,500 \
    --read-group ${SAMPLENAME},${SAMPLENAME} --sam-unaligned \
    -L $GENOME_INDEX \
    -1 $FASTQ \
    -2 ${FASTQ/_R1_/_R2_} \
    >$OUTSAM
