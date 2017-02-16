#!/bin/bash

SDIR="$( cd "$( dirname "$0" )" && pwd )"

MINLENGTH=15

ODIR=$1
FASTQ=$2
BASE=$(basename $FASTQ | sed 's/.fastq.*//')

## R1
# Maximal common  AGATCGGAAGAGC


$SDIR/bin/clipAdapters.sh AGATCGGAAGAGC \
    $FASTQ \
    ${FASTQ/_R1_/_R2_} \
    ${ODIR} \
    $MINLENGTH


#gzcat $FASTQ | $SDIR/bin/fastx_clipper -a $ADAPTER_1 -n -Q33 \
#    -l $MINLENGTH -v -z -o ${ODIR}/${BASE}___CLIP.fastq.gz
