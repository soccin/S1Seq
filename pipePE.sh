#!/bin/bash

SDIR="$( cd "$( dirname "$0" )" && pwd )"

if [ "$#" -lt "1" ]; then
    echo "usage: S1Seq_PE/pipePE.sh GENOME SAMPLENAME SAMPLEDIR1 [SAMPLEDIR_N]"
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
source $SDIR/genomes/$GENOME

#GENOME_DIR=/ifs/res/socci/LUX/ifs/data/bio/Genomes/S.cerevisiae/sacCer2/SGD/20080628
#GENOME_FASTA=$GENOME_DIR/SGD_sacCer2.fa
#GENOME_TAG=SGD_sacCer2
#GENOME_INDEX=$GENOME_DIR/SHRiMP/DNA/$GENOME_TAG-ls
#GENOME_BEDTOOLS=$GENOME_DIR/SGD_sacCer2.genome

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

        bsub -o LSF/ -J ${TAG}_1_$BLOCKNUM -We 59 \
            $SDIR/clipAdapterPE.sh $ODIR/$BLOCKNUM $FASTQ

        CLIPFASTQ=$ODIR/$BLOCKNUM/$(basename $FASTQ | sed 's/.fastq.gz//')___CLIP.fastq

        bsub -o LSF/ -J ${TAG}_2_$BLOCKNUM -w "post_done(${TAG}_1_$BLOCKNUM)" -n 24 -We 59 \
            $SDIR/mapSHRiMP_PE.sh $GENOME_INDEX $CLIPFASTQ $SAMPLENAME

        SAM=$(echo $CLIPFASTQ | sed 's/.fastq/___SHR_PE.sam/')

        bsub -o LSF/ -J ${TAG}_3_$BLOCKNUM -w "post_done(${TAG}_2_$BLOCKNUM)" -R "rusage[mem=36]" -n 3 -We 59\
            picard.local SortSam I=$SAM O=${SAM/.sam/.bam} SO=queryname CREATE_INDEX=true

        bsub -o LSF/ -J ${TAG}_4_$BLOCKNUM -w "post_done(${TAG}_3_$BLOCKNUM)" -n 3 -We 59 \
            $SDIR/bam2UniqueStrandHitMap.sh $GENOME_BEDTOOLS ${SAM/.sam/.bam}

        HITMAPS[$BLOCKNUM]=${SAM/.sam/}

        BLOCKNUM=$((BLOCKNUM+1))

    done
done

bSync ${TAG}_4_'\d+'

bsub -o LSF/ -J ${TAG}_5 -n 3 -R "rusage[mem=36]" \
    picard.local MergeSamFiles O=$ODIR/${SAMPLENAME}___merge.bam CREATE_INDEX=true \
    $(find $ODIR | fgrep .bam | fgrep -v merge.bam | fgrep -v ___UNIQ_PP.bam | awk '{print "I="$1}')

bsub -o LSF/ -J ${TAG}_6 -w "post_done(${TAG}_5)" -n 3 \
    $SDIR/getUniqueMaps.sh $ODIR/${SAMPLENAME}___merge.bam $ODIR/${SAMPLENAME}___merge,unique.bam

bsub -o LSF/ -J ${TAG}_7 -w "post_done(${TAG}_5)" -n 3 -R "rusage[mem=36]" \
    picard.local CollectAlignmentSummaryMetrics R=$GENOME_FASTA \
    O=$ODIR/${SAMPLENAME}___merge___AS.txt I=$ODIR/${SAMPLENAME}___merge.bam

bsub -o LSF/ -J ${TAG}_8 -n 3 -We 59 \
    $RSCRIPT --no-save $SDIR/mergeHitMaps.R \
        $ODIR/${SAMPLENAME}_HITMAP_.Rdata \
        $SAMPLENAME \
        ${HITMAPS[*]}

