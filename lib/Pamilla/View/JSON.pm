package Pamilla::View::JSON;

use base 'Catalyst::View::JSON';
use strict;

=head1 NAME

Pamilla::View::JSON - TapTinder JSON Site View

=head1 SYNOPSIS

See L<Pamilla>

=head1 DESCRIPTION

Pamilla JSON Site View.

=cut

__PACKAGE__->config({
    #allow_callback  => 1,    # defaults to 0
    #callback_param  => 'cb', # defaults to 'callback'
    expose_stash    => [ qw(data ot) ], # defaults to everything
    #no_x_json_header => 1,
});

=head1 AUTHOR

Michal Jurosz <mj@mj41.cz>

=head1 LICENSE

This file is part of Pamilla. See L<Pamilla> license.

=cut

1;
