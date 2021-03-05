#!/usr/bin/bash

set -e
set -u
set -o pipefail

#module load snap
#module load maker/2.31.11

if [ $# -lt 3 ]; then
    echo "$0 datastore_index.log round specie_name"
    exit 1
fi

ds_index=$1
round=$2
specie=$3

mkdir -p snap && cd snap
mkdir -p round${round} && cd round${round}

gff3_merge -d $ds_index -s > maker_round${round}.gff
maker2zff -x 0.25 -l 100 maker_round${round}.gff

fathom genome.ann genome.dna -gene-stats > gene-stats.log 2>&1 &
fathom genome.ann genome.dna -validate > validate.log 2>&1 &
fathom -categorize 1000 genome.ann genome.dna
fathom -export 1000 -plus uni.ann uni.dna

mkdir params && cd params
forge ../export.ann ../export.dna
cd ..

hmm-assembler.pl $specie params  > snap.hmm