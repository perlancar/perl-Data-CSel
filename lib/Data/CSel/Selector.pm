package Data::CSel::Selector;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(select_nodes_with_csel);


sub select_nodes_with_csel {
    require Data::CSel::Parser;

    my ($expr, $tree, $opts) = @_;
    $opts //= {};

    my $pexpr =  Data::CSel::Parser::parse_csel_expr($expr);

    # XXX wrap tree using wrapper object if not blessed

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
# ABSTRACT: Select nodes from tree object using CSel query language

=head1 SYNOPSIS

 use Data::CSel::Selector qw(select_nodes_with_csel);

 # select nodes from a tree object, return list of node objects
 my @obj = select_nodes_with_csel('Table Cell[value =~ /\S/]', $tree);

 # ditto, but wrap result with selection object (Data::CSel::Selection)
 my $selection = select_nodes_with_csel('...', $tree, {wrap=>1});


=head1 DESCRIPTION


=head1 FUNCTIONS

=head2 select_nodes_with_csel($expr, $tree[ , \%opts ]) => list|obj

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
