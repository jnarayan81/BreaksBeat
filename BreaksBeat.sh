#!/bin/bash

# A pipeline to check explore the breaks in genome
# Jitendra Narayan



: '
# GENERAL location settings for checker
scriptLoc=/home/urbe/Tools/MyTools/checkerG/scriptBase
rGenome=/home/urbe/Tools/MyTools/checkerG/Contig_0_1_10.fa
tGenome=/home/urbe/Tools/MyTools/checkerG/MergedContigs.fasta
genomeFileName=Contig_0_1_10.fa

config=/home/urbe/Tools/MyTools/checkerG/lastZconfig
R1=/media/urbe/MyDDrive/OriginalReads/ANature/GC027568.151120_Adineta_Nature_and_Habrotrocha.160226.HiSeq2000.FCB.lane1.gcap_dev.R1.fastq
R2=/media/urbe/MyDDrive/OriginalReads/ANature/GC027568.151120_Adineta_Nature_and_Habrotrocha.160226.HiSeq2000.FCB.lane1.gcap_dev.R2.fastq
$readType=short
$longR=
readLen=251

# General thresholds and folders
DIR=OutData

#=========================================================================================================================================

# DATE today
Now_hourly=$(date +%d-%b-%H_%M)
Now_daily=$(date +%d-%b-daily)
echo "$Now_hourly"
echo "$Now_daily"

# Clean up the fasta header
awk '{print $1}' $rGenome > rGenome.fa

# CHECK directory
if [ -d "$DIR" ]; then
read -p "Are you sure you want to delete the folder -- continue? <y/N> " prompt
if [[ $prompt == "y" || $prompt == "Y" || $prompt == "yes" || $prompt == "Yes" ]] && [[ -d "$DIR" ]]
then
  printf '%s\n' "Removing Directory ($DIR)"
  rm -rf "$DIR"
else
  exit 0
fi
fi

# Create DIR
mkdir $DIR; cd $DIR

# LastZ alignment
echo "Align to genome"
perl $scriptLoc/parallelLastZ.pl -q $rGenome -t $tGenome -c $config -s 4 -l 1000

echo "Move all alignment to ALN folder"
mkdir 'ALN'
mv *.lz  ALN

cd ALN

for f in *.lz
do
	echo "Processing $f"
	echo "Filtering direct overlaps/alignments"
	perl $scriptLoc/filterOverlaps.pl $f > $f.bed

done

# find . -name "*.lz" -size 0 -delete

cat *.bed > allALN.bed
cp allALN.bed ..

echo "Come out of the dir"
cd ..

#General for simple reformatting ... strand for merge 
echo "Merge overlapping blocks of interest +/-"
perl $scriptLoc/mergeOverlaps.pl allALN.bed general > finalALN.bed

echo "Create the faidx"
samtools faidx $rGenome

# Size of the genome - using fai file of samtools
#perl -e '$total = 0; while(<>){chomp();($id, $length) = split(/\t/); $total += $length;}; printf "$total\n"' $rGenome.fai
# Return the genome size in a variable.

echo "Checking the genome size"
genomesize=$(perl -e '$total = 0; while(<>){chomp();($id, $length) = split(/\t/); $total += $length;}; printf "$total\n"' $rGenome.fai)

echo "extract all breaks location"
perl $scriptLoc/findBRK.pl finalALN.bed final_breakspoints.txt $rGenome.fai 1

echo "Looking for TRF"
$scriptLoc/trf/trf409.linux64 $rGenome 2 7 7 80 10 50 500 -f -d -m
perl $scriptLoc/trf/trfparser_v1.pl $genomeFileName.2.7.7.80.10.50.500.dat 1
rm -rf *.tmp *.html *.mask *.txt.parse *.dat.parse *.dat

echo "Remove the small contigs" # Put the number here to filter
perl $scriptLoc/removeSmall.pl 0 $rGenome > newGenome.fa

# MAPPING reads
#----------------------------------------------------------------------------------------------
echo "Map the contigs"
bwa index newGenome.fa

if [ "$readType" == "long" ]
then
  echo "You have long Pacbio reads"
  bwa mem -x pacbio newGenome.fa $longR > aln.sam
else
  echo "You have small PE reads"
  bwa mem -M -t 16 newGenome.fa $R1 $R2 > aln.sam
fi

echo "Sam to Bam conversion"
samtools view -Sb  aln.sam  >  aln.bam
#-----------------------------------------------------------------------------------------------

# Sort the BAM file
echo "Sort the BAM file"
samtools sort -T /tmp/aln.sorted -o aln.sorted.bam aln.bam

#just the total number of "mapped reads" divided by the "size of the reference genome" for average coverage
echo "Looking for global coverage"
allMappedReads=$(samtools view -c -F 4 aln.sorted.bam)

#Average coverage
#number of reads * read length / target size
avarageCoverage=$($allMappedReads * $readLen/$genomesize);

echo "Avarage coverage = $averageCoverage";

# If the bam files are indexed the fastest way to get the number of mapped reads on each chromosome is:
#samtools index myfile.bam
#samtools idxstats myfile.bam

# Create genomecov file
echo "checking for genome coverage"
bedtools genomecov -ibam aln.sorted.bam -bga -split > allCoverage.bed

# AbnormalCoverage.bed contain the regions with coverage >= averageCoverage X 2
# Extract all the region with "Abnormally high coverage" ... i.e coverage >= averageCoverage X 2
perl $scriptLoc/extractAbnormalCoverage.pl allCoverage.bed $avarageCoverage > AbnoralCoverageRegion.bed

# Look into depth
#samtools depth $bamFile  |  awk '{sum+=$3; sumsq+=$3*$3} END { print "Average = ",sum/NR; print "Stdev = ",sqrt(sumsq/NR - (sum/NR)**2)}'

# Create final GFF result file for visualization
echo "Creating final GFF file in detail"
perl $scriptLoc/createFinalGFF.pl final_breakspoints.txt $genomeFileName.2.7.7.80.10.50.500.final.parse allCoverage.bed 1000 newGenome.fa avarageCoverage > final.gff

'

echo "All Done\n";

