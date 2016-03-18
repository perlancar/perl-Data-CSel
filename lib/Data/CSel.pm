package Data::CSel;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(
                       csel
                       parse_csel
               );

our $RE =
    qr{
          #(?&SELECTORS) (?{ $_ = $^R->[1] })
          (?&SELECTOR) (?{ $_ = $^R->[1] })

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
                          (?{ [$^R, {type=>$^N, filters=>[]}] })
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
                          (?{ [$^R, {type=>$^N // '*', filters=>[]}] })
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
                  ([A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z0-9_]+)*|\*)
              )

              (?<FILTER>
                  (?{ [$^R, {}] })
                  (
                      (?&ATTR_SELECTOR) # [[$^R, {}], [$attr, $op, $val]]
                      (?{
                          $^R->[0][1]{type}  = 'attr_selector';
                          $^R->[0][1]{attr}  = $^R->[1][0];
                          $^R->[0][1]{op}    = $^R->[1][1];
                          $^R->[0][1]{value} = $^R->[1][2];
                          $^R->[0];
                      })
                  |
                      (?&PSEUDOCLASS) # [[$^R, {}], [$pseudoclass]]
                      (?{
                          $^R->[0][1]{type}         = 'pseudoclass';
                          $^R->[0][1]{pseudoclass}  = $^R->[1][0];
                          $^R->[0];
                      })
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
                      \s+(?:isnt|is|isnta|isa)\s+
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
    eval { m{\A$RE\z}; } and return $_;
    die $@ if $@;
    return undef;
}

sub csel {
    my ($expr, $tree, $opts) = @_;
    $opts //= {};

    my $pexpr =  parse_csel($expr);

    my $code_sel = sub {
        my ($res, $tree) = @_;
    };

    my @res;
    for my $sel (@{$pexpr}) {
        # XXX
    }

    if ($opts->wrap) {
        require Data::CSel::Selection;
        return Data::CSel::Selection->new(@res);
    } else {
        return @res;
    }
}

1;
# ABSTRACT: Select nodes of tree object using CSS Selector-like syntax

=head1 SYNOPSIS

 use Data::CSel qw(csel);

 my @cells = csel("Table[name=~/data/i] TCell[value isnt empty]:first", $tree);

 # ditto, but wrap result using a Data::CSel::Selection
 my $res = csel("...", $data, {wrap=>1});

 # call method 'foo' of each node object (works even when there are zero nodes
 # in the selection object, or when some nodes do not support the 'foo' method
 $res->foo;


=head1 DESCRIPTION

This module lets you use a query language (hereby named CSel) that is similar to
CSS Selector to select nodes of tree object.


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

=item * C<=> (or C<==>)

Numerical equality using Perl's C<==> operator.

Example:

 TableCell[length=3]

selects all C<TableCell> objects that have C<length()> with the value of 3.

=item * C<eq>

String equality using Perl's C<eq> operator.

Example:

 Table[title eq "TOC"]

selects all C<Table> objects that have C<title()> with the value of C<"TOC">.

=item * C<!=>

Numerical inequality using Perl's C<!=> operator.

Example:

 TableCell[length != 3]

selects all C<TableCell> objects that have C<length()> with the value not equal
to 3.

=item * C<ne>

String inequality using Perl's C<ne> operator.

Example:

 Table[title ne "TOC"]

selects all C<Table> objects that have C<title()> with the value not equal to
C<"TOC">.

=item * C<< > >>

Numerical greater-than using Perl's C<< > >> operator.

Example:

 TableCell[length > 3]

selects all C<TableCell> objects that have C<length()> with the value greater
than 3.

=item * C<gt>

String greater-than using Perl's C<gt> operator.

Example:

 Person[first_name gt "Albert"]

selects all C<Person> objects that have C<first_name()> with the value
asciibetically greater than C<"Albert">.

=item * C<< >= >>

Numerical greater-than-or-equal-to using Perl's C<< >= >> operator.

Example:

 TableCell[length >= 3]

selects all C<TableCell> objects that have C<length()> with the value greater
than or equal to 3.

=item * C<ge>

String greater-than-or-equal-to using Perl's C<< ge >> operator.

Example:

 Person[first_name ge "Albert"]

selects all C<Person> objects that have C<first_name()> with the value
asciibetically greater than or equal to C<"Albert">.

=item * C<< < >>

Numerical less-than using Perl's C<< < >> operator.

Example:

 TableCell[length < 3]

selects all C<TableCell> objects that have C<length()> with the value less
than 3.

=item * C<lt>

String less-than using Perl's C<< lt >> operator.

Example:

 Person[first_name lt "Albert"]

selects all C<Person> objects that have C<first_name()> with the value
asciibetically less than C<"Albert">.

=item * C<< <= >>

Numerical less-than-or-equal-to using Perl's C<< <= >> operator.

Example:

 TableCell[length <= 3]

selects all C<TableCell> objects that have C<length()> with the value less
than or equal to 3.

=item * C<le>

String less-than-or-equal-to using Perl's C<< le >> operator.

Example:

 Person[first_name le "Albert"]

selects all C<Person> objects that have C<first_name()> with the value
asciibetically less than or equal to C<"Albert">.

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

=item * C<isa> and C<isnta>

Checking C<isa()> relationship.

Example:

 [date isa "DateTime"]

will select all objects that have a C<date> attribute having a value that is a
L<DateTime> object.

 [date isnta "DateTime"]

This is the opposite of C<isa>, will select all objects that have a C<date>
attribute having a value that is not a DateTime object.

=back

=head2 Pseudo-class

A I<pseudo-class> filters objects based on some criteria, and is either:

=over

=item * C<:first-child>

Select only object that is the first child of its parent.

=item * C<:nth-child(n)>

=item * C<:nth-last-child(n)>

=item * C<:last-child>

=item * C<:only-child>

=item * C<:first-of-type>

=item * C<:nth-of-type(n)>

=item * C<:nth-last-of-type(n)>

=item * C<:last-of-type>

=item * C<:first>

Select only the first object.

=item * C<:last>

Select only the last object.

=item * C<:empty>

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

=head3 Different pseudo-classes supported

Some CSS pseudo-classes only make sense for a DOM or a visual browser, e.g.
C<:link>, C<:visited>, C<:hover>, so they are not supported.

=head3 :has(p) and :not(p) needs quoted value

In CSel, C<p> is a regular string literal and must be quoted.

=head3 There is no concept of CSS namespaces

But Perl package names are already hierarchical.


=head1 FUNCTIONS

=head2 csel($expr, $tree [ , \%opts ]) => list|selection

Select nodes from a tree object C<$tree> using CSel expression C<$expr>. See
L<Data::CSel> for the CSel syntax. Will return a list of mattching node objects
(unless when C<wrap> option is true, in which case will return a
L<Data::CSel::Selection> object instead). Will die on errors (e.g. syntax error
in expression, object not having the requied method, etc).

A tree object is a node object, while node object is any regular Perl object
satisfying the following criteria: 1) it supports a C<parent> method which
should return a single parent node object, or undef if object is the root node);
2) it supports a C<children> method which should return a list (or an arrayref)
of node objects or an empty list if object is a leaf node.

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
