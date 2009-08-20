package DictAgent;

use strict;
use warnings;
use Carp qw(verbose carp croak);

sub new {
    my $class = shift;
    my $params = shift;

    my $self  = {};
    $self->{debug} = $params->{debug};
    $self->{dump_prev_caller_str} = '';

    bless $self, $class;
    return $self;
}


sub debug {
    my $self = shift;
    if (@_) { $self->{debug} = shift }
    return $self->{debug};
}


sub raw_dump {
    my $self = shift;
    my $caller_offset = shift;

    require Data::Dumper;

    my $cal = (caller(1+$caller_offset))[3];
    my $line = (caller(0+$caller_offset))[2];
    my $caller_str = "on $cal line $line";

    if ( $caller_str eq $self->{dump_prev_caller_str} ) {
        print "Dumper used $caller_str:\n";
    } else {
        $self->{dump_prev_caller_str} = $caller_str;
    }
    print Data::Dumper::Dumper( @_ );
    return 1;
}


sub dump {
    my $self = shift;
    return $self->raw_dump( 0, @_ );
}


sub edump {
    my $self = shift;
    $self->raw_dump( 1, @_ );

    print "Exiting, edump used on ";
    my $cal = (caller 1)[3];
    my $line = (caller 0)[2];
    print "$cal line $line.\n";
    exit;
}



1;