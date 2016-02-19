package Data::CSel;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

sub new {

}

1;
# ABSTRACT: Select nodes of object/data tree using CSS Selector-like syntax

=head1 SYNOPSIS

 use Data::CSel;



=head1 DESCRIPTION

This class lets you use a query language (hereby named CSel) that is similar to
CSS Selector to select nodes of object/data tree.


=head1 METHODS


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
