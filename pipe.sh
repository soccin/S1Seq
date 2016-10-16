#!/bin/bash

SDIR="$( cd "$( dirname "$0" )" && pwd )"

if [ "$#" -lt "1" ]; then
    echo "usage: S1Seq/pipe.sh GENOME SAMPLENAME SAMPLEDIR1 [SAMPLEDIR_N]"
    echo
    exit
fi

RSCRIPT=/opt/common/CentOS_6-dev/R/R-3.2.2/bin/Rscript

GENOME=$1
shift 1

if [ ! -e "$SDIR/genomes/$GENOME" ]; then
    echo "Invalid GENOME=[$GENOME]"
    echo "Valid genomes:"
    ls -1 $SDIR/genomes
    exit
fi

MEMSIZE=4
source $SDIR/genomes/$GENOME

# Echo genome parameters set

echo "GENOME_DIR      = $GENOME_DIR"
echo "GENOME_FASTA    = $GENOME_FASTA"
echo "GENOME_TAG      = $GENOME_TAG"
echo "GENOME_INDEX    = $GENOME_INDEX"
echo "GENOME_BEDTOOLS = $GENOME_BEDTOOLS"
echo "MEMSIZE         = $MEMSIZE"

SAMPLENAME=$1
shift 1
SAMPLEDIRS=$*

BASE=$SAMPLENAME
echo $BASE

ODIR=out/${BASE}____${GENOME_TAG}
mkdir -p $ODIR
echo $ODIR

TAG=qS1SEQ_$$__$(uuidgen)

BLOCKNUM=1
declare -a HITMAPS

for SAMPLEDIR in $SAMPLEDIRS; do
    for FASTQ in $(ls $SAMPLEDIR/*_R1_*fastq.gz); do

        mkdir -p $ODIR/$BLOCKNUM

        bsub -We 59 -o LSF/ -J ${TAG}_1_$BLOCKNUM \
            $SDIR/clipAdapterSE.sh $ODIR/$BLOCKNUM $FASTQ $SDIR/adapter_TruSeqFull.sh

        CLIPFASTQ=$ODIR/$BLOCKNUM/$(basename $FASTQ | sed 's/.fastq.gz//')___CLIP.fastq.gz

        bsub -o LSF/ -J ${TAG}_2_$BLOCKNUM -w "post_done(${TAG}_1_$BLOCKNUM)" \
            -n 24 \
            -R "rusage[mem=$MEMSIZE]" \
            $SDIR/mapSHRiMP_SE.sh $GENOME_INDEX $CLIPFASTQ $SAMPLENAME

        SAM=$(echo $CLIPFASTQ | sed 's/.fastq.gz/___SHR_SE.sam/')

        bsub -We 59 -o LSF/ -J ${TAG}_3_$BLOCKNUM -w "post_done(${TAG}_2_$BLOCKNUM)" -R "rusage[mem=36]" -n 3 \
            picard.local SortSam I=$SAM O=${SAM/.sam/.bam} SO=coordinate CREATE_INDEX=true

        bsub -We 59 -o LSF/ -J ${TAG}_4_$BLOCKNUM -w "post_done(${TAG}_3_$BLOCKNUM)" -n 3 \
            $SDIR/bam2UniqueStrandHitMap.sh $GENOME_BEDTOOLS ${SAM/.sam/.bam}

        HITMAPS[$BLOCKNUM]=${SAM/.sam/}

        BLOCKNUM=$((BLOCKNUM+1))

    done
done

bSync ${TAG}_4_'\d+'

bsub -We 59 -o LSF/ -J ${TAG}_5 -n 3 -R "rusage[mem=36]" \
    picard.local MergeSamFiles O=$ODIR/${SAMPLENAME}___merge.bam CREATE_INDEX=true \
    $(find $ODIR | fgrep .bam | fgrep -v merge.bam | awk '{print "I="$1}')

bsub -We 59 -o LSF/ -J ${TAG}_6 -w "post_done(${TAG}_5)" -n 3 \
    $SDIR/getUniqueMaps.sh $ODIR/${SAMPLENAME}___merge.bam \
    $ODIR/${SAMPLENAME}___merge,unique.bam

bsub -We 59 -o LSF/ -J ${TAG}_7 -w "post_done(${TAG}_5)" -n 3 -R "rusage[mem=36]" \
    picard.local CollectAlignmentSummaryMetrics R=$GENOME_FASTA \
    O=$ODIR/${SAMPLENAME}___merge___AS.txt I=$ODIR/${SAMPLENAME}___merge.bam

bsub -We 59 -o LSF/ -J ${TAG}_8 -n 3 \
    $RSCRIPT --no-save $SDIR/mergeHitMaps.R \
        $ODIR/${SAMPLENAME}_HITMAP_.Rdata \
        $SAMPLENAME \
        ${HITMAPS[*]}

