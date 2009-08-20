package Pamilla::View::TT;

use base 'Catalyst::View::TT';
use strict;

=head1 NAME

Pamilla::View::TT - Pamilla TT (Template Toolkit) Site View

=head1 SYNOPSIS

See L<Pamilla>

=head1 DESCRIPTION

Pamilla TT Site View.

=cut

__PACKAGE__->config({
    CATALYST_VAR => 'c',
    INCLUDE_PATH => [
        Pamilla->path_to( 'root', 'src' ),
        Pamilla->path_to( 'root', 'lib' )
    ],
    PRE_PROCESS  => 'config/main',
    WRAPPER      => 'site/wrapper',
    ERROR        => 'error.tt2',
    TIMER        => 0,
    TEMPLATE_EXTENSION => '.tt2',
    #COMPILE_DIR => '/tmp/Pamilla/cache',
});

=head1 AUTHOR

Michal Jurosz <mj@mj41.cz>

=head1 LICENSE

This file is part of Pamilla. See L<Pamilla> license.

=cut

1;
