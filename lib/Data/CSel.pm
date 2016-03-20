package Data::CSel;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

#use List::Util qw(first);
use Scalar::Util qw(refaddr looks_like_number);

use Exporter qw(import);
our @EXPORT_OK = qw(
                       csel
                       parse_csel
               );

our $RE =
    qr{
          (?&SELECTORS) (?{ $_ = $^R->[1] })

          (?(DEFINE)
              (?<SELECTORS>
                  (?{ [$^R, []] })
                  (?&SELECTOR) # [[$^R, []], $selector]
                  (?{ [$^R->[0][0], [$^R->[1]]] })
                  (?:
                      \s*,\s*
                      (?&SELECTOR)
                      (?{
                          push @{$^R->[0][1]}, $^R->[1];
                          $^R->[0];
                      })
                  )*
                  \s*
              )

              (?<SELECTOR>
                  (?{ [$^R, []] })
                  (?&SIMPLE_SELECTOR) # [[$^R, []], $simple_selector]
                  (?{ [$^R->[0][0], [$^R->[1]]] })
                  (?:
                      (\s*>\s*|\s*\+\s*|\s*~\s*|\s+)
                      (?{
                          my $comb = $^N;
                          $comb =~ s/^\s+//; $comb =~ s/\s+$//;
                          $comb = " " if $comb eq '';
                          push @{$^R->[1]}, {combinator=>$comb};
                          $^R;
                      })

                      (?&SIMPLE_SELECTOR)
                      (?{
                          push @{$^R->[0][1]}, $^R->[1];
                          $^R->[0];
                      })
                  )*
              )

              (?<SIMPLE_SELECTOR>
                  (?:
                      (?:
                          # type selector + optional filters
                          ((?&TYPE_NAME))
                          (?{ [$^R, {type=>$^N}] })
                          (?:
                              (?&FILTER) # [[$^R, $simple_selector], $filter]
                              (?{
                                  push @{ $^R->[0][1]{filters} }, $^R->[1];
                                  $^R->[0];
                              })
                              (?:
                                  \s*
                                  (?&FILTER)
                                  (?{
                                      push @{ $^R->[0][1]{filters} }, $^R->[1];
                                      $^R->[0];
                                  })
                              )*
                          )?
                      )
                  |
                      (?:
                          # optional type selector + one or more filters
                          ((?&TYPE_NAME))?
                          (?{
                              # XXX sometimes $^N is ' '?
                              my $t = $^N // '*';
                              $t = '*' if $t eq ' ';
                              [$^R, {type=>$t}] })
                          (?&FILTER) # [[$^R, $simple_selector], $filter]
                          (?{
                              push @{ $^R->[0][1]{filters} }, $^R->[1];
                              $^R->[0];
                          })
                          (?:
                              \s*
                              (?&FILTER)
                              (?{
                                  push @{ $^R->[0][1]{filters} }, $^R->[1];
                                  $^R->[0];
                              })
                          )*
                      )
                  )
              )

              (?<TYPE_NAME>
                  [A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z0-9_]+)*|\*
              )

              (?<FILTER>
                  (?{ [$^R, {}] })
                  (
                      (?&ATTR_SELECTOR) # [[$^R, {}], [$attr, $op, $val]]
                      (?{
                          $^R->[0][1]{type}  = 'attr_selector';
                          $^R->[0][1]{attr}  = $^R->[1][0];
                          $^R->[0][1]{op}    = $^R->[1][1] if @{$^R->[1]} > 1;
                          $^R->[0][1]{value} = $^R->[1][2] if @{$^R->[1]} > 2;
                          $^R->[0];
                      })
                  |
                      (?&PSEUDOCLASS) # [[$^R, {}], [$pseudoclass]]
                      (?{
                          $^R->[0][1]{type}         = 'pseudoclass';
                          $^R->[0][1]{pseudoclass}  = $^R->[1][0];
                          $^R->[0];
                      })
                      (?:
                          \(\s*
                          (?&LITERAL)
                          (?{
                              push @{ $^R->[0][1]{args} }, $^R->[1];
                              $^R->[0];
                          })
                          (?:
                              \s*,\s*
                              (?&LITERAL)
                              (?{
                                  push @{ $^R->[0][1]{args} }, $^R->[1];
                                  $^R->[0];
                              })
                          )*
                          \s*\)
                      )?
                  )
              )

              (?<ATTR_SELECTOR>
                  \[\s*((?&ATTR_NAME))\s*\]
                  (?{ [$^R, [$^N]] })
              |
                  \[\s*
                  ((?&ATTR_NAME))
                  (?{ [$^R, [$^N]] })

                  (
                      \s*(?:=~|!~)\s* |
                      \s*(?:!=|>=?|<=?|==?)\s* |
                      \s+(?:eq|ne|lt|gt|le|ge)\s+ |
                      \s+(?:isnt|is)\s+
                  )
                  (?{
                      my $op = $^N;
                      $op =~ s/^\s+//; $op =~ s/\s+$//;
                      push @{$^R->[1]}, $op;
                      $^R;
                  })

                  ((?&LITERAL)) # [[$^R, [$attr, $op]], $literal]
                  (?{
                      push @{ $^R->[0][1] }, $^R->[1];
                      $^R->[0];
                  })
                  \s*\]
              )

              (?<ATTR_NAME>
                  [A-Za-z_][A-Za-z0-9_]*
              )

              (?<LITERAL>
                  (?&LITERAL_NUMBER)
              |
                  (?&LITERAL_STRING_DQUOTE)
              |
                  (?&LITERAL_STRING_SQUOTE)
              |
                  (?&LITERAL_REGEX)
              |
                  true (?{ [$^R, 1] })
              |
                  false (?{ [$^R, 0] })
              |
                  null (?{ [$^R, undef] })
              )

              (?<LITERAL_NUMBER>
                  (
                      -?
                      (?: 0 | [1-9]\d* )
                      (?: \. \d+ )?
                      (?: [eE] [-+]? \d+ )?
                  )
                  (?{ [$^R, 0+$^N] })
              )

              (?<LITERAL_STRING_DQUOTE>
                  (
                      "
                      (?:
                          [^\\"]+
                      |
                          \\ [0-7]{1,3}
                      |
                          \\ x [0-9A-Fa-f]{1,2}
                      |
                          \\ ["\\'tnrfbae]
                      )*
                      "
                  )
                  (?{ [$^R, eval $^N] })
              )

              (?<LITERAL_STRING_SQUOTE>
                  (
                      '
                      (?:
                          [^\\']+
                      |
                          \\ .
                      )*
                      '
                  )
                  (?{ [$^R, eval $^N] })
              )

              (?<LITERAL_REGEX>
                  (
                      /
                      (?:
                          [^\\]+
                      |
                          \\ .
                      )*
                      /
                      [ims]*
                  )
                  (?{ my $re = eval "qr$^N"; die if $@; [$^R, $re] })
              )

              (?<PSEUDOCLASS_NAME>
                  [A-Za-z_][A-Za-z0-9_]*(?:-[A-Za-z0-9_]+)*
              )

              (?<PSEUDOCLASS>
                  :((?&PSEUDOCLASS_NAME))
                  (?{ [$^R, [$^N]] })
              )
          ) # DEFINE
  }x;

sub parse_csel {
    local $_ = shift;
    local $^R;
    eval { m{\A\s*$RE\s*\z}; } and return $_;
    die $@ if $@;
    return undef;
}

sub _node_children {
    my $node = shift;
    my @c = $node->children;
    @c = @{$c[0]} if @c==1 && ref($c[0]) eq 'ARRAY';
    @c;
}

sub _node_descendants {
    my $node = shift;
    my @c = _node_children($node);
    (@c, map { _node_descendants($_) } _node_children($node));
}

sub _node_is_first_child {
    my $node = shift;
    my $parent = $node->parent;
    return 0 unless $parent;
    my @c = _node_children($parent);
    @c && refaddr($node) == refaddr($c[0]);
}

sub _node_is_last_child {
    my $node = shift;
    my $parent = $node->parent;
    return 0 unless $parent;
    my @c = _node_children($parent);
    @c && refaddr($node) == refaddr($c[-1]);
}

sub _node_is_only_child {
    my $node = shift;
    my $parent = $node->parent;
    return 0 unless $parent;
    my @c = _node_children($parent);
    @c==1;# && refaddr($node) == refaddr($c[0]);
}

sub _node_is_nth_child {
    my ($node, $n) = @_;
    my $parent = $node->parent;
    return 0 unless $parent;
    my @c = _node_children($parent);
    @c >= $n && refaddr($node) == refaddr($c[$n-1]);
}

sub _node_is_nth_last_child {
    my ($node, $n) = @_;
    my $parent = $node->parent;
    return 0 unless $parent;
    my @c = _node_children($parent);
    @c >= $n && refaddr($node) == refaddr($c[-$n]);
}

sub _node_is_first_of_type {
    my $node = shift;
    my $parent = $node->parent;
    return 0 unless $parent;
    my $type = ref($node);
    my @c = grep { $_->isa($type) } _node_children($parent);
    @c && refaddr($node) == refaddr($c[0]);
}

sub _node_is_last_of_type {
    my $node = shift;
    my $parent = $node->parent;
    return 0 unless $parent;
    my $type = ref($node);
    my @c = grep { $_->isa($type) } _node_children($parent);
    @c && refaddr($node) == refaddr($c[-1]);
}

sub _node_is_only_of_type {
    my $node = shift;
    my $parent = $node->parent;
    return 0 unless $parent;
    my $type = ref($node);
    my @c = grep { $_->isa($type) } _node_children($parent);
    @c == 1; # && refaddr($node) == refaddr($c[0]);
}

sub _node_is_nth_of_type {
    my ($node, $n) = @_;
    my $parent = $node->parent;
    return 0 unless $parent;
    my $type = ref($node);
    my @c = grep { $_->isa($type) } _node_children($parent);
    @c >= $n && refaddr($node) == refaddr($c[$n-1]);
}

sub _node_is_nth_last_of_type {
    my ($node, $n) = @_;
    my $parent = $node->parent;
    return 0 unless $parent;
    my $type = ref($node);
    my @c = grep { $_->isa($type) } _node_children($parent);
    @c >= $n && refaddr($node) == refaddr($c[-$n]);
}

sub _node_little_siblings {
    my $node = shift;
    my $parent = $node->parent or return ();
    my $refaddr = refaddr($node);
    my @children = _node_children($parent);
    for my $i (0..$#children-1) {
        if (refaddr($children[$i]) == $refaddr) {
            return @children[$i+1 .. $#children];
        }
    }
    ();
}

sub _node_adjacent_little_sibling {
    my $node = shift;
    my $parent = $node->parent or return undef;
    my $refaddr = refaddr($node);
    my @children = _node_children($parent);
    for my $i (0..$#children-1) {
        if (refaddr($children[$i]) == $refaddr) {
            return $children[$i+1];
        }
    }
    undef;
}

sub _uniq_objects {
    my @uniq;
    my %mem;
    for (@_) {
        push @uniq, $_ unless $mem{refaddr($_)}++;
    }
    @uniq;
}

sub _simpsel {
    no warnings 'numeric', 'uninitialized';

    my ($opts, $simpsel, $is_recursive, @nodes) = @_;

    #use Data::Dmp; say "D: _simpsel(expr", dmp($simpsel), ", recursive=$is_recursive, nodes=[".join(",",map {$_->{id}} @nodes)."])";

    my @res;
    if ($is_recursive) {
        @res = (@nodes, map {_node_descendants($_)} @nodes);
    } else {
        @res = @nodes;
    }
    #say "D:   intermediate result (after walk): [".join(",",map {$_->{id}} @res)."]";

    unless ($simpsel->{type} eq '*') {
        @res = grep { $_->isa($simpsel->{type}) } @res;
    }

    @res = _uniq_objects(@res);
    #say "D:   intermediate result (after type): [".join(",",map {$_->{id}} @res)."]";

    for my $f (@{ $simpsel->{filters} // [] }) {
        last unless @res;

        if (defined (my $attr = $f->{attr})) {
            my $op  = $f->{op};
            my $opv = $f->{value};

            my @newres;
          ITEM:
            for my $o (@res) {
                next ITEM unless $o->can($f->{attr}) ||
                    $o->can('AUTOLOAD');

                my $val = $o->$attr;
                if ($op eq '=' || $op eq '==') {
                    if (looks_like_number($opv)) {
                        next ITEM unless $val == $opv;
                    } else {
                        next ITEM unless $val eq $opv;
                    }
                } elsif ($op eq 'eq') {
                    next ITEM unless $val eq $opv;
                } elsif ($op eq '!=') {
                    if (looks_like_number($opv)) {
                        next ITEM unless $val != $opv;
                    } else {
                        next ITEM unless $val ne $opv;
                    }
                } elsif ($op eq 'ne') {
                    next ITEM unless $val ne $opv;
                } elsif ($op eq '>') {
                    if (looks_like_number($opv)) {
                        next ITEM unless $val >  $opv;
                    } else {
                        next ITEM unless $val gt $opv;
                    }
                } elsif ($op eq 'gt') {
                    next ITEM unless $val gt $opv;
                } elsif ($op eq '>=') {
                    if (looks_like_number($opv)) {
                        next ITEM unless $val >=  $opv;
                    } else {
                        next ITEM unless $val gt $opv;
                    }
                } elsif ($op eq 'ge') {
                    next ITEM unless $val ge $opv;
                } elsif ($op eq '<') {
                    if (looks_like_number($opv)) {
                        next ITEM unless $val <  $opv;
                    } else {
                        next ITEM unless $val lt $opv;
                    }
                } elsif ($op eq 'lt') {
                    next ITEM unless $val lt $opv;
                } elsif ($op eq '<=') {
                    if (looks_like_number($opv)) {
                        next ITEM unless $val <= $opv;
                    } else {
                        next ITEM unless $val le $opv;
                    }
                } elsif ($op eq 'le') {
                    next ITEM unless $val le $opv;
                } elsif ($op eq 'is') {
                    if (!defined($opv)) {
                        next ITEM unless !defined($val);
                    } elsif ($opv) {
                        next ITEM unless $val;
                    } else {
                        next ITEM unless !$val;
                    }
                } elsif ($op eq 'isnt') {
                    if (!defined($opv)) {
                        next ITEM unless defined($val);
                    } elsif ($opv) {
                        next ITEM unless !$val;
                    } else {
                        next ITEM unless $val;
                    }
                } elsif ($op eq '=~') {
                    next ITEM unless $val =~ $opv;
                } elsif ($op eq '!~') {
                    next ITEM unless $val !~ $opv;
                } else {
                    die "BUG: Unsupported operator '$op' in attr_selector";
                }

                # pass all attribute filters, add to new result
                #say "D:    adding to result: ".$o->{id};
                push @newres, $o;
            } # for each item
            @res = @newres;
        } # attr filter

        if (defined(my $pc = $f->{pseudoclass})) {
            if ($pc eq 'first') {
                @res = ($res[0]);
            } elsif ($pc eq 'last') {
                @res = ($res[-1]);
            } elsif ($pc eq 'first-child') {
                @res = grep { _node_is_first_child($_) } @res;
            } elsif ($pc eq 'last-child') {
                @res = grep { _node_is_last_child($_) } @res;
            } elsif ($pc eq 'only-child') {
                @res = grep { _node_is_only_child($_) } @res;
            } elsif ($pc eq 'nth-child') {
                @res = grep { _node_is_nth_child($_, $f->{args}[0]) } @res;
            } elsif ($pc eq 'nth-last-child') {
                @res = grep { _node_is_nth_last_child($_, $f->{args}[0]) } @res;
            } elsif ($pc eq 'first-of-type') {
                @res = grep { _node_is_first_of_type($_) } @res;
            } elsif ($pc eq 'last-of-type') {
                @res = grep { _node_is_last_of_type($_) } @res;
            } elsif ($pc eq 'only-of-type') {
                @res = grep { _node_is_only_of_type($_) } @res;
            } elsif ($pc eq 'nth-of-type') {
                @res = grep { _node_is_nth_of_type($_, $f->{args}[0]) } @res;
            } elsif ($pc eq 'nth-last-of-type') {
                @res = grep { _node_is_nth_last_of_type($_, $f->{args}[0]) } @res;
            } elsif ($pc eq 'has') {
                @res = grep { csel($opts, $f->{args}[0], $_) }
                    _uniq_objects(
                        grep {defined} map { $_->parent } @res);
            } elsif ($pc eq 'not') {
                #say "D: res=(".join(",", map {$_->{id}} @res).")";
                my @all_matches = map { csel($opts, $f->{args}[0], $_) } @res;
                #say "D: all_matches=(".join(",", map {$_->{id}} @all_matches).")";
                my %all_matches_refaddrs;
                for (@all_matches) { $all_matches_refaddrs{refaddr($_)}++ }
                @res = grep { !$all_matches_refaddrs{refaddr($_)} } @res;
            } else {
                die "Unsupported pseudo-class '$pc'";
            }
        } # pseudoclass filter

        #say "D:   intermediate result (after filter): [".join(",",map {$_->{id}} @res)."]";
    } # for each filter
    @res;
}

sub _sel {
    my ($opts, $sel, @nodes) = @_;

    my @simpsels = @$sel;
    my @res;

    my $i = 0;
    while (@simpsels) {
        if ($i++ == 0) {
            my $simpsel = shift @simpsels;
            @res = _simpsel($opts, $simpsel, 1, @nodes);
        } else {
            my $combinator = shift @simpsels;
            my $simpsel = shift @simpsels;
            last unless @res;
            if ($combinator->{combinator} eq ' ') { # descendant
                @res = _simpsel($opts, $simpsel, 1,
                                map { _node_children($_) } @res);
            } elsif ($combinator->{combinator} eq '>') { # child
                @res = _simpsel($opts, $simpsel, 0,
                                map { _node_children($_) } @res);
            } elsif ($combinator->{combinator} eq '~') { # sibling
                @res = _simpsel($opts, $simpsel, 0,
                                map { _node_little_siblings($_) } @res);
            } elsif ($combinator->{combinator} eq '+') { # adjacent sibling
                @res = _simpsel($opts, $simpsel, 0,
                                grep {defined}
                                    map { _node_adjacent_little_sibling($_) }
                                    @res);
            } else {
                die "BUG: Unknown combinator '$combinator->{combinator}'";
            }
        }
    }

    @res;
}

sub csel {
    my $opts;
    if (ref($_[0]) eq 'HASH') {
        $opts = shift;
    } else {
        $opts = {};
    }
    my $expr = shift;
    my @nodes = @_;

    my $pexpr = parse_csel($expr);

    my @res = _uniq_objects(map { _sel($opts, $_, @nodes) } @$pexpr );

    if ($opts->{wrap}) {
        require Data::CSel::Selection;
        return Data::CSel::Selection->new(\@res);
    } else {
        return @res;
    }
}

1;
# ABSTRACT: Select tree node objects using CSS Selector-like syntax

=head1 SYNOPSIS

 use Data::CSel qw(csel);

 my @cells = csel("Table[name=~/data/i] TCell[value isnt '']:first", $tree);

 # ditto, but wrap result using a Data::CSel::Selection
 my $res = csel({wrap=>1}, "Table ...", $tree);

 # call method 'foo' of each node object (works even when there are zero nodes
 # in the selection object, or when some nodes do not support the 'foo' method
 $res->foo;


=head1 DESCRIPTION

This module lets you use a query language (hereby named CSel) that is similar to
CSS Selector to select nodes from a tree of objects.


=head1 EXPRESSION SYNTAX

The following is description of the CSel query expression. It is modeled after
the CSS Selector syntax with some modification (see L</"Differences with CSS
selector">).

An I<expression> is a chain of one or more selectors separated by commas.

A I<selector> is a chain of one or more simple selectors separated by
combinators.

A I<combinator> is either: whitespace (descendant combinator), C<< > >> (child
combinator), C<~> (general sibling combinator), or C<+> (adjacent sibling
combinator). C<E F>, or two elements combined using descendant combinator, means
F element descendant of an E element. C<< E > F >> means F element child of E
element. C<E ~ F> means F element preceded by an E element. C<E + F> means F
element immediately preceded by an E element.

A I<simple selector> is either a type selector or universal selector followed
immediately by zero or more attribute selectors or pseudo-classes, in any order.
Type or universal selector is optional if there are at least one attribute
selector or pseudo-class.

=head2 Type selector

A I<type selector> is a Perl class/package name.

Example:

 My::Class

will match any C<My::Class> object.

=head2 Universal selector

A I<universal selector> is C<*> and matches any class/package.

Example:

 *

will match any object.

=head2 Attribute selector

An I<attribute selector> filters objects based on the value of their attributes.
The syntax is:

 [ATTR]
 [ATTR OP LITERAL]

C<[ATTR]> means to only select objects that have an attribute named C<ATTR>, for
example:

 Any[length]

means to select object of type (C<isa()>) C<Any> that responds to (C<can()>)
C<length()>.

Note: to select objects that do not have a specified attribute, you can use the
C<:not> pseudo-class (see L</"Pseudo-class">), for example:

 Any:not([length])

C<[ATTR]> means to only select objects that have an attribute named C<ATTR> that
has value that matches the expression specified by operator C<OP> and operand
C<LITERAL>.

=head3 Literal

Literals can either be a number, e.g.:

 1
 -2.3
 4.5e-6

or boolean literals:

 true
 false

or null (undef) literal:

 null

or a single-quoted string (only recognizes the escape sequences C<\\> and
C<\'>):

 'this is a string'
 'this isn\'t hard'

or a double-quoted string (currently recognizes the escape sequences C<\\>,
C<\">, C<\'>, C<\$> [literal $], C<\t> [tab character], C<\n> [newline], C<\r>
[linefeed], C<\f> [formfeed], C<\b> [backspace], C<\a> [bell], C<\e> [escape],
C<\0> [null], octal escape e.g. C<\033>, hexadecimal escape e.g. C<\x1b>):

 "This is a string"
 "This isn't hard"
 "Line 1\nLine 2"

or a regex string (must be delimited by C</> ... C</>, can be followed by zero
of more regex modifier characters m, s, i):

 //
 /ab(c|d)/i

=head3 Operators

The following are supported operators:

=over

=item * C<eq>

String equality using Perl's C<eq> operator.

Example:

 Table[title eq "TOC"]

selects all C<Table> objects that have C<title()> with the value of C<"TOC">.

=item * C<=> (or C<==>)

Numerical equality using Perl's C<==> operator.

Example:

 TableCell[length=3]

selects all C<TableCell> objects that have C<length()> with the value of 3.

To avoid common trap, will switch to using Perl's C<eq> operator when operand
does not look like number, e.g.:

 Table[title = 'foo']

is the same as:

 Table[title eq 'foo']

=item * C<ne>

String inequality using Perl's C<ne> operator.

Example:

 Table[title ne "TOC"]

selects all C<Table> objects that have C<title()> with the value not equal to
C<"TOC">.

=item * C<!=>

Numerical inequality using Perl's C<!=> operator.

Example:

 TableCell[length != 3]

selects all C<TableCell> objects that have C<length()> with the value not equal
to 3.

To avoid common trap, will switch to using Perl's C<ne> operator when operand
does not look like number, e.g.:

 Table[title != 'foo']

is the same as:

 Table[title ne 'foo']

=item * C<gt>

String greater-than using Perl's C<gt> operator.

Example:

 Person[first_name gt "Albert"]

selects all C<Person> objects that have C<first_name()> with the value
asciibetically greater than C<"Albert">.

=item * C<< > >>

Numerical greater-than using Perl's C<< > >> operator.

Example:

 TableCell[length > 3]

selects all C<TableCell> objects that have C<length()> with the value greater
than 3.

To avoid common trap, will switch to using Perl's C<gt> operator when operand
does not look like number, e.g.:

 Person[first_name > 'Albert']

is the same as:

 Person[first_name gt "Albert"]

=item * C<ge>

String greater-than-or-equal-to using Perl's C<< ge >> operator.

Example:

 Person[first_name ge "Albert"]

selects all C<Person> objects that have C<first_name()> with the value
asciibetically greater than or equal to C<"Albert">.

=item * C<< >= >>

Numerical greater-than-or-equal-to using Perl's C<< >= >> operator.

Example:

 TableCell[length >= 3]

selects all C<TableCell> objects that have C<length()> with the value greater
than or equal to 3.

To avoid common trap, will switch to using Perl's C<ge> operator when operand
does not look like number, e.g.:

 Person[first_name >= 'Albert']

is the same as:

 Person[first_name ge "Albert"]

=item * C<lt>

String less-than using Perl's C<< lt >> operator.

Example:

 Person[first_name lt "Albert"]

selects all C<Person> objects that have C<first_name()> with the value
asciibetically less than C<"Albert">.

=item * C<< < >>

Numerical less-than using Perl's C<< < >> operator.

Example:

 TableCell[length < 3]

selects all C<TableCell> objects that have C<length()> with the value less
than 3.

To avoid common trap, will switch to using Perl's C<lt> operator when operand
does not look like number, e.g.:

 Person[first_name < 'Albert']

is the same as:

 Person[first_name lt "Albert"]

=item * C<le>

String less-than-or-equal-to using Perl's C<< le >> operator.

Example:

 Person[first_name le "Albert"]

selects all C<Person> objects that have C<first_name()> with the value
asciibetically less than or equal to C<"Albert">.

=item * C<< <= >>

Numerical less-than-or-equal-to using Perl's C<< <= >> operator.

Example:

 TableCell[length <= 3]

selects all C<TableCell> objects that have C<length()> with the value less
than or equal to 3.

To avoid common trap, will switch to using Perl's C<le> operator when operand
does not look like number, e.g.:

 Person[first_name <= 'Albert']

is the same as:

 Person[first_name le "Albert"]

=item * C<=~> and C<!~>

Filter only objects where the attribute named I<attr> has the value matching
regular expression I<value>. Operand should be a regex literal. Regex literal
must be delimited by C<//>.

Example:

 Person[first_name =~ /^Al/]

selects all C<Person> objects that have C<first_name()> with the value
matching the regex C</^Al/>.

 Person[first_name =~ /^al/i]

Same as previous example except the regex is case-insensitive.

C<!~> is the opposite of C<=~>, just like in Perl. It checks whether I<attr> has
value that does not match regular expression.

=item * C<is> and C<isnt>

Testing truth value or definedness. Value can be null or boolean literal.

Example:

 DateTime[is_leap_year is true]

will select all DateTime objects where its C<is_leap_year> attribute has a true
value.

 DateTime[is_leap_year is false]

will select all DateTime objects where its C<is_leap_year> attribute has a false
value.

 Person[age isnt null]

will select all Person objects where age is defined.

=back

=head2 Pseudo-class

A I<pseudo-class> filters objects based on some criteria, in the form of:

 :NAME
 :NAME(ARG, ...)

Supported pseudo-classes include:

=over

=item * C<:first>

Select only the first object from the result set.

Example:

 Person[name =~ /^a/i]:first

selects the first person whose name starts with the letter C<A>.

=item * C<:last>

Select only the last item from the result set.

Example:

 Person[name =~ /^a/i]:last

selects the last person whose name starts with the letter C<A>.

=item * C<:first-child>

Select only object that is the first child of its parent.

=item * C<:last-child>

Select only object that is the last child of its parent.

=item * C<:only-child>

Select only object that is the only child of its parent.

=item * C<:nth-child(n)>

Select only object that is the I<n>th child of its parent.

=item * C<:nth-last-child(n)>

Select only object that is the I<n>th last child of its parent.

=item * C<:first-of-type>

=item * C<:last-of-type>

=item * C<:only-of-type>

=item * C<:nth-of-type(n)>

=item * C<:nth-last-of-type(n)>

=item * C<:not(s)>

=item * C<:has(s)>

=back


=head2 Differences with CSS selector

=head3 Type selector can contain double colon (C<::>)

Since Perl package names are separated by C<::>, CSel allows it in type
selector.

=head3 No equivalent for CSS class and ID selectors

I.e.:

 E.class
 E#id

They are not used in CSel.

=head3 Syntax of attribute selector is a bit different

In CSel, the syntax of attribute selector is made simpler and more regular.

There are operators not supported by CSel, but CSel adds more operators from
Perl. In particular, the whole substring matching operations like
C<[attr^=val]>, C<[attr$=val]>, C<[attr*=val]>, C<[attr~=val]>, and
C<[attr|=val]> are replaced with the more flexible regex matching instead
C<[attr =~ /re/]>.

String must always be quoted, e.g.:

 p[align="middle"]
 p[align='middle']

instead of just:

 p[align=middle]

=head3 Different pseudo-classes supported

Some CSS pseudo-classes only make sense for a DOM or a visual browser, e.g.
C<:link>, C<:visited>, C<:hover>, so they are not supported.

C<:has(p)> and C<:not(p)> needs quoted value. In CSel, C<p> is a regular string
literal and must be quoted.

=head3 There is no concept of CSS namespaces

But Perl package names are already hierarchical.


=head1 FUNCTIONS

=head2 csel([ \%opts , ] $expr, @tree_nodes) => list|selection_object

Select from tree node objects C<@tree_nodes> using CSel expression C<$expr>.
Will return a list of mattching node objects (unless when C<wrap> option is
true, in which case will return a L<Data::CSel::Selection> object instead). Will
die on errors (e.g. syntax error in expression, objects not having the required
methods, etc).

A tree node object is any regular Perl object satisfying the following criteria:
1) it supports a C<parent> method which should return a single parent node
object, or undef if object is the root node); 2) it supports a C<children>
method which should return a list (or an arrayref) of children node objects
(where the list/array will be empty for a leaf node).

Known options:

=over

=item * wrap => bool

If set to true, instead of returning a list of matching nodes, the function will
return a L<Data::CSel::Selection> object instead (which wraps the result, for
convenience). See the selection object's documentation for more details.

=back

=head2 parse_csel($expr) => hash|undef

Parse an expression. On success, will return a hash containing parsed
information. On failure, will return undef.


=head1 SEE ALSO

CSS4 Selectors Specification, L<https://www.w3.org/TR/selectors4/>.

These modules let you use XPath (or XPath-like) syntax to select nodes of a data
structure: L<Data::DPath>. Like CSS selectors, XPath is another query language
to select nodes of a document. XPath specification:
L<https://www.w3.org/TR/xpath/>.

These modules let you use JSONPath syntax to select nodes of a data structure:
L<JSON::Path>. JSONPath is a query language to select nodes of a JSON document
(data structure). JSONPath specification:
L<http://goessner.net/articles/JsonPath>.

These modules let you use CSS selector syntax (or its subset) to select nodes of
an HTML document: L<Mojo::DOM> (or L<DOM::Tiny>), L<jQuery>, L<pQuery>,
L<HTML::Selector::XPath> (or via L<Web::Query>). The last two modules can also
handle XPath expression.
