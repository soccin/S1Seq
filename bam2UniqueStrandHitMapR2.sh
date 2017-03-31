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

# 0x042
# 0x040 == first read in pair
# 0x080 == second read in pair
# 0x002 == proper pair
#

(
    $SAMTOOLS view -H $BAM;
    $SAMTOOLS view -f 0x082 $BAM| fgrep -w "NH:i:1"
    ) \
| samtools view -Sb - >${BASE}___UNIQ_R2_PP.bam


#
# BAM now only have R1 reads in them so just do the normal
# bamtobed (not bedpe)
#
# We have already filter for NH:i:1 but no harm in doing again
#

$BEDTOOLS bamtobed -tag NH -i ${BASE}___UNIQ_R2_PP.bam \
    | awk '$5==1 && $6=="+"{print $1,$2,$2+1,$0}' \
    | tr ' ' '\t' \
    | sort -k1,1V -k2,2n \
    | $BEDTOOLS genomecov -i - -g $GENOME -d >${BASE}__R2__PosHM.txt

$BEDTOOLS bamtobed -tag NH -i ${BASE}___UNIQ_R2_PP.bam \
    | awk '$5==1 && $6=="-"{print $1,$3-1,$3,$0}' \
    | tr ' ' '\t' \
    | sort -k1,1V -k2,2n \
    | $BEDTOOLS genomecov -i - -g $GENOME -d >${BASE}__R2__NegHM.txt

