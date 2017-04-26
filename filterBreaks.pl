#!/usr/bin/perl
use strict;
use warnings;
use 5.010;
use File::Basename;
use lib dirname (__FILE__); # check for local folder for modules

#File
#Chr	DelSt	DelEd	Reads	Len	GC	nonATGC	exLen	exSeq	delScore
#scaffold_1	0	35	1	35	31.4285714286	0	35	GTTTCATATGTATTACAAGCACTAAGCAAAGAAAG	1
#scaffold_1	35	54	2	19	25	0	20	GAAAGAAAGAAAGAAAAAGA	1

#USAGE perl filterBreaks.pl raw 5 5
#NOTE: Assume the the file name are formated accordingly: sample.0.res ; where 0 is sample name; should be numeric

my $dir=$ARGV[0]; #Directory 
my $Nnum=$ARGV[1]; #N Number
my $Breaklen=$ARGV[2]; #Breaks length
my $outDir="allBrkData";

mkdir $outDir;
my $wfhSTAT=write_fh("$outDir/sampleSTAT"); 
my @allSTAT;
foreach my $fp (glob("$dir/*.res")) { # Loop over all files in folder
  		#printf "%s\n", $fp;
  		my @sampleName = split('\.', $fp);
  		#print "$sampleName[1]\n";
  		my $fh=read_fh($fp); #File here
		my $wfh=write_fh("$outDir/sample.$sampleName[1].txt");
		my @allBrkSize;
  		while(<$fh>) {
      			chomp; next if $. == 1; #Ignore header
      			my @val = split('\t', $_);
			#$val[6] is "N" number and $val[4] is break length
			if (($val[6] <= $Nnum) and ($val[4] >= $Breaklen)) {
				my $brkSize=$val[2]-$val[1];
				print $wfh "$val[0]\t$val[1]\t$val[2]\t$brkSize\t$sampleName[1]\n";
				push @allBrkSize, $brkSize;
			}
		}
		my @allBrkSize_sorted=sort {$a <=> $b} @allBrkSize;
		my $median=median(@allBrkSize); my $mean=mean(@allBrkSize); my $std_dev=std_dev(@allBrkSize);	
		push @allSTAT, "sample.$sampleName[1]\t$median\t$mean\t$std_dev\t$allBrkSize_sorted[0]\t$allBrkSize_sorted[-1]";
		close $fh; close $wfh; undef @allBrkSize;
}

if (-z "$outDir/sampleSTAT") { print $wfhSTAT "Sample\tMedian\tMean\tStandard Dev\tMin\tMax\n";}
foreach (@allSTAT) { print $wfhSTAT "$_\n"; } close $wfhSTAT;

# Open and Read a file
sub read_fh {
    my $filename = shift @_;
    my $filehandle;
    if ($filename =~ /gz$/) {
        open $filehandle, "gunzip -dc $filename |" or die $!;
    }
    else {
        open $filehandle, "<$filename" or die $!;
    }
    return $filehandle;
}


# Open and Read a file
sub write_fh {
    my $filename = shift @_;
    my $filehandle;
    open $filehandle, ">$filename" or die $!;
    return $filehandle;
}


sub mean {
    my (@data) = @_;
    my $sum;
    foreach (@data) {
        $sum += $_;
    }
    return ( $sum / @data );
}
sub median {
    my (@data) = sort { $a <=> $b } @_;
    if ( scalar(@data) % 2 ) {
        return ( $data[ @data / 2 ] );
    } else {
        my ( $upper, $lower );
        $lower = $data[ @data / 2 ];
        $upper = $data[ @data / 2 - 1 ];
        return ( mean( $lower, $upper ) );
    }
}
sub std_dev {
    my (@data) = @_;
    my ( $sq_dev_sum, $avg ) = ( 0, 0 );

    $avg = mean(@data);
    foreach my $elem (@data) {
        $sq_dev_sum += ( $avg - $elem )**2;
    }
    return ( sqrt( $sq_dev_sum / ( @data - 1 ) ) );
}

