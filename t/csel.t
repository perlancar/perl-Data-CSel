#!perl

use 5.010;
use strict;
use warnings;

use FindBin '$Bin';
use lib "$Bin/lib";

use Data::CSel qw(csel);
use Test::More 0.98;
use TN;
use TN1;
use TN2;

my $root;
my ($a1, $b11, $b12, $a2, $b21, $b22, $b23);
{
    # root (TN)
    #   a1 (TN)
    #     b11 (TN)
    #     b12 (TN2)
    #   a2 (TN)
    #     b21 (TN2)
    #     b22 (TN)
    #     b23 (TN1)
    $root = TN->new({id=>"root", kind=>"root"});
    $a1 = TN->new({id=>"a1", kind=>"a"}, $root);
    {
        $b11 = TN ->new({id=>"b11", kind=>"b"}, $a1);
        $b12 = TN2->new({id=>"b12", kind=>"b", bool=>1, defined=>undef, str=>"abc"}, $a1);
    }
    $a2 = TN->new({id=>"a2", kind=>"a"}, $root);
    {
        $b21 = TN2->new({id=>"b21", kind=>"b", bool=>0, defined=>1, str=>"cde"}, $a2);
        $b22 = TN ->new({id=>"b22", kind=>"b"}, $a2);
        $b23 = TN1->new({id=>"b23", kind=>"b"}, $a2);
    }
    #print $root->as_string;
}

subtest "simple selector: type selector" => sub {
    test_csel(
        expr   => "TN",
        nodes  => [$root],
        result => [$root, $a1, $a2, $b11, $b12, $b21, $b22, $b23],
    );
    test_csel(
        expr   => "TN2",
        nodes  => [$root],
        result => [$b12, $b21],
    );
};

subtest "simple selector: universal selector" => sub {
    test_csel(
        expr   => "*",
        nodes  => [$b21, $b23],
        result => [$b21, $b23],
    );
};

subtest "simple selector: attribute selector" => sub {
    test_csel(
        name   => 'without type',
        expr   => "[id eq 'b11']",
        nodes  => [$root],
        result => [$b11],
    );

    test_csel(
        name   => 'op:eq',
        expr   => "TN2[kind eq 'b']",
        nodes  => [$root],
        result => [$b12, $b21],
    );
    test_csel(
        name   => 'op:ne',
        expr   => "TN2[id ne 'b12']",
        nodes  => [$root],
        result => [$b21],
    );
    # XXX: op =, ==
    # XXX: op !=
    # XXX: op >
    # XXX: op >=
    # XXX: op <
    # XXX: op <=

    test_csel(
        name   => 'op:=~',
        expr   => "[str =~ /C/i]",
        nodes  => [$root],
        result => [$b12, $b21],
    );
    test_csel(
        name   => 'op:!~',
        expr   => "TN2[str !~ /a/i]",
        nodes  => [$root],
        result => [$b21],
    );

    test_csel(
        name   => 'op:is 1',
        expr   => "TN2[bool is true]",
        nodes  => [$root],
        result => [$b12],
    );
    test_csel(
        name   => 'op:is 2',
        expr   => "TN2[bool is false]",
        nodes  => [$root],
        result => [$b21],
    );
    test_csel(
        name   => 'op:is 3',
        expr   => "TN2[defined is null]",
        nodes  => [$root],
        result => [$b12],
    );

    test_csel(
        name   => 'op:isnt 1',
        expr   => "TN2[bool isnt true]",
        nodes  => [$root],
        result => [$b21],
    );
    test_csel(
        name   => 'op:isnt 2',
        expr   => "TN2[bool isnt false]",
        nodes  => [$root],
        result => [$b12],
    );
    test_csel(
        name   => 'op:isnt 3',
        expr   => "TN2[defined isnt null]",
        nodes  => [$root],
        result => [$b21],
    );
};

#subtest "simple selector: pseudo-class" => sub {
#};

#subtest "simple selector: attribute selector + pseudo-class" => sub {
#};

L1:
subtest "selector: combinator" => sub {
    test_csel(
        name   => "descendant",
        expr   => "[kind eq 'root'] TN1",
        nodes  => [$root],
        result => [$b23],
    );
    test_csel(
        name   => "child",
        expr   => "[kind eq 'root'] > TN1",
        nodes  => [$root],
        result => [],
    );
    test_csel(
        name   => "child",
        expr   => "[kind eq 'a'] > TN1",
        nodes  => [$root],
        result => [$b23],
    );
};

#subtest "selectors: comma" => sub {
#};

DONE_TESTING:
done_testing;

sub test_csel {
    my %args = @_;

    my $opts = $args{opts} // {};
    my @res = csel($opts, $args{expr}, @{$args{nodes}});

    my $res_ids = [map {$_->{id}} @res];
    my $exp_res_ids = [map {$_->{id}} @{ $args{result} }];

    subtest +($args{name} // $args{expr}) => sub {
        is_deeply($res_ids, $exp_res_ids, "result")
            or diag explain $res_ids;
    };
}
