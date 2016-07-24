#!/bin/bash

SDIR="$( cd "$( dirname "$0" )" && pwd )"

INPUT=$1
OUTPUT=$2

samtools view -h $INPUT | egrep "(NH:i:1[^0-9]|^@)" | samtools view -bS - >$OUTPUT

