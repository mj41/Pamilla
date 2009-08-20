package DictAgent::Plugin::SeznamCz;

use utf8;
use strict;
use warnings;
use Carp qw(verbose carp croak);

use base 'DictAgent::PluginBase';


sub run {
    my ( $self, $word ) = @_;
    my $debug = $self->{debug};

    return undef unless $word;

    my $url_base = 'http://slovnik.seznam.cz/?q=%s&lang=en_cz';
    my $url = sprintf( $url_base, $word );

    my $cache_fn_suffix = $word;
    $cache_fn_suffix =~ s{[  \\\/\;\:\}\{\]\[\>\<\=  ]}{_}gx;
    $cache_fn_suffix .= '.html';

    my $tree = $self->get_tree_from_cached_url( $url, $cache_fn_suffix );

    my $content = $tree->look_down('_tag', 'div', 'id', 'results' );
    return undef unless $content;
    return $content->as_HTML;
}

1;
