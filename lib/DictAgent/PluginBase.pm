package DictAgent::PluginBase;

use strict;
use warnings;
use Carp qw(verbose carp croak);
use utf8;

use base 'DictAgent';


sub new {
    my $class = shift;
    my $params = shift;

    my $self = $class->SUPER::new( $params, @_ );

    $self->{web_robot} = $params->{web_robot};

    if ( $params->{web} ) {
        $self->{web_name} = $params->{web};

    # use lowercassed class name as web_name
    } else {
        my ( $web_name ) = $class =~ /([^\:]+)$/;
        $web_name = lc($web_name);
        $self->{web_name} = $web_name;
    }

    $self->{online} = $params->{online};
    $self->{online} = 1 unless defined $params->{online};

    bless $self, $class;

    $self->initialize();

    return $self;
}


sub plugin_status {
    return 1;
}


sub initialize {
    my $self = shift;

    return 1 unless $self->plugin_status();
    $self->purge_cache() if $self->{online};

    return 1;
}


sub get_tree_from_cached_url {
    my ( $self, $url, $cache_fn_suffix ) = @_;

    my $page = $self->get_cached( $url, $cache_fn_suffix );

    my $tree = HTML::TreeBuilder->new_from_content( $page );
    $tree->ignore_ignorable_whitespace(0);
    $tree->no_space_compacting(1);

    return $tree;
}


sub run {
    my ( $self, $sel_sport, $sel_region, $sel_liga ) = @_;
    croak "Plugin should implement this method.";
}


sub normalize_base {
    my $self = shift;
    my $str = shift;
    my $in = $str;

    return '' unless $str;

    $str =~ s{^\s+}{};
    $str =~ s{\s+$}{};

    #print "'$in' ---> '$str'\n";
    return $str;
}


# web_robot

sub init_user_agent {
    my $self = shift;
    return $self->{web_robot}->init_user_agent( @_ );
}


sub response_get {
    my $self = shift;
    return $self->{web_robot}->response_get( $self->{web_name}, @_ );
}


sub get_cached {
    my $self = shift;
    return $self->{web_robot}->get_cached( $self->{web_name}, @_ );
}


sub purge_cache {
    my $self = shift;
    return $self->{web_robot}->purge_cache( $self->{web_name}, @_ );
}


sub raw_dump {
    my $self = shift;
    my $caller_offset = shift;

    require Data::Dumper;

    my $cal = (caller(1+$caller_offset))[3];
    my $line = (caller(0+$caller_offset))[2];
    my $caller_str = "on $cal line $line";

    my $print_caller_info_line = 0;
    unless ( $caller_str eq $self->{dump_prev_caller_str} ) {
        $self->{dump_prev_caller_str} = $caller_str;
        # TODO co kdyz se zmeni typ, to pak bude jen prvni info zavadejici
        $print_caller_info_line = 1;
    }

    my $is_tree = 0;
    my $first = $_[0];
    if ( ref $first eq 'ARRAY' && ref($first->[0]) eq 'HTML::Element' ) {
        print "Dumping HTML::Element array $caller_str:\n" if $print_caller_info_line;
        my $num = 0;
        foreach my $elem ( @$first ) {
            print "element num: $num\n";
            $elem->dump;
            print "\n";
            $num++;
        }
    } elsif ( ref $first eq 'HTML::Element' ) {
        print "Dumping HTML::Element object $caller_str:\n" if $print_caller_info_line;
        $first->dump;

    } else {
        print "Dumping perl structure $caller_str:\n" if $print_caller_info_line;
        print Data::Dumper::Dumper( @_ );
    }
    return 1;
}


1;
