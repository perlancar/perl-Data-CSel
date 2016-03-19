#!perl

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Data::CSel qw(csel);
use Test::More 0.98;
use TN;
use TN2;

my $root;
my ($a1, $b11, $b12, $a2, $b21, $b22);
{
    # root (TN)
    #   a1 (TN)
    #     b11 (TN)
    #     b12 (TN2)
    #   a2 (TN)
    #     b21 (TN2)
    #     b22 (TN)
    $root = TN->new({id=>"root"});
    $a1 = TN->new({id=>"a1"}, $root);
    {
        $b11 = TN ->new({id=>"b11"}, $a1);
        $b12 = TN2->new({id=>"b12"}, $a1);
    }
    $a2 = TN->new({id=>"a2"}, $root);
    {
        $b21 = TN2->new({id=>"b21"}, $a2);
        $b22 = TN ->new({id=>"b22"}, $a2);
    }
}

subtest "simple selector: type selector" => sub {
    test_csel(
        expr   => "TN",
        nodes  => [$root],
        result => [$root, $a1, $b11, $a2, $b22],
    );
};

#subtest "simple selector: universal selector" => sub {
#};

#subtest "simple selector: attribute selector" => sub {
#};

#subtest "simple selector: pseudo-class" => sub {
#};

#subtest "simple selector: attribute selector + pseudo-class" => sub {
#};

#subtest "selector: combinator" => sub {
#};

#subtest "selectors: comma" => sub {
#};

DONE_TESTING:
done_testing;

sub test_csel {
    my %args = @_;

    my $opts = $args{opts} // {};
    my @res = csel($opts, $args{expr}, @{$args{nodes}});

    subtest +($args{name} // $args{expr}) => sub {
        is_deeply(\@res, $args{res}, "result")
            or diag explain \@res;
    };
}
