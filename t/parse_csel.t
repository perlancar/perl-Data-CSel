#!perl

use 5.010;
use strict;
use warnings;

use Data::CSel qw(parse_csel);
use Test::More 0.98;

subtest "empty" => sub {
    test_parse(
        name=>"empty string",
        expr=>"",
        fail=>1,
    );
    test_parse(
        name=>"space",
        expr=>" ",
        fail=>1,
    );
};

subtest "simple selector: type selector" => sub {
    test_parse(
        expr=>"T",
        res=>[[{type=>"T"}]],
    );
    test_parse(
        name=>":: allowed",
        expr=>"T::T2",
        res=>[[{type=>"T::T2"}]],
    );
    test_parse(
        name=>"invalid type name",
        expr=>"2",
        fail=>1,
    );
};

subtest "simple selector: universal selector" => sub {
    test_parse(
        expr=>"*",
        res=>[[{type=>"*"}]],
    );
};

subtest "simple selector: attribute selector" => sub {
    test_parse(
        name => 'type selector is optional',
        expr=>"[attr]",
        res=>[
            [{type=>"*", filters=>[
                {type=>"attr_selector", attr=>"attr"},
            ]}],
        ],
    );

    test_parse(
        expr=>"T[attr]",
        res=>[
            [{type=>"T", filters=>[
                {type=>"attr_selector", attr=>"attr"},
            ]}],
        ],
    );
    test_parse(
        expr=>"T[attr=1]",
        res=>[
            [{type=>"T", filters=>[
                {type=>"attr_selector", attr=>"attr", op=>"=", value=>1},
            ]}],
        ],
    );
    test_parse(
        name=>"whitespace allowed between attr name, operator, value",
        expr=>"T[attr = 1]",
        res=>[
            [{type=>"T", filters=>[
                {type=>"attr_selector", attr=>"attr", op=>"=", value=>1},
            ]}],
        ],
    );
};

subtest "simple selector: pseudo-class" => sub {
    test_parse(
        name => 'type selector is optional',
        expr=>":foo",
        res=>[
            [{type=>"*", filters=>[
                {type=>"pseudoclass", pseudoclass=>"foo"},
            ]}],
        ],
    );
    test_parse(
        expr=>"T:foo",
        res=>[
            [{type=>"T", filters=>[
                {type=>"pseudoclass", pseudoclass=>"foo"},
            ]}],
        ],
    );
    test_parse(
        name => 'arguments',
        expr=>"T:foo(1, 'a')",
        res=>[
            [{type=>"T", filters=>[
                {type=>"pseudoclass", pseudoclass=>"foo", args=>[1, "a"]},
            ]}],
        ],
    );
    test_parse(
        name => 'multiple pseudo-classes',
        expr=>"T:foo(1, 'a'):bar",
        res=>[
            [{type=>"T", filters=>[
                {type=>"pseudoclass", pseudoclass=>"foo", args=>[1, "a"]},
                {type=>"pseudoclass", pseudoclass=>"bar"},
            ]}],
        ],
    );
};

subtest "simple selector: attribute selector + pseudo-class" => sub {
    test_parse(
        expr=>"T[attr][attr2]:foo(1, 'a'):bar",
        res=>[
            [{type=>"T", filters=>[
                {type=>"attr_selector", attr=>"attr"},
                {type=>"attr_selector", attr=>"attr2"},
                {type=>"pseudoclass", pseudoclass=>"foo", args=>[1, "a"]},
                {type=>"pseudoclass", pseudoclass=>"bar"},
            ]}],
        ],
    );
};

subtest "selector: combinator" => sub {
    test_parse(
        expr=>"T T2 > T3",
        res=>[
            [
                {type=>"T"},
                {combinator=>" "},
                {type=>"T2"},
                {combinator=>">"},
                {type=>"T3"},
            ],
        ],
    );
    test_parse(
        expr=>"T + T2 + T3",
        res=>[
            [
                {type=>"T"},
                {combinator=>"+"},
                {type=>"T2"},
                {combinator=>"+"},
                {type=>"T3"},
            ],
        ],
    );
    test_parse(
        expr=>"T ~ T2 ~ T3",
        res=>[
            [
                {type=>"T"},
                {combinator=>"~"},
                {type=>"T2"},
                {combinator=>"~"},
                {type=>"T3"},
            ],
        ],
    );
};

subtest "selectors: comma" => sub {
    test_parse(
        expr=>"T,T2" ,
        res=>[ [{type=>"T"}], [{type=>"T2"}] ],
    );
    test_parse(
        name=>"whitespace allowed",
        expr=>"T, T2",
        res=>[ [{type=>"T"}], [{type=>"T2"}] ],
    );
};

DONE_TESTING:
done_testing;

sub test_parse {
    my %args = @_;

    my $res = parse_csel($args{expr});

    subtest +($args{name} // $args{expr}) => sub {
        if ($args{fail}) {
            ok(!$res, "parse fail") or diag explain $res;
            return;
        }
        is_deeply($res, $args{res}, "parse result")
            or diag explain $res;
    };
}