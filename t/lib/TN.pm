package # hide from PAUSE
    TN;

sub new {
    my $class = shift;
    my ($attrs, $parent) = @_;
    my $obj = bless {parent=>$parent, children=>[]}, $class;
    for (keys %$attrs) { $obj->{$_} = $_ }
    if ($parent) { push @{$parent->{children}}, $obj }
    $obj;
}

sub parent {
    my $self = shift;
    $self->{parent};
}

sub children {
    my $self = shift;
    # we deliberately do this for testing, to make sure that csel() can accept
    # both
    if (rand() < 0.5) {
        return $self->{children};
    } else {
        return @{ $self->{children} };
    }
}

sub AUTOLOAD {
    my $method = shift;
    my $self = shift;
    $self->{$method};
}

1;
