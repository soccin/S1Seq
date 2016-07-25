#!/bin/bash

SDIR="$( cd "$( dirname "$0" )" && pwd )"

MINLENGTH=15

ODIR=$1
FASTQ=$2
BASE=$(basename $FASTQ | sed 's/.fastq.*//')
ADAPTERS=$3

. $ADAPTERS

echo "$0"
echo MINLENGTH=$MINLENGTH
echo ADAPTERS_1=$ADAPTERS_1

gzcat $FASTQ | $SDIR/bin/fastx_clipper -a $ADAPTER_1 -n -Q33 \
    -l $MINLENGTH -v -z -o ${ODIR}/${BASE}___CLIP.fastq.gz
