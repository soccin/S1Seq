#!/bin/bash
GENOME=$1
BAM=$2
BASE=${BAM%%.bam}
echo $BASE, $BAM

BEDTOOLS=/opt/common/CentOS_6-dev/bedtools/bedtools-2.25.0/bin/bedtools

#
# NH tag in SHRiMP is number of hits
# -tag NH puts NH number in col 5
# $5==1 UNIQUE hits

$BEDTOOLS bamtobed -tag NH -i $BAM \
    | awk '$5==1 && $6=="+"{print $1,$2,$2+1,$0}' \
    | tr ' ' '\t' \
    | $BEDTOOLS genomecov -i - -g $GENOME -d >${BASE}__PosHM.txt

$BEDTOOLS bamtobed -tag NH -i $BAM \
    | awk '$5==1 && $6=="-"{print $1,$3-1,$3,$0}' \
    | tr ' ' '\t' \
    | $BEDTOOLS genomecov -i - -g $GENOME -d >${BASE}__NegHM.txt

