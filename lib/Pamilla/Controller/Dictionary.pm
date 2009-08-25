package Pamilla::Controller::Dictionary;

use strict;
use warnings;
use Carp qw(carp croak);
use parent 'Catalyst::Controller';

use FindBin qw($RealBin);
use JSON;
use Time::HiRes qw(sleep time);

use WWW::RobotBase;
use DictAgent;

sub get_dict_html {
    my ( $self, $c, $word ) = @_;

    my $debug = 1;
    my $command = 'cache';

    my $plugin_name = 'SeznamCz';
    my $web = lc( $plugin_name );
    my $full_plugin_name = 'DictAgent::Plugin::' . $plugin_name;

    unless ( $self->{web_robot_obj} ) {
        my $temp_dir = $RealBin . '/../../pamilla-data/temp-files/';
        mkdir $temp_dir unless -d $temp_dir;
        my $cache_dir = $temp_dir . 'cache/';
        mkdir $cache_dir unless -d $cache_dir;
        return undef unless -d $cache_dir;

        my $web_robot_obj = WWW::RobotBase->new( {
            'debug' => $debug,
            'temp_dir' => $temp_dir,
        } );
        $self->{web_robot_obj} = $web_robot_obj;

        eval "require $full_plugin_name" or  croak $@ . "\n in plugin $plugin_name.";

    }

    my $online = ( $command eq 'online' );
    my $plugin_obj = $full_plugin_name->new( {
        web_robot => $self->{web_robot_obj},
        online => $online,
        debug => $debug,
    } );
    unless ( $plugin_obj->plugin_status() ) {
        return undef;
    }

    my $html = $plugin_obj->run( $word );
    return $html;
}



sub save_new_text {
    my ( $self, $c, $file_name, $text, $timestamp, $data_dir ) = @_;

    my $fpath = $data_dir . 'data/' . $file_name;

    my $data = [];

    my $fh;
    if ( -f $fpath ) {
        unless ( open($fh,'<:utf8',$fpath) ) {
            return 0;
        }
        my $json = do { local $/; <$fh> };
        close $fh;
        $data = from_json( $json );
    }

    push @$data, [ $text, $timestamp ];

    unless ( open($fh,'>:utf8', $fpath) ) {
        return 0;
    }

    my $new_json = to_json( $data );
    print $fh $new_json;
    close $fh;

    return 1;
}



sub process_text {
    my ( $self, $c, $data, $text, $timestamp, $data_dir ) = @_;

    return 1 unless $text;

    $text =~ s{\s+$}{}x;
    $text =~ s{^\s+}{}x;

    # Probably hacking on code.
    if ( $text =~ /\$/ ) {
        $data->{html} = "text: '$text'<br />\n";
        $data->{html} = "<br />\n";
        $data->{html} .= '<div style="color:red">Warning: Shouldn\'t you disable dictionary.</div>';
        return 1;
    }

    if ( length($text) > 250 ) {
        $self->save_new_text( $c, 'dictionary-full_texts.json', $text, $timestamp, $data_dir );
        $data->{html} .= '<div style="color:red">Full text saved.</div>';
        return 1;
    }

    if ( length($text) > 25 ) {
        $data->{html} = "text: '$text'<br />\n";
        $data->{html} = "<br />\n";
        $data->{html} .= '<div style="color:red">Warning: Too long word.</div>';
        return 1;
    }

    my $word = $text;

    $word =~ s{ [\s\.\!\?\,\:\;\"]+$}{}x;
    $word =~ s{^[\s\.\!\?\,\:\;\"]+ }{}x;
    $word = lc($word);

    $data->{html} = "word: '$word'<br />\n";
    $data->{html} .= $self->get_dict_html( $c, $word );
    $c->log->info( substr( $data->{html}, 0, 100) );

    $self->save_new_text( $c, 'dictionary.json', $word, $timestamp, $data_dir );

    return 1;
}



sub index : Path  {
    my ( $self, $c, @arg ) = @_;

    my $start_time = time();

    my $params = $c->request->params;

    my $data = {};
    $c->stash->{data} = $data;

    my $prev_req_aborted = $params->{prev_req_aborted};

    $data->{html} = '';

    my $data_dir = $RealBin . '/../../pamilla-data/';
    my $fh;

    my $sl_data;
    my $sl_fpath = $data_dir . 'web_dictionary.json';
    if ( open($fh,'<:utf8',$sl_fpath) ) {
        my $json = do { local $/; <$fh> };
        #$data->{html} .= $json;
        close $fh;

        $sl_data = from_json( $json );
    }


    my $clb_fpath = $data_dir . 'clipboard.json';

    # Should be shorter than timeout_time variable in js/ajax.php.
    while ( time() - $start_time < 10 - 0.25 ) {
        my ( $dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime, $mtime, $ctime, $blksize, $blocks ) = stat( $clb_fpath );

        my $changed = 0;
        # File changed.
        if ( !$sl_data->{mtime} || $sl_data->{mtime} != $mtime || $prev_req_aborted ) {
            if ( open($fh,'<:utf8',$clb_fpath) ) {
                my $json = do { local $/; <$fh> };
                close $fh;
                my $clb_data = from_json( $json );

                # Data are for as and text changed.
                if ( $clb_data->{selected} eq 'dictionary' && ( $prev_req_aborted || (not defined $sl_data->{clipboard_text}) || $sl_data->{clipboard_text} ne $clb_data->{clipboard_text}) ) {
                    $changed = 1;

                    $self->process_text(
                        $c,
                        $data,
                        $clb_data->{clipboard_text},
                        $clb_data->{timestamp},
                        $data_dir
                    );
                    $sl_data->{clipboard_text} = $clb_data->{clipboard_text};
                }

            } else {
                $data->{html} .= 'err:' . $! . " '$clb_fpath'";
                last;
            }

            # Save new values. Value of clipboard_text probably set earlier.
            $sl_data->{mtime} = $mtime;
            if ( open($fh,'>:utf8', $sl_fpath) ) {
                my $new_sl_data = to_json( $sl_data );
                print $fh $new_sl_data;
                close $fh;
            }

            last if $changed;
        }
        sleep(0.25);
    }

    if ( $params->{ot} && $params->{ot} eq 'html' ) {
        use Data::Dumper;
        $c->stash->{ot} = Dumper( $c->stash->{data} );
        return;
    }

    $c->forward('Pamilla::View::JSON');
}

1;
