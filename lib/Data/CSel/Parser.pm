package Data::CSel::Parser;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(parse_csel_expr);

our $re_elem =
    qr/
          [A-Za-z_][A-Za-z0-9_]*(?:::[A-Za-z0-9_]+)*
      /x;

our $re_attr_name =
    qr/
          [A-Za-z_][A-Za-z0-9_]*
      /x;

our $re_attr_op_val =
    qr/
          \w+
      /x;

our $re_pseudoclass_name =
    qr/
          [A-Za-z_][A-Za-z0-9_]*(-[A-Za-z0-9_]+)*
      /x;

our $re_attr_filter =
    qr/
          (?P<attr_name>$re_attr_name)
          (?:
              \s*
              (?P<attr_op>
                  =  |
                  !=
              )
              \s*
              (?P<attr_op_val>
                  $re_attr_op_val
              )
          )?
      /x;

our $re_pseudoclass_arg =
    qr/
          \w+
      /x;

our $re_pseudoclass_filter =
    qr/
          (?P<pseudoclass_name>$re_pseudoclass_name)
          (?:
              \(
              (?P<pseudoclass_args>
                  (?:$re_pseudoclass_arg)
                  (?:\s*,\s*(?:$re_pseudoclass_arg))*
              )
              \)
          )?
      /x;

our $re_filter =
    qr/
          (?P<attr_filter>\[$re_attr_filter\]) |
          (?P<pseudoclass_filter>:$re_pseudoclass_filter)
      /x;

# elem with zero or more filters
our $re_elemf =
    qr/
          (?P<elem>$re_elem)
          (?P<filters>(?:$re_filter)*)
      /x;

our $re_pattern =
    qr/
          (?:$re_elemf)
      /x;

our $re =
    qr/
          \A\s*
          (?:$re_pattern)
          \s*\z
      /x;

sub parse_csel_expr {
    my $expr = shift;
    if ($expr =~ $re) {
        return {%+};
    } else {
        return undef;
    }
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
