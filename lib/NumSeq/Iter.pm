package NumSeq::Iter;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(numseq_iter numseq_parse);

my $re_num = qr/(?:[+-]?[0-9]+(?:\.[0-9]+)?)/;

sub _numseq_parse_or_iter {
    my $which = shift;
    my $opts = ref($_[0]) eq 'HASH' ? shift : {};
    my $numseq = shift;

    my @nums;
    while ($numseq =~ s/\A(\s*,\s*)?($re_num)//) {
        die "Number sequence must not start with comma" if $1 && !@nums;
        push @nums, $2;
    }
    die "Please specify one or more number in number sequence: '$numseq'" unless @nums;

    my $has_ellipsis = 0;
    if ($numseq =~ s/\A\s*,\s*\.\.\.//) {
        die "Please specify at least three number in number sequence before ellipsis" unless @nums >= 3;
        $has_ellipsis++;
    }

    my $last_num;
    if ($numseq =~ s/\A\s*,\s*($re_num|[+-]?Inf)//) {
        $last_num = $1;
    }
    die "Extraneous token in number sequence: $numseq, please only use 'a,b,c, ...' or 'a,b,c,...,z'" if length $numseq;

    my ($is_arithmetic, $is_geometric, $inc);
  CHECK_SEQ_TYPE: {
        last unless $has_ellipsis;

      CHECK_ARITHMETIC: {
            my $inc0;
            for (1..$#nums) {
                if ($_ == 1) { $inc0 = $nums[1] - $nums[0] }
                elsif ($inc0 != ($nums[$_] - $nums[$_-1])) {
                    last CHECK_ARITHMETIC;
                }
            }
            $is_arithmetic++;
            $inc = $inc0;
            last CHECK_SEQ_TYPE;
        }

      CHECK_GEOMETRIC: {
            last if $nums[0] == 0;
            my $inc0;
            for (1..$#nums) {
                if ($_ == 1) { $inc0 = $nums[1] / $nums[0] }
                else {
                    last CHECK_GEOMETRIC if $nums[$_-1] == 0;
                    if ($inc0 != ($nums[$_] / $nums[$_-1])) {
                        last CHECK_GEOMETRIC;
                    }
                }
            }
            $is_geometric++;
            $inc = $inc0;
            last CHECK_SEQ_TYPE;
        }

        die "Can't determine the pattern from number sequence: ".join(", ", @nums);
    }

    if ($which eq 'parse') {
        return {
            numbers => \@nums,
            has_ellipsis => $has_ellipsis,
            ($has_ellipsis ? (last_number => $last_num) : ()),
            type => $is_arithmetic ? 'arithmetic' : ($is_geometric ? 'geometric' : 'itemized'),
            inc => $inc,
        };
    }

    my $i = 0;
    my $cur;
    my $ends;
    return sub {
        return undef if $ends;
        return $nums[$i++] if $i <= $#nums;
        if (!$has_ellipsis) { $ends++; return undef }

        $cur //= $nums[-1];
        if ($is_arithmetic) {
            $cur += $inc;
            if (defined $last_num) {
                if ($inc >= 0 && $cur > $last_num || $inc < 0 && $cur < $last_num) {
                    $ends++;
                    return undef;
                }
            }
            return $cur;
        } elsif ($is_geometric) {
            $cur *= $inc;
            if (defined $last_num) {
                if ($inc >= 1 && $cur > $last_num || $inc < 1 && $cur < $last_num) {
                    $ends++;
                    return undef;
                }
            }
            return $cur;
        }
    };
}

sub numseq_iter {
    _numseq_parse_or_iter('iter', @_);
}

sub numseq_parse {
    my $res;
    eval {
        $res = _numseq_parse_or_iter('parse', @_);
    };
    if ($@) { return [400, "Parse fail: $@"] }
    [200, "OK", $res];
}

1;
#ABSTRACT: Generate a coderef iterator from a number sequence specification (e.g. '1,3,5,...,101')

=for Pod::Coverage .+

=head1 SYNOPSIS

  use NumSeq::Iter qw(numseq_parse numseq_iter);

  my $iter = numseq_iter('1,3,5,...,13');
  while (my $val = $iter->()) { ... } # 1,3,5,7,9,11,13

  my $res = numseq_parse(''); # [400, "Parse fail: Please specify one or more number in number sequence"]
  my $res = numseq_parse('1,3,5');        # [200, "OK", {numbers=>[1,2,3], has_ellipsis=>0, type=>'arithmetic', inc=>2}]
  my $res = numseq_parse('1,3,9,...');    # [200, "OK", {numbers=>[1,3,9], has_ellipsis=>1, last_number=>undef, type=>'geometric', inc=>3}]
  my $res = numseq_parse('1,3,5,...,10'); # [200, "OK", {numbers=>[1,2,3], has_ellipsis=>1, last_number=>10, type=>'arithmetic', inc=>2}]


=head1 DESCRIPTION

This module provides a simple (coderef) iterator which you can call repeatedly
to get numbers specified in a number sequence specification (string). When the
numbers are exhausted, the coderef will return undef. No class/object involved.

A number sequence is a comma-separated list of numbers (either integer like 1,
-2 or decimal number like 1.3, -100.70) with at least one number. It can contain
an ellipsis (e.g. '1,2,3,...' or '1, 3, 5, ..., 10').

When the sequence has an ellipsis, there must be at least three numbers before
the ellipsis. There can optionally be another number after the ellipsis to make
the sequence finite; but the last number can also be Inf, +Inf, or -Inf.
Currently only simple arithmetic sequence ('1,3,5') or simple geometric sequence
('2,6,18') is recognized.


=head1 FUNCTIONS

=head2 numseq_iter

Usage:

 $iter = numseq_iter([ \%opts ], $spec); # coderef

Options:

=over

=back

=head2 numseq_parse

 my $res = numseq_parse([ \%opts ], $spec); # enveloped response

See L</numseq_iter> for list of known options.


=head1 SEE ALSO

L<IntRange::Iter>, L<Range::Iter>

Raku's lazy lists.

=cut
