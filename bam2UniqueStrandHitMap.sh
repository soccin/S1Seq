#!/bin/bash
GENOME=$1
BAM=$2
BASE=${BAM%%.bam}
echo $BASE, $BAM

BEDTOOLS=/opt/common/CentOS_7/bedtools/bedtools-2.27.1/bin/bedtools
SAMTOOLS=/opt/common/CentOS_7/samtools/samtools-1.9/bin/samtools


#
# First get unique properly paired reads
#

# 0x042
# 0x040 == first pair
# 0x002 == proper pair
#

echo 1 $(date)

(
    $SAMTOOLS view -H $BAM;
    $SAMTOOLS view -f 0x042 $BAM| fgrep -w "NH:i:1"
    ) \
| samtools view -Sb - >${BASE}___UNIQ_R1_PP.bam

echo 2 $(date)

#
# BAM now only have R1 reads in them so just do the normal
# bamtobed (not bedpe)
#
# We have already filter for NH:i:1 but no harm in doing again
#

echo 3 $(date)

$BEDTOOLS bamtobed -tag NH -i ${BASE}___UNIQ_R1_PP.bam \
    | awk '$5==1 && $6=="+"{print $1,$2,$2+1,$0}' \
    | tr ' ' '\t' \
    | sort -S 4g -k1,1V -k2,2n \
    | $BEDTOOLS genomecov -i - -g $GENOME -d >${BASE}__PosHM.txt

echo 4 $(date)

$BEDTOOLS bamtobed -tag NH -i ${BASE}___UNIQ_R1_PP.bam \
    | awk '$5==1 && $6=="-"{print $1,$3-1,$3,$0}' \
    | tr ' ' '\t' \
    | sort -S 4g -k1,1V -k2,2n \
    | $BEDTOOLS genomecov -i - -g $GENOME -d >${BASE}__NegHM.txt

echo 5 $(date)

