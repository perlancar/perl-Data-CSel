package # hide from PAUSE
    TN2;

use parent 'TN';

sub int2 {
    my $self = shift;
    $self->{int2} = $_[0] if @_;
    $self->{int2};
}

1;
