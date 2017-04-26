use strict;
#use warnings;
use English;

#Cross compare many ranges and create a matrix
#Jitendra Narayan

#USAGE
# perl crossCompare.pl <folderName> <ids>

# NOTE: sampleData.0.txt ; Here 0 stands for sample number; should begin with 0
# The file name also contain the sample number in numeric format @ last column

my $dir = "$ARGV[0]"; # DIR containing all files
my $allIds="$ARGV[1]"; # File with all ids

# Store the ids in array
my $IDfh=read_fh($allIds); #Matrix file here
my @allIds;
  while(<$IDfh>) {
      chomp;
      #my @val = split('\t', $_);
      $_=~ s/\t/\:/g;
      push @allIds, $_;
   }

#Sorted with brk size descending order - to avoid the weired cases of missing brk
my @allIds_sorted = sort { (split "\t", $a)[0] cmp (split "\t", $b)[0] || (split "\t", $b)[3] <=> (split "\t", $a)[3] } @allIds;

my @finalResult;
foreach my $index (0..$#allIds_sorted) {
	my @Idval = split('\:', $allIds_sorted[$index]);
	foreach my $fp (glob("$dir/*.txt")) { # Loop over all files in folder
  		#printf "%s\n", $fp;
  		my @sampleName = split('\.', $fp);
  		#print "$sampleName[1]\n";

  		my $fh=read_fh($fp); #Matrix file here
		my @allOverlaps; my @allIdx;
  		while(<$fh>) {
      			chomp;
      			my @val = split('\t', $_);
			if ($Idval[0] eq $val[0]) { #Check if Ids match
				my $OverlapRes = checkCorOverlaps ($Idval[1], $Idval[2], $val[4], $val[5]);
				if ($OverlapRes) {
					my $brkSize=$val[5]-$val[4];
					push @allOverlaps, "$val[0]:$val[4]:$val[5]:$brkSize:$sampleName[1]";
					my( $idx )= grep { $allIds_sorted[$_] eq "$val[0]:$val[4]:$val[5]:$brkSize:$sampleName[1]" } 0..$#allIds_sorted;
					push @allIdx, $idx;	
					}
			}
   		}
		#Store all match and join them with ","
		foreach my $i (@allIdx) { undef $allIds_sorted[$i]; }
		$finalResult[$index][$sampleName[1]]= join (',', @allOverlaps);
   		close $fh; undef @allOverlaps; undef @allIdx;
	}
}

# Print the break matrix
print_2d_modified (@finalResult);

# See if any Ids does not match at all. If yes print them
my @remainingIds = grep { $_ ne '' } @allIds_sorted; #Remove the spaced from remaining set
#foreach my $v (@remainingIds) { print "$v --\n"; }

for(my $i = 0; $i <= $#remainingIds; $i++){
	my @name = split('\:', $remainingIds[$i]); #print "$name[-1]\t$remainingIds[$i]\n";
	my $loc=$name[-1];
	my $tabN;
	if ($loc) { $tabN="\t" x ($loc-1); }
	print "$tabN$remainingIds[$i]\n";
}

# Print the 2D array
sub print_2d_modified {
	my @array_2d=@_; my @row; my @rrow;
	for(my $i = 0; $i <= $#array_2d; $i++){
	   for(my $j = 0; $j <= $#{$array_2d[0]} ; $j++){
	      #print "$array_2d[$i][$j]\t";
	      my $r = trim ($array_2d[$i][$j]);
	      if ((defined $r) && $r ne "") { push @row, "$r"; }
	      push @rrow, "$array_2d[$i][$j]";
	   }
	   #Print only if row contain any values	
	   if (@row) { foreach my $ro (@rrow) {print "$ro\t";} print "\n";} undef @row; undef @rrow;
	}
}

# Perl trim function to remove whitespace from the start and end of the string
sub trim($)
{
	my $string = shift;
	$string =~ s/^\s+//;
	$string =~ s/\s+$//;
	$string =~ s/\t+//;
	return $string;
}

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

# Checks if a provided two coordinates overlaps or not
#my $OverRes = checkCorOverlaps ($StartCor[0], $EndCor[1], $tmp1[3], $tmp1[4]);
#Return 1 if overlaps

sub checkCorOverlaps {
my ($x1, $x2, $y1, $y2)=@_;
return $x1 <= $y2 && $y1 <= $x2;
}
