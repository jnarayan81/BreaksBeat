use List::Util qw(max);

use strict;
use warnings;

# Skip Header row
<DATA>;

# With only 60k rows, going to just slurp all the data
my %chroms;
while (<DATA>) {
    chomp;
    my ($chrom, $start, $end, $pgb) = split ' ';

    # Basic Data Validation.
    warn "chromStart is NaN, '$start'" if $start =~ /\D/;
    warn "chromEnd is NaN, '$end'" if $end =~ /\D/;
    warn "range not ordered, '$start' to '$end'" if $start > $end;
    warn "PGB only can be 1 or 2, '$pgb'" if ($pgb ne '1' && $pgb ne '2');

    push @{$chroms{$chrom}{$pgb}}, [$start, $end];
}

print "chrom    chromStart  chromEnd    PGB\n";

# Process each Chrom
for my $chrom (sort keys %chroms) {
    for my $pgb (sort keys %{$chroms{$chrom}}) {
        my $ranges = $chroms{$chrom}{$pgb};

        # Sort Ranges
        @$ranges = sort {$a->[0] <=> $b->[0] || $a->[1] <=> $b->[1]} @$ranges;

        # Combine overlapping and continguous ranges.
        # - Note because we're dealing with integer ranges, 1-4 & 5-8 are contiguous
        for my $i (0..$#$ranges-1) {
            if ($ranges->[$i][1] >= $ranges->[$i+1][0] - 1) {
                $ranges->[$i+1][0] = $ranges->[$i][0];
                $ranges->[$i+1][1] = max($ranges->[$i][1], $ranges->[$i+1][1]);
                $ranges->[$i] = undef;
            }
        }
        @$ranges = grep {$_} @$ranges;
    }

    # Create pgb=3 for overlaps.
    # - Save old ranges into aliases, and then start fresh
    my $pgb1array = $chroms{$chrom}{1};
    my $pgb2array = $chroms{$chrom}{2};
    my @ranges;

    # Always working on the first range in each array, until one of the arrays is empty
    while (@$pgb1array && @$pgb2array) {
        # Aliases to first element
        my $pgb1 = $pgb1array->[0];
        my $pgb2 = $pgb2array->[0];

        # PGB1 < PGB2
        if ($pgb1->[1] < $pgb2->[0]) {
            push @ranges, [@{shift @$pgb1array}, 1]

        # PGB2 < PGB1
        } elsif ($pgb2->[1] < $pgb1->[0]) {
            push @ranges, [@{shift @$pgb2array}, 2]

        # There's overlap for all rest 
        } else {
            # PGB1start < PGB2start
            if ($pgb1->[0] < $pgb2->[0]) {
                push @ranges, [$pgb1->[0], $pgb2->[0]-1, 1];
                $pgb1->[0] = $pgb2->[0];

            # PGB2start < PGB1start
            } elsif ($pgb2->[0] < $pgb1->[0]) {
                push @ranges, [$pgb2->[0], $pgb1->[0]-1, 2];
                $pgb2->[0] = $pgb1->[0];
            }
            # (Starts are equal now)

            # PGB1end < PGB2end
            if ($pgb1->[1] < $pgb2->[1]) {
                $pgb2->[0] = $pgb1->[1] + 1;
                push @ranges, [@{shift @$pgb1array}, 3];

            # PGB2end < PGB1end
            } elsif ($pgb2->[1] < $pgb1->[1]) {
                $pgb1->[0] = $pgb2->[1] + 1;
                push @ranges, [@{shift @$pgb2array}, 3];

            # PGB2end = PGB1end
            } else {
                push @ranges, [@$pgb1, 3];
                shift @$pgb1array;
                shift @$pgb2array;
            }
        }
    }

    # Append whichever is left over
    push @ranges, map {$_->[2] = 1; $_} @$pgb1array;
    push @ranges, map {$_->[2] = 2; $_} @$pgb2array;

    printf "%-8s %-11s %-11s %s\n", $chrom, @$_ for (@ranges);
}

1;

__DATA__
chrom   chromStart  chromEnd    PGB
chr1    12871   12873   2
chr1    12874   28371   2
chr1    15765   21765   1
chr1    15795   28371   2
chr1    18759   24759   1
chr1    28370   34961   1
chr3    233278  240325  1
chr3    239279  440831  2
chr3    356365  362365  1
