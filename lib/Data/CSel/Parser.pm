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
                      (\s*>\s*|\s*\+\s*|\s*~\s*|\s+)
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
# ABSTRACT: Parse CSel expression

=head1 SYNOPSIS

 use Data::CSel::Parser qw(parse_csel_expr);

 my $res = parse_csel_expr("Table[num_rows > 0] > TableRow > TableCell");


=head1 FUNCTIONS

The functions are not exported by default but they are exportable.

=head2 parse_csel_expr($expr) => hash|undef

Parse an expression. On success, will return a hash containing parsed
information. On failure, will return undef.
