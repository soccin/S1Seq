#!/bin/bash

SDIR="$( cd "$( dirname "$0" )" && pwd )"

if [ "$#" -lt "1" ]; then
    echo "usage: S1Seq_PE/pipePE.sh GENOME SAMPLENAME SAMPLEDIR1 [SAMPLEDIR_N]"
    echo
    exit
fi

#RSCRIPT=/opt/common/CentOS_6-dev/R/R-3.2.2/bin/Rscript
RSCRIPT=/opt/common/CentOS_7/R/R-3.6.1/bin/Rscript

MEMSIZE=1
LSF_WARG="-W 59"
LSF_WARG_LONG="-W 359"

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

        bsub -o LSF/ -J ${TAG}_1_$BLOCKNUM $LSF_WARG \
            $SDIR/clipAdapterPE.sh $ODIR/$BLOCKNUM $FASTQ

        CLIPFASTQ=$ODIR/$BLOCKNUM/$(basename $FASTQ | sed 's/.fastq.gz//')___CLIP.fastq

        bsub -o LSF/ -J ${TAG}_2_$BLOCKNUM -w "post_done(${TAG}_1_$BLOCKNUM)" -n 24 $LSF_WARG_LONG \
            -R "rusage[mem=$MEMSIZE]" \
            $SDIR/mapSHRiMP_PE.sh $GENOME_INDEX $CLIPFASTQ $SAMPLENAME

        SAM=$(echo $CLIPFASTQ | sed 's/.fastq/___SHR_PE.sam/')

        bsub -o LSF/ -J ${TAG}_3_$BLOCKNUM -w "post_done(${TAG}_2_$BLOCKNUM)" -R "rusage[mem=12]" -n 3 $LSF_WARG\
            picard.local AddOrReplaceReadGroups \
                SO=queryname \
                I=$SAM O=${SAM/.sam/.bam} \
                SM=$SAMPLENAME \
                LB=$SAMPLENAME \
                PU=$SAMPLENAME \
                PL=illumina

        bsub -o LSF/ -J ${TAG}_4_$BLOCKNUM -w "post_done(${TAG}_3_$BLOCKNUM)" -n 5 $LSF_WARG_LONG \
            $SDIR/bam2UniqueStrandHitMap.sh $GENOME_BEDTOOLS ${SAM/.sam/.bam}

        bsub -o LSF/ -J ${TAG}_4_2_$BLOCKNUM -w "post_done(${TAG}_3_$BLOCKNUM)" -n 5 $LSF_WARG_LONG \
            $SDIR/bam2UniqueStrandHitMapR2.sh $GENOME_BEDTOOLS ${SAM/.sam/.bam}


        HITMAPS[$BLOCKNUM]=${SAM/.sam/}

        BLOCKNUM=$((BLOCKNUM+1))

    done
done

echo =========
echo HITMAPS
echo $HITMAPS
echo

bSync ${TAG}_4_'\d+'

bsub -o LSF/ -J ${TAG}_5 -n 3 -R "rusage[mem=12]" $LSF_WARG \
    picard.local MergeSamFiles O=$ODIR/${SAMPLENAME}___merge.bam SO=coordinate CREATE_INDEX=true \
    $(find $ODIR | fgrep ___CLIP___SHR_PE.bam | fgrep -v merge.bam | awk '{print "I="$1}')

bsub -o LSF/ -J ${TAG}_6 -w "post_done(${TAG}_5)" -n 3 $LSF_WARG \
    $SDIR/getUniqueMaps.sh $ODIR/${SAMPLENAME}___merge.bam $ODIR/${SAMPLENAME}___merge,unique.bam

bsub -o LSF/ -J ${TAG}_7 -w "post_done(${TAG}_5)" -n 3 -R "rusage[mem=12]" $LSF_WARG \
    picard.local CollectAlignmentSummaryMetrics R=$GENOME_FASTA \
    O=$ODIR/${SAMPLENAME}___merge___AS.txt I=$ODIR/${SAMPLENAME}___merge.bam

bsub -o LSF/ -J ${TAG}_7 -w "post_done(${TAG}_5)" -n 3 -R "rusage[mem=12]" $LSF_WARG \
    picard.local CollectInsertSizeMetrics \
    I=$ODIR/${SAMPLENAME}___merge.bam \
    O=$ODIR/${SAMPLENAME}___merge___INS.txt \
    H=$ODIR/${SAMPLENAME}___merge___INS.pdf

bsub -o LSF/ -J ${TAG}_7.1 -w "post_done(${TAG}_5)" -n 3 -R "rusage[mem=12]" $LSF_WARG \
    picard.local MarkDuplicates REMOVE_DUPLICATES=true \
    I=$ODIR/${SAMPLENAME}___merge.bam \
    O=$ODIR/${SAMPLENAME}___merge___MD.bam \
    M=$ODIR/${SAMPLENAME}___merge___MD.txt

bsub -o LSF/ -J ${TAG}_8 -n 3 $LSF_WARG \
    $RSCRIPT --no-save $SDIR/mergeHitMaps.R \
        $ODIR/${SAMPLENAME}_HITMAP_.Rdata \
        $SAMPLENAME \
        ${HITMAPS[*]}

bsub -o LSF/ -J ${TAG}_8.2 -n 3 $LSF_WARG \
    $RSCRIPT --no-save $SDIR/mergeHitMaps.R \
        $ODIR/${SAMPLENAME}_HITMAP_R2.Rdata \
        $SAMPLENAME \
        ${HITMAPS[*]/___SHR_PE/___SHR_PE__R2}

bsub -o LSF/ -J ${TAG}_9 -w "post_done(${TAG}_7.1)" -n 3 $LSF_WARG \
    $SDIR/bam2UniqueStrandHitMap.sh $GENOME_BEDTOOLS $ODIR/${SAMPLENAME}___merge___MD.bam

bsub -o LSF/ -J ${TAG}_A -w "post_done(${TAG}_9)" $LSF_WARG \
    $RSCRIPT --no-save $SDIR/mergeHitMaps.R \
        $ODIR/${SAMPLENAME}_HITMAP_MarkDup.Rdata \
        $SAMPLENAME \
        $ODIR/${SAMPLENAME}___merge___MD
