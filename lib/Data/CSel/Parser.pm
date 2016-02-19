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

A I<type selector> is a Perl class/package name, e.g.:

 My::Class

A I<universal selector> is C<*> and matches any class/package.

=head2 Attribute selector

An I<attribute selector> filters objects based on their attributes, and is
either:

C<[>I<attr>C<]> to filter only objects that C<can()> I<attr>;

C<[!>I<attr>C<]> to filter only objects that cannot I<attr>;

C<[>I<attr> C<=> I<value>C<]> or C<[>I<attr> C<==> I<value>C<]> to filter
only objects where the attribute named I<attr> has the value I<value> (compared
numerically);

C<[>I<attr> C<eq> I<value>C<]> to filter only objects where the attribute
named I<attr> has the value I<value> (compared stringily, using Perl's C<eq>
operator);

C<[>I<attr> C<!=> I<value>C<]>

C<[>I<attr> C<ne> I<value>C<]>

C<[>I<attr> C<< > >> I<value>C<]>

C<[>I<attr> C<gt> I<value>C<]>

C<[>I<attr> C<< >= >> I<value>C<]>

C<[>I<attr> C<ge> I<value>C<]>

C<[>I<attr> C<< < >> I<value>C<]>

C<[>I<attr> C<lt> I<value>C<]>

C<[>I<attr> C<< <= >> I<value>C<]>

C<[>I<attr> C<le> I<value>C<]>

=head2 Pseudo-class

A I<pseudo-class> filters objects based on some criteria, and is either:

C<:first-child> to select only object that is the first child of its parent;

C<:first> to select only the first object;

C<:last> to select only the last object;


=head1 DIFFERENCES WITH CSS SELECTOR/JQUERY

=head2 Syntax of attribute selector is a bit different

CSel follows Perl more closely.

=head2 Attribute selector or pseudo-class without type/universal selector is not allowed

jQuery allows this:

 [disabled]

which is the same as:

 *[disabled]

In CSel you have to explicitly says the latter.


=head1 FUNCTIONS

The functions are not exported by default but they are exportable.

=head2 parse_csel_expr($expr) => hash|undef
