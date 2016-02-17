package Data::CSel::Parser;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(parse_csel_expr);

use DD;

our $re =
    qr{
          (?&VALUE) (?{ $_ = $^R->[1] })
          (?(DEFINE)
              (?<ATTR_NAME>
                  [A-Za-z_][A-Za-z0-9_]*
              )

              (?<ATTR_FILTER>
                  \[((?&ATTR_NAME))\]
                  (?{
                      $^R->[1]{filters} //= [];
                      push @{ $^R->[1]{filters} }, {type=>'attr', attr=>$^N};
                      [$^R, $^R->[1]];
                  })
              )

              (?<PSEUDOCLASS_NAME>
                  [A-Za-z_][A-Za-z0-9_]*(?:-[A-Za-z0-9_]+)*
              )

              (?<PSEUDOCLASS_FILTER>
                  :((?&PSEUDOCLASS_NAME))
                  (?{
                      $^R->[1]{filters} //= [];
                      push @{ $^R->[1]{filters} }, {type=>'pseudoclass', pseudoclass=>$^N};
                      [$^R, $^R->[1]];
                  })
              )

              (?<FILTERS>
                  (?&ATTR_FILTER)
                  (?:
                      \s*
                      (?&ATTR_FILTER)+
                  )?

                  |

                  (?&PSEUDOCLASS_FILTER)
                  (?:
                      \s*
                      (?&PSEUDOCLASS_FILTER)+
                  )?

              )

              (?<ELEM>
                 ([A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z0-9_]+)*)
                 (?{ [$^R, {elem=>$^N}] })
                 (?&FILTERS)?
              )

              (?<VALUE>
                  \s*
                  (?&ELEM)
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
# ABSTRACT: Parse query expression

=head1 SYNOPSIS

 use Data::CSel::Parser qw(parse_csel_expr);

 my $res = parse_csel_expr("Table > TableRow");


=head1 DESCRIPTION

=head1 DIFFERENCES WITH CSS SELECTOR

=head1 FUNCTIONS

The functions are not exported by default but they are exportable.

=head2 parse_csel_expr($expr) => hash|undef
