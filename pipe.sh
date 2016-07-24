#!/bin/bash

SDIR="$( cd "$( dirname "$0" )" && pwd )"

if [ "$#" -lt "1" ]; then
    echo "usage: S1Seq/pipe.sh SAMPLENAME SAMPLEDIR1 [SAMPLEDIR_N]"
    echo
    exit
fi

GENOME_DIR=/ifs/res/socci/LUX/ifs/data/bio/Genomes/S.cerevisiae/sacCer2/SGD/20080628
GENOME_FASTA=$GENOME_DIR/SGD_sacCer2.fa
GENOME_TAG=SGD_sacCer2
GENOME_INDEX=$GENOME_DIR/SHRiMP/DNA/$GENOME_TAG-ls
GENOME_BEDTOOLS=$GENOME_DIR/SGD_sacCer2.genome

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
for SAMPLEDIR in $SAMPLEDIRS; do
    for FASTQ in $(ls $SAMPLEDIR/*_R1_*fastq.gz); do

        mkdir -p $ODIR/$BLOCKNUM

        bsub -o LSF/ -J ${TAG}_1_$BLOCKNUM -We 59 \
            $SDIR/clipAdapterSE.sh $ODIR/$BLOCKNUM $FASTQ

        CLIPFASTQ=$ODIR/$BLOCKNUM/$(basename $FASTQ | sed 's/.fastq.gz//')___CLIP.fastq.gz

        bsub -o LSF/ -J ${TAG}_2_$BLOCKNUM -w "post_done(${TAG}_1_$BLOCKNUM)" -n 24 -We 59 \
            $SDIR/mapSHRiMP_SE.sh $GENOME_INDEX $CLIPFASTQ $SAMPLENAME

        SAM=$(echo $CLIPFASTQ | sed 's/.fastq.gz/___SHR_SE.sam/')

        bsub -o LSF/ -J ${TAG}_3_$BLOCKNUM -w "post_done(${TAG}_2_$BLOCKNUM)" -R "rusage[mem=36]" -n 3 -We 59\
            picard.local SortSam I=$SAM O=${SAM/.sam/.bam} SO=coordinate CREATE_INDEX=true

        bsub -o LSF/ -J ${TAG}_4_$BLOCKNUM -w "post_done(${TAG}_3_$BLOCKNUM)" -n 3 -We 59 \
            $SDIR/bam2UniqueStrandHitMap.sh $GENOME_BEDTOOLS ${SAM/.sam/.bam}

        BLOCKNUM=$((BLOCKNUM+1))

    done
done

~/Code/LSF/bSync/bHold ${TAG}_4_'\d+'
~/bin/notify.sh DONE

#bSync ${TAG}_3_'\d+'
