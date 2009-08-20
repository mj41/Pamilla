package WWW::RobotBase;

use strict;
use warnings;
use Carp qw(verbose carp croak);

use LWP::UserAgent;
use HTML::TreeBuilder;
use HTTP::Request;
use HTTP::Request::Common;
use HTTP::Cookies;
use Encode;
use Time::HiRes qw(time sleep);


sub new {
    my $class = shift;
    my $params = shift;

    my $self  = {};
    $self->{debug} = $params->{debug};
    $self->{last_download_time} = 0;
    $self->{sleep_time} = $params->{sleep_time} || 1.0;
    $self->{timeout} = $params->{timeout} || 10*60;
    $self->{user_agent} = undef;
    $self->{user_agent_web_name} = '';
    $self->{temp_dir} = $params->{temp_dir} || './temp/';
    $self->{cache_dir_base} = $params->{cache_dir_base} || $self->{temp_dir} . 'cache/';
    $self->{cookies_dir_base} = $params->{cookies_dir_base} || $self->{temp_dir} . 'cookies/';

    bless $self, $class;
    return $self;
}


sub debug {
    my $self = shift;
    if (@_) { $self->{debug} = shift }
    return $self->{debug};
}


sub dumper {
    my $self = shift;
    require Data::Dumper;
    print Data::Dumper::Dumper( @_ );
}

sub init_user_agent {
    my ( $self ) = @_;

    $self->{user_agent} = LWP::UserAgent->new(
        agent => 'Mozilla/5.0 (Windows; U; Windows NT 5.1; cs; rv:1.9) Gecko/2008052906 Firefox/3.0',
        keep_alive => 1,
        timeout => 300
    );
    $self->{user_agent}->default_header('Accept-Language' => "en-us;q=0.7,en;q=0.3,cs");

    #Host    ent.ro.vutbr.cz
    #User-Agent  Mozilla/5.0 (Windows; U; Windows NT 5.1; cs; rv:1.9) Gecko/2008052906 Firefox/3.0
    #Accept  */*
    #Accept-Language cs,en-us;q=0.7,en;q=0.3
    #Accept-Encoding gzip,deflate
    #Accept-Charset  ISO-8859-2,utf-8;q=0.7,*;q=0.7
    #Keep-Alive  300
    #Connection  keep-alive
    #Referer https://ent.ro.vutbr.cz/vyvoj/jurosz/studis/student.phtml?sn=individualni_plan_nepov
    return 1;
}


sub get_web_cache_dir {
    my ( $self, $web_name ) = @_;
    return $self->{cache_dir_base} . $web_name . '/';
}


# nutne zavolat vzdy, kdyz se zmeni web
sub web_change {
    my ( $self, $web_name ) = @_;

    # pokud uz user agent existuje tak zmenime cookie
    # slo by pouzit i stejnou, ale kvuli mazani takhle
    if ( $self->{user_agent} ) {
        my $cookie_fp = $self->{cookies_dir_base} . $web_name . ".txt";
        my $cookie_jar = HTTP::Cookies->new(
            file => $cookie_fp,
            autosave => 1,
            hide_cookie2 => 1
        );
        $self->{user_agent}->cookie_jar( $cookie_jar );
    }

    # zmenime cache adresar a pripadne vytvorime
    $self->{web_cache_fn_base} = $self->get_web_cache_dir( $web_name );
    mkdir( $self->{web_cache_fn_base} ) unless -d $self->{web_cache_fn_base};

    # smazeme, sice pri stridani dvou webu bude bez pauzy, ale k tomu by dochaze nemelo
    $self->{last_download_time} = 0;

    $self->{user_agent_web_name} = $web_name;
}


# smaze cookie
sub clear_cookie {
    my $self = shift;
    return $self->{user_agent}->cookie_jar()->clear;
}


sub purge_cache {
    my ( $self, $web_name ) = @_;

    my $web_cache_dir = $self->get_web_cache_dir( $web_name );
    return 1 unless -d $web_cache_dir ;

    opendir( my $dir_handle, $web_cache_dir  ) or croak "Can't open '$web_cache_dir'.\n$!";

    while ( my $file = readdir($dir_handle) ) {
        my $file_path = $web_cache_dir . $file;
        next unless -f $file_path;
        unlink( $file_path );
    }
    return 1;
}


# TODO
# nastavi referer
sub set_referer {
    my ( $self, $referer_url ) = @_;
    return $self->{user_agent}->default_header( 'Referer', $referer_url );
}


# nutne zavolat vzdy predtim nez pouzijeme user agenta
sub before_agent_use {
    my ( $self, $web_name ) = @_;

    # pauza mezi stahovanim
    if ( $self->{last_download_time} + $self->{sleep_time} > time() ) {
        my $rand_coeficient = rand(5) / 10;
        my $sleep_time = $self->{sleep_time} * ( 1 + $rand_coeficient );
        my $to_sleep = ( $self->{last_download_time} + $self->{sleep_time} ) - time();
        $to_sleep = 0 if $to_sleep < 0;
        printf( "Sleeping %3.2f (%2.1f) s ...\n" , $to_sleep, $rand_coeficient );
        sleep( $to_sleep );
    }
    $self->{last_download_time} = time();

    # pokud user agent neexistuje, tak jej vytvorime
    unless ( defined $self->{user_agent} ) {
        $self->init_user_agent();
        # prvni spusteni je vpodstate take zmena webu
        $self->web_change( $web_name );
    }

    return 1;
}


# vraci primo response objekt, nepouziva cache
sub response_get {
    my ( $self, $web_name, $url ) = @_;

    $self->before_agent_use( $web_name );
    print "Getting online from url '$url'.\n";
    my $response = $self->{user_agent}->get( $url );
    return $response;
}



sub get_cached {
    my ( $self, $web_name, $url, $cache_fn_suffix, $timeout ) = @_;
    $timeout = $self->{timeout} unless defined $timeout;

    # TODO $timeout, mtime souboru

    $self->web_change( $web_name ) unless $web_name eq $self->{user_agent_web_name};
    my $cache_fn = $self->{web_cache_fn_base} . $cache_fn_suffix;

    my $page;
    unless ( -f $cache_fn ) {
        $self->before_agent_use( $web_name );

        # nefunguje, kvuli decode_content
        #my $res = $self->{user_agent}->get($url, ':content_file' => $cache_fn) || die $!;

        #print "Getting online from url '$url'.\n";
        my $res = $self->{user_agent}->get($url);
        #$res->decoded_content();
        my $page = $res->content();
        open( my $out, '>:utf8', $cache_fn ) or croak "Nelze otevrit '$cache_fn' pro zapis.\n$!";
        binmode( $out );
        print $out $page;
        close $page;
        return decode_utf8 $page;

        # TODO
        #$page = $res->content;
        #return $page;

    } else {
        #print "Loading from cache file '$cache_fn'.\n";
    }

    local $/ = undef;
    my $fh;
    open( $fh, '<:utf8', $cache_fn ) || die $!;
    binmode( $fh );
    $page = <$fh>;
    return decode_utf8 $page;
}


1;
