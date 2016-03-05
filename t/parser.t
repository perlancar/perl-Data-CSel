#!perl

use 5.010;
use strict;
use warnings;

use Data::CSel::Parser qw(parse_csel_expr);
use Test::More 0.98;

subtest "empty" => sub {
    test_parse(
        name=>"empty string",
        expr=>"",
        fail=>,1,
    );
    test_parse(
        name=>"space",
        expr=>" ",
        fail=>1,
    );
};

subtest "simple selector: type selector" => sub {
    test_parse(
        expr=>"t",
        res=>{selectors=>[[{type=>"t"}]]},
    );
    test_parse(
        name=>":: allowed",
        expr=>"T::T2",
        res=>{selectors=>[[{type=>"T::T2"}]]},
    );
    test_parse(
        name=>"invalid type name",
        expr=>"2",
        fail=>1,
    );
};

subtest "simple selector: universal selector" => sub {
    test_parse(
        name=>"*",
        expr=>"*",
        res=>{selectors=>[[{type=>"*"}]]},
    );
};

subtest "simple selector: attribute selector" => sub {
    test_parse(
        expr=>"t[attr]",
        res=>{selectors=>[
            [{type=>"t", filters=>[
                {type=>"attr_selector", attr=>"attr"},
            ]}],
        ]},
    );
    test_parse(
        expr=>"t[attr=1]",
        res=>{selectors=>[
            [{type=>"t", filters=>[
                {type=>"attr_selector", attr=>"attr", op=>"=", value=>1},
            ]}],
        ]},
    );
    test_parse(
        name=>"whitespace allowed between attr name, operator, value",
        expr=>"t[attr = 1]",
        res=>{selectors=>[
            [{type=>"t", filters=>[
                {type=>"attr_selector", attr=>"attr", op=>"=", value=>1},
            ]}],
        ]},
    );
};

subtest "multiple selectors: comma" => sub {
    test_parse(
        expr=>"t,t2" ,
        res=>{selectors=>[ [{type=>"t"}], [{type=>"t2"}] ]},
    );
    test_parse(
        name=>"whitespace allowed",
        expr=>"t, t2",
        res=>{selectors=>[ [{type=>"t"}], [{type=>"t2"}] ]},
    );
};

DONE_TESTING:
done_testing;

sub test_parse {
    my %args = @_;

    my $res = parse_csel_expr($args{expr});

    subtest +($args{name} // $args{expr}) => sub {
        if ($args{fail}) {
            ok(!$res, "parse fail") or diag explain $res;
            return;
        }
        is_deeply($res, $args{res}, "parse result")
            or diag explain $res;
    };
}
