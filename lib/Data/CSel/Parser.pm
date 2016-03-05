package Data::CSel::Parser;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(parse_csel_expr);

use DD;

my ($m_attr, $m_op, $m_val);

our $re =
    qr{
          (?&SELECTORS) (?{ $_ = $^R })
          (?(DEFINE)
              (?<LITERAL_NUMBER>
                  (
                      -?
                      (?: 0 | [1-9]\d* )
                      (?: \. \d+ )?
                      (?: [eE] [-+]? \d+ )?
                  )
                  (?{ $m_val = 0+$^N; $^R })
              )

              (?<LITERAL>
                  (?&LITERAL_NUMBER)
              )

              (?<ATTR_NAME>
                  [A-Za-z_][A-Za-z0-9_]*
              )

              (?<ATTR_SELECTOR>
                  \[((?&ATTR_NAME))\]
                  (?{
                      my $simpsel = $^R->{selectors}[-1][-1];
                      push @{ $simpsel->{filters} }, {type=>'attr_selector', attr=>$^N};
                      $^R;
                  })
              |
                  \[!((?&ATTR_NAME))\]
                  (?{
                      my $simpsel = $^R->{selectors}[-1][-1];
                      push @{ $simpsel->{filters} }, {type=>'attr_selector', attr=>$^N, not=>1};
                      $^R;
                  })
              |
                  \[((?&ATTR_NAME)) (?{ $m_attr = $^N; $^R })
                  (
                      \s*(?:==?|!=|>=?|<=?)\s* |
                      \s+(?:eq|ne|lt|gt|le|ge)\s+
                  )
                  (?{ $m_op = $^N; $m_op =~ s/\s+//g; $^R })
                  ((?&LITERAL))
                  \]
                  (?{
                      my $simpsel = $^R->{selectors}[-1][-1];
                      push @{ $simpsel->{filters} }, {type=>'attr_selector', attr=>$m_attr, op=>$m_op, value=>$m_val };
                      $^R;
                  })
              )

              (?<PSEUDOCLASS_NAME>
                  [A-Za-z_][A-Za-z0-9_]*(?:-[A-Za-z0-9_]+)*
              )

              (?<PSEUDOCLASS>
                  :((?&PSEUDOCLASS_NAME))
                  (?{
                      my $simpsel = $^R->{selectors}[-1][-1];
                      push @{ $simpsel->{filters} }, {type=>'pseudoclass', pseudoclass=>$^N};
                      $^R;
                  })
              )

              (?<FILTER>
                  (?&ATTR_SELECTOR)|(?&PSEUDOCLASS)
              )

              (?<FILTERS>
                  (?:
                      (?&FILTER) (?: \s* (?&FILTER) )*
                  )?
              )

              (?<SIMPLE_SELECTOR>
                 ([A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z0-9_]+)*|\*)
                 (?{
                     my $sel = $^R->{selectors}[-1];
                     push @{$sel}, {};
                     $sel->[-1]{type} = $^N;
                     $^R;
                 })
                 (?&FILTERS)
              )

              (?<SELECTOR>
                  (?{
                      push @{ $^R->{selectors} }, [];
                      $^R;
                  })
                  (?&SIMPLE_SELECTOR)
                  (?:
                      (\s*>\s*|\s*\+\s*|\s+)
                      (?{
                          my $sel = $^R->{selectors}[-1];
                          my $comb = $^N; $comb =~ s/\s+//g;
                          push @$sel, {combinator=>$comb};
                          $^R;
                      })

                      (?&SIMPLE_SELECTOR)
                  )?
              )

              (?<SELECTORS>
                  \s*
                  (?{ {selectors=>[] } })
                  (?&SELECTOR)
                  (?:
                      \s*,\s*
                      (?&SELECTOR)
                  )?
                  \s*
              )
          ) # DEFINE
  }x;

sub parse_csel_expr {
    local $_ = shift;
    local $^R;
    eval { m{\A$re\z}; } and return $_;
    die $@ if $@;
    return undef;
}

1;
# ABSTRACT: Parse CSel query language

=head1 SYNOPSIS

 use Data::CSel::Parser qw(parse_csel_expr);

 my $res = parse_csel_expr("Table[num_rows > 0] > TableRow > TableCell");


=head1 DESCRIPTION

The following is a description of the CSel query expression.

An I<expression> is chain of one or more selectors separated by commas.

A I<selector> is a chain of one or more simple selectors separated by
combinators. I<Combinators> are: white space, C<< > >>, and C<+>.

A I<simple selector> is either a type selector or universal selector followed
immediately by zero or more attribute selectors or pseudo-classes, in any order.

=head1 Type selector

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

An I<attribute selector> filters objects based on their attributes, and is
either:

=over

=item * C<[>I<attr>C<]>

Filter only objects that C<can()> I<attr>.

Example:

 *[quack]

selects any object that can C<quack()>.

=item * C<[!>I<attr>C<]>

Filter only objects that cannot I<attr>.

Example:

 *[!quack]

selects any object that cannot C<quack()>.

=item * C<[>I<attr> C<=> I<value>C<]> or C<[>I<attr> C<==> I<value>C<]>

Filter only objects where the attribute named I<attr> has the value equal to
I<value> (compared numerically using Perl's C<==> operator).

Example:

 TableCell[length=3]

selects all C<TableCell> objects that have C<length()> with the value of 3.

=item * C<[>I<attr> C<eq> I<value>C<]>

Filter only objects where the attribute named I<attr> has the value equal to
I<value> (compared stringily using Perl's C<eq> operator).

Example:

 Table[title="TOC"]

selects all C<Table> objects that have C<title()> with the value of C<"TOC">.

=item * C<[>I<attr> C<!=> I<value>C<]>

Filter only objects where the attribute named I<attr> has the value not equal to
I<value> (compared numerically using Perl's C<!=> operator).

Example:

 TableCell[length != 3]

selects all C<TableCell> objects that have C<length()> with the value not equal
to 3.

=item * C<[>I<attr> C<ne> I<value>C<]>

Filter only objects where the attribute named I<attr> has the value not equal to
I<value> (compared stringily using Perl's C<ne> operator).

Example:

 Table[title ne "TOC"]

selects all C<Table> objects that have C<title()> with the value of C<"TOC">.

=item * C<[>I<attr> C<< > >> I<value>C<]>

Filter only objects where the attribute named I<attr> has the value greater than
I<value> (compared numerically using Perl's C<< > >> operator).

Example:

 TableCell[length > 3]

selects all C<TableCell> objects that have C<length()> with the value greater
than 3.

=item * C<[>I<attr> C<gt> I<value>C<]>

Filter only objects where the attribute named I<attr> has the value greater than
I<value> (compared stringily using Perl's C<< gt >> operator).

Example:

 Person[first_name gt "Albert"]

selects all C<Person> objects that have C<first_name()> with the value
asciibetically greater than C<"Albert">.

=item * C<[>I<attr> C<< >= >> I<value>C<]>

Filter only objects where the attribute named I<attr> has the value greater than
or equal to I<value> (compared numerically using Perl's C<< >= >> operator).

Example:

 TableCell[length >= 3]

selects all C<TableCell> objects that have C<length()> with the value greater
than or equal to 3.

=item * C<[>I<attr> C<ge> I<value>C<]>

Filter only objects where the attribute named I<attr> has the value greater than
or equal to I<value> (compared stringily using Perl's C<< ge >> operator).

Example:

 Person[first_name ge "Albert"]

selects all C<Person> objects that have C<first_name()> with the value
asciibetically greater than or equal to C<"Albert">.

=item * C<[>I<attr> C<< < >> I<value>C<]>

Filter only objects where the attribute named I<attr> has the value less than
I<value> (compared numerically using Perl's C<< < >> operator).

Example:

 TableCell[length < 3]

selects all C<TableCell> objects that have C<length()> with the value less
than 3.

=item * C<[>I<attr> C<lt> I<value>C<]>

Filter only objects where the attribute named I<attr> has the value less than
I<value> (compared stringily using Perl's C<< lt >> operator).

Example:

 Person[first_name lt "Albert"]

selects all C<Person> objects that have C<first_name()> with the value
asciibetically less than C<"Albert">.

=item * C<[>I<attr> C<< <= >> I<value>C<]>

Filter only objects where the attribute named I<attr> has the value less than
or equal to I<value> (compared numerically using Perl's C<< <= >> operator).

Example:

 TableCell[length <= 3]

selects all C<TableCell> objects that have C<length()> with the value less
than or equal to 3.

=item * C<[>I<attr> C<le> I<value>C<]>

Filter only objects where the attribute named I<attr> has the value less than or
equal to I<value> (compared stringily using Perl's C<< le >> operator).

Example:

 Person[first_name le "Albert"]

selects all C<Person> objects that have C<first_name()> with the value
asciibetically less than or equal to C<"Albert">.

=item * C<[>I<attr> C<=~> I<value>C<]>

Filter only objects where the attribute named I<attr> has the value matching
regular expression I<value>. Regular expression must be delimited by C<//>.

Example:

 Person[first_name =~ /^Al/]

selects all C<Person> objects that have C<first_name()> with the value
matching the regex C</^Al/>.

 Person[first_name =~ /^al/i]

Same as previous example except the regex is case-insensitive.

=item * C<[>I<attr> C<is> C<true><C<]> or C<[>I<attr> C<is> C<false><C<]>

Filter only objects where the attribute named I<attr> has a true (or false)
value. What's true or false follows Perl's semantic.

Example:

 DateTime[is_leap_year is true]

will select all DateTime objects where its C<is_leap_year> attribute has a true
value.

 DateTime[is_leap_year is false]

will select all DateTime objects where its C<is_leap_year> attribute has a false
value.

=item * C<[>I<attr> C<is> I<type><C<]>

Filter only objects where the attribute named I<attr> has a value that is an
object of type I<type>.

Example:

 *[date is DateTime]

will select all objects that have a C<date> attribute having a value that is a
L<DateTime> object.

=item * C<[>I<attr> C<isnt> C<true><C<]> or C<[>I<attr> C<isnt> C<false><C<]>

The opposite of C<is>.

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

=back


=head1 DIFFERENCES WITH CSS SELECTOR/JQUERY

=head2 No equivalent of CSS class and ID selectors

I.e.:

 E.class
 E#id

They are not used in CSel.

=head2 Syntax of attribute selector is a bit different

CSel follows Perl more closely. There are operators not supported by CSel, but
CSel adds more operators from Perl. In particular, the whole substring matching
operations like C<[attr^=val]>, C<[attr$=val]>, C<[attr*=val]>, C<[attr~=val]>,
and C<[attr|=val]> can be performed with the more flexible regex matching
instead C<[attr =~ /re/]>.

=head2 Attribute selector or pseudo-class without type/universal selector is not allowed

jQuery allows this:

 [disabled]

which is the same as:

 *[disabled]

In CSel you have to explicitly says the latter.

=head2 Different pseudo-classes supported

Some CSS pseudo-classes only make sense for a DOM or a visual browser, e.g.
C<:link>, C<:visited>, C<:hover>.

=head2 There is no concept of CSS namespaces

But Perl packages are already hierarchical.


=head1 FUNCTIONS

The functions are not exported by default but they are exportable.

=head2 parse_csel_expr($expr) => hash|undef

Parse an expression. On success, will return a hash containing parsed
information. On failure, will return undef.
