#!/bin/bash

SDIR="$( cd "$( dirname "$0" )" && pwd )"

GENOME_INDEX=$1
FASTQ=$2
SAMPLENAME=$3
ODIR=$(dirname $FASTQ)

$SDIR/bin/SHRiMP_2_1_1b/bin/gmapper-ls \
    -E -U -n 1 -Q --sam-unaligned --strata \
    -o 11 -N 24 \
    --read-group ${SAMPLENAME},${SAMPLENAME} --sam-unaligned \
    -L $GENOME_INDEX \
    $FASTQ \
    >$(echo $FASTQ | sed 's/.fastq.gz/___SHR_SE.sam/')
