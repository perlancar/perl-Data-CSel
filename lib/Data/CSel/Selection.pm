package Data::CSel::Selection;

# DATE
# VERSION

sub new {
    my $class = shift;
    bless [@_], $class;
}

sub AUTOLOAD {
    my $method = $AUTOLOAD;
    $method =~ s/.*:://;

    my $self = shift;
    for (@$self) {
        $self->$method if $self->can($method);
    }
}

1;
# ABSTRACT: Selection object

=head1 DESCRIPTION

A selection object holds zero or more nodes and lets you perform operations on
all of them. It is inspired by jQuery.
