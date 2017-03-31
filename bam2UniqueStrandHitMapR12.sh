#!/bin/bash
GENOME=$1
BAM=$2
BASE=${BAM%%.bam}
echo $BASE, $BAM

BEDTOOLS=/opt/common/CentOS_6-dev/bedtools/bedtools-2.25.0/bin/bedtools
SAMTOOLS=/opt/common/CentOS_6-dev/samtools/samtools-1.3.1/samtools


#
# Get properly paired reads (0x02)
# with unique maps (fgrep -w "NH:i:1")
# and then sort into queryname so bedtools bedpe
# works

#
# 0x002 == proper pair
#

(
    $SAMTOOLS view -H $BAM;
    $SAMTOOLS view -f 0x02 $BAM | fgrep -w "NH:i:1";
) \
    | samtools view -Sb - \
    | samtools sort -n - \
    >${BASE}___UNIQ_R12_PP.bam

#
# Use R1 read for + R2 for negative
#

$BEDTOOLS bamtobed -bedpe -i ${BASE}___UNIQ_R12_PP.bam \
    | awk '$9=="+"{print $1,$2,$2+1,$0}' \
    | tr ' ' '\t' \
    | sort -k1,1V -k2,2n \
    | $BEDTOOLS genomecov -i - -g $GENOME -d >${BASE}__R12__PosHM.txt

$BEDTOOLS bamtobed -bedpe -i ${BASE}___UNIQ_R12_PP.bam \
    | awk '$9=="-"{print $4,$6-1,$6,$0}' \
    | tr ' ' '\t' \
    | sort -k1,1V -k2,2n \
    | $BEDTOOLS genomecov -i - -g $GENOME -d >${BASE}__R12__NegHM.txt

