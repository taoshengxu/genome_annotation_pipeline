#!/usr/bin/bash

set -e
set -u
set -o pipefail

#module load maker/2.31.11

if [ $# -lt 3 ]; then
    echo "$0 datastore_index.log genome.fa specie_name"
    exit 1
fi

# set variable name
ds_index=$1
genome=$2
specie=$3

# get the script path
PWD=$(dirname $(readlink -f "$0"))

# create species
if [ -z $AUGUSTUS_CONFIG_PATH ];then
    new_species.pl --species=${specie}
else
    new_species.pl --species=${specie} --AUGUSTUS_CONFIG_PATH=$AUGUSTUS_CONFIG_PATH
fi

# create augustus
mkdir augustus && cd augustus

# output the gff and fasta
gff3_merge -n -g -d  $ds_index -s > maker.gff
fasta_merge -d  $ds_index -o maker.all

# get the high quality gff
python $PWD/maker_filter.py -e 1 -d 0 maker.gff > hc.gff

# compute the flanking region size
perl $PWD/compute_flanking_region.pl hc.gff
flank_size=$(cat flank_size.txt) 

# 
gff2gbSmallDNA.pl hc.gff $genome  $flank_size training.gb 
# first tranning
etraining --species=$specie training.gb 1> etraining.stdout 2> etraining.stderr

# filter the bad gene
perl -n -e 'm/n sequence (\S+):.*/; print "$1\n";' etraining.stderr > etrain.bad.lst
filterGenes.pl  etrain.bad.lst training.gb 1> training.f.gb

# randomSplit.pl training.f.gb 8000
perl -n -e '$_ =~/\/gene=\"(\S+)\"/ ;print "$1\n"' training.f.gb | sort -u > good_gene.lst

seqkit grep -f good_gene.lst ${prefix}.all.maker.proteins.fasta > good_gene_protein.fasta

# remove the redundant
perl $PWD/aa2nonred.pl --cores=100 --maxid=0.7 good_gene_protein.fasta traingenes.good.nr.fa 

seqkit seq -ni traingenes.good.nr.fa > traingenes.good.nr.txt
filterGenes.pl traingenes.good.nr.txt training.f.gb > training.ff.gb  
grep -c LOCUS training.gb training.f.gb training.ff.gb
cp training.ff.gb train.gb

# auto tranning
autoAugTrain.pl -v -v -v --trainingset=train.gb --species=${specie} --optrounds=5 --useexisting 1> autoAugTrain.log