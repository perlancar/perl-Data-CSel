package Data::CSel;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(csel);

sub csel {
    require Data::CSel::Selector;
    my ($expr, $tree, $opts) = @_;
    Data::CSel::Selector::select_nodes_with_csel($expr, $tree, $opts);
}

1;
# ABSTRACT: Select nodes of tree object/data structure using CSS Selector-like syntax

=head1 SYNOPSIS

 use Data::CSel qw(csel);

 # to select from data structure
 my @records  = csel("Hash:has_key('name'):has_key('age')", $data);

 # to select nodes from tree object
 my @cells = csel("Table[name=~/data/i] TCell[value isnt empty]:first", $tree);

 # ditto, but wrap result using a Data::CSel::Selection
 my $res = csel("...", $data, {wrap=>1});

 # delete all matching nodes (works even though there are zero nodes)
 $res->delete;


=head1 DESCRIPTION

This module lets you use a query language (hereby named CSel) that is similar to
CSS Selector to select nodes of tree object/data structure.


=head1 EXPRESSION SYNTAX

The following is description of the CSel query expression.

An I<expression> is chain of one or more selectors separated by commas.

A I<selector> is a chain of one or more simple selectors separated by
combinators. I<Combinators> are: white space (descendant combinator), C<< > >>
(child combinator), C<~> (general sibling combinator), or C<+> (adjacent sibling
combinator). C<E F>, or two elements combined using descendant combinator means
F element descendant of an E element. C<< E > F >> means F element child of E
element. C<E ~ F> means F element preceded by an E element. C<E + F> means F
element immediately preceded by an E element.

A I<simple selector> is either a type selector or universal selector followed
immediately by zero or more attribute selectors or pseudo-classes, in any order.

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

The opposite of C<is true> or C<is false>, respectively.

=item * C<[>I<attr> C<isnt> I<type><C<]>

The opposite of C<is> I<type>..

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


=head2 Differences with CSS selector/jQuery

=head3 No equivalent of CSS class and ID selectors

I.e.:

 E.class
 E#id

They are not used in CSel.

=head3 Syntax of attribute selector is a bit different

CSel follows Perl more closely. There are operators not supported by CSel, but
CSel adds more operators from Perl. In particular, the whole substring matching
operations like C<[attr^=val]>, C<[attr$=val]>, C<[attr*=val]>, C<[attr~=val]>,
and C<[attr|=val]> can be performed with the more flexible regex matching
instead C<[attr =~ /re/]>.

=head3 Attribute selector or pseudo-class without type/universal selector is not allowed

jQuery allows this:

 [disabled]

which is the same as:

 *[disabled]

In CSel you have to explicitly says the latter.

=head3 Different pseudo-classes supported

Some CSS pseudo-classes only make sense for a DOM or a visual browser, e.g.
C<:link>, C<:visited>, C<:hover>.

=head3 There is no concept of CSS namespaces

But Perl packages are already hierarchical.


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
