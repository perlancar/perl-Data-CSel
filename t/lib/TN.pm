package # hide from PAUSE
    TN;

sub new {
    my $class = shift;
    my ($attrs, $parent) = @_;
    my $obj = bless {parent=>$parent, children=>[]}, $class;
    for (keys %$attrs) { $obj->{$_} = $attrs->{$_} }
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

sub as_string {
    my $self = shift;
    my $level = shift // 0;
    ("  " x $level ) . "$self->{id}\n" .
        join("", map { $_->as_string($level+1) } @{ $self->{children} });
}

sub AUTOLOAD {
    my $method = $AUTOLOAD; $method =~ s/.*:://;
    my $self = shift;
    $self->{$method};
}

1;
