#!/bin/bash
GENOME=$1
BAM=$2
BASE=${BAM%%.bam}
echo $BASE, $BAM

BEDTOOLS=/opt/common/CentOS_6-dev/bedtools/bedtools-2.25.0/bin/bedtools
SAMTOOLS=/opt/common/CentOS_6-dev/samtools/samtools-1.3.1/samtools


#
# First get unique properly paired reads
#

(
    $SAMTOOLS view -H $BAM;
    $SAMTOOLS view -f2 $BAM| fgrep -w "NH:i:1"
    ) \
| samtools view -Sb - >${BASE}___UNIQ_PP.bam

#
# NH tag in SHRiMP is number of hits
# -tag NH puts NH number in col 5
# $5==1 UNIQUE hits

$BEDTOOLS bamtobed -bedpe -i ${BASE}___UNIQ_PP.bam \
    | awk '$9=="+"{print $1,$2,$2+1,$0}' \
    | tr ' ' '\t' \
    | sort -k1,1V -k2,2n \
    | $BEDTOOLS genomecov -i - -g $GENOME -d >${BASE}__PosHM.txt

$BEDTOOLS bamtobed -bedpe -i ${BASE}___UNIQ_PP.bam \
    | awk '$9=="-"{print $1,$6-1,$6,$0}' \
    | tr ' ' '\t' \
    | sort -k1,1V -k2,2n \
    | $BEDTOOLS genomecov -i - -g $GENOME -d >${BASE}__NegHM.txt

