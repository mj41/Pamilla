package Pamilla::Controller::DayAgenda;

use parent 'Catalyst::Controller';

use strict;
use warnings;
use Carp qw(carp croak);

use FindBin qw($RealBin);

use DateTime;


sub get_time_diff {
    my ( $self, $c, $prev_min_timestamp, $min_timestamp ) = @_;

    my $min_diff = $min_timestamp - $prev_min_timestamp;
    return $min_diff;
}


sub add_time_diff_to_part {
    my ( $self, $c, $stat, $part_name, $category_text, $base_text, $desc_text, $time_diff_min ) = @_;

    $stat->{ $part_name }->{_all_category}->{ $base_text } = 0 unless exists $stat->{ $part_name }->{_all_category}->{ $base_text };
    $stat->{ $part_name }->{_all_category}->{ $base_text } += $time_diff_min;

    $stat->{ $part_name }->{_category_sum}->{ $category_text } = 0 unless exists $stat->{ $part_name }->{_category_sum}->{ $category_text };
    $stat->{ $part_name }->{_category_sum}->{ $category_text } += $time_diff_min;

    $stat->{ $part_name }->{ $category_text }->{ $base_text } = 0 unless exists $stat->{ $part_name }->{ $category_text }->{ $base_text };
    $stat->{ $part_name }->{ $category_text }->{ $base_text } += $time_diff_min;

    $c->stash->{ot} .= "part_name $part_name $base_text ($category_text:$desc_text) + $time_diff_min\n";
    return 1;
}


sub add_time_diff {
    my ( $self, $c, $stat, $datetime, $category_text, $base_text, $desc_text, $time_diff_min ) = @_;


    my $dt_now = $c->stash->{datetime_now};
    my $dt_yesterday = $c->stash->{datetime_yesterday};
    my $dt_week_back = $c->stash->{datetime_week_back};

    # all 1/1
    $self->add_time_diff_to_part( $c, $stat, 'all', $category_text, $base_text, $desc_text, $time_diff_min );

    # year 1/1
    if ( $dt_now->year == $datetime->year ) {
        $self->add_time_diff_to_part( $c, $stat, 'year', $category_text, $base_text, $desc_text, $time_diff_min );

        # quarter 1/1: same year, same quarter
        if ( $dt_now->quarter == $datetime->quarter ) {
            $self->add_time_diff_to_part( $c, $stat, 'quarter', $category_text, $base_text, $desc_text, $time_diff_min );
        }

        # month 1/1: same year, same month
        if ( $dt_now->month == $datetime->month ) {
            $self->add_time_diff_to_part( $c, $stat, 'month', $category_text, $base_text, $desc_text, $time_diff_min );

            # day 1/1: same year, same month, same day
            if ( $dt_now->day == $datetime->day ) {
                $self->add_time_diff_to_part( $c, $stat, 'day', $category_text, $base_text, $desc_text, $time_diff_min );
            }
        }

        # week 1/1: same year, same week
        if ( $dt_now->week_number == $datetime->week_number ) {
            $self->add_time_diff_to_part( $c, $stat, 'week', $category_text, $base_text, $desc_text, $time_diff_min );
        }

        # prev_quarter 1/2: same year, prev quarter
        if ( $dt_now->quarter - 1 == $datetime->quarter ) {
            $self->add_time_diff_to_part( $c, $stat, 'prev_quarter', $category_text, $base_text, $desc_text, $time_diff_min );
        }

        # prev_month 1/2: same year, prev month
        if ( $dt_now->month - 1 == $datetime->month ) {
            $self->add_time_diff_to_part( $c, $stat, 'prev_month', $category_text, $base_text, $desc_text, $time_diff_min );
        }
    }

    # prev_day 1/1: same year as yesterday, same day_of_year as yesterday
    if ( $dt_yesterday->year == $datetime->year && $dt_yesterday->day_of_year == $datetime->day_of_year ) {
        $self->add_time_diff_to_part( $c, $stat, 'prev_day', $category_text, $base_text, $desc_text, $time_diff_min );
    }

    # prev_week 1/1: same year as one week back, same week_number as one week back
    if ( $dt_week_back->year == $datetime->year && $dt_week_back->week_number == $datetime->week_number ) {
        $self->add_time_diff_to_part( $c, $stat, 'prev_week', $category_text, $base_text, $desc_text, $time_diff_min );
    }

    # prev_year 1/1
    if ( $dt_now->year - 1 == $datetime->year ) {
        $self->add_time_diff_to_part( $c, $stat, 'prev_year', $category_text, $base_text, $desc_text, $time_diff_min );

        # prev_quarter 2/2: prev year, act quarter is 1, data quarter is 4
        if ( $dt_now->quarter == 1 && $datetime->quarter == 4 ) {
            $self->add_time_diff_to_part( $c, $stat, 'prev_quarter', $category_text, $base_text, $desc_text, $time_diff_min );
        }

        # prev_month 2/2: prev year, act month is 1, data month is 12
        if ( $dt_now->month == 1 && $datetime->month == 12 ) {
            $self->add_time_diff_to_part( $c, $stat, 'prev_month', $category_text, $base_text, $desc_text, $time_diff_min );
        }
    }

    return 1;
}


sub save_category {
    my ( $self, $c, $cat, $category_text, $base_text ) = @_;

    if ( exists $cat->{ $base_text } ) {
        if ( $cat->{ $base_text } ne $category_text ) {
            my $prev_cat = $cat->{$base_text};
            $cat->{ $base_text } = $category_text;
            return "Redefinig category for '$base_text' from '$prev_cat' to '$category_text'.";
        }
        return undef;
    }

    $cat->{ $base_text } = $category_text;
    return undef;
}


sub get_category {
    my ( $self, $c, $cat, $base_text ) = @_;
    return $cat->{ $base_text } if exists $cat->{ $base_text };
    return undef;
}


sub index : Path  {
    my ( $self, $c, @arg ) = @_;

    my $data = {};

    $c->stash->{data} = $data;

    my $fpath = 'C:\mj\WH.txt';
    my $text = '';

    my $fh;
    if ( open($fh,'<:utf8',$fpath) ) {
        $text = do { local $/; <$fh> };
        close $fh;
    }

    my @lines = split( /\n/, $text );

    $c->stash->{datetime_now} = DateTime->now;

    $c->stash->{datetime_yesterday} = $c->stash->{datetime_now}->clone;
    $c->stash->{datetime_yesterday}->add( days => -1 );

    $c->stash->{datetime_week_back} = $c->stash->{datetime_now}->clone;
    $c->stash->{datetime_week_back}->add( days => -7 );

    my @stat_parts = qw/ day prev_day week prev_week month prev_month quarter prev_quarter year prev_year all /;
    my $stat = {};
    my $cat = {};

    my $prev_min_timestamp = undef;
    my $prev_category_text = undef;
    my $prev_base_text = undef;
    my $prev_desc_text = undef;

    my $act_day = undef;
    my $act_month = undef;
    my $act_year = undef;
    my $act_datetime = undef;

    my $first_item = 0;
    foreach my $line_num ( 0..$#lines ) {
        my $line = $lines[ $line_num ];

        next if $line =~ m/^ \s* \# /x;

        if ( my ( $t_day, $t_month, $t_year ) = $line =~ m/^ .*? \s* (\d+) \s* \. \s* (\d+) \s* \. \s* (\d+)? \s* .*? \s* $/x ) {
            $t_year = $c->stash->{datetime_now}->year unless $t_year;
            $c->stash->{ot} .= sprintf( "%60s : %4d : ", "'$line'", $line_num) . "$t_day-$t_month-$t_year\n";
            $first_item = 1;

            $act_day = $t_day;
            $act_month = $t_month;
            $act_year = $t_year;
            $act_datetime = DateTime->new(
                year   => $act_year,
                month  => $act_month,
                day    => $act_day,
                hour   => 0,
                minute => 0,
                second => 0,
                nanosecond => 0,
                time_zone => 'Europe/Prague',
            );

        } elsif ( my ( $t_time_hour, $t_time_min, $t_category_text, $t_category_separator, $t_base_text, $t_desc_text ) = $line =~ m/^
                \s*
                (?: \* \s*)?
                ( \d+ ) \s* \: \s* ( \d+ ) \s*
                \- \s*
                (?: ([^\:]+?) \s* (\:+) \s* )?
                ( [^\)\(\:]+? )
                (?: \s* \( (.*?) \) )? \s*
            $/x )
        {
            my $min_timestamp = $t_time_hour * 60 + $t_time_min;
            $t_desc_text = '' unless $t_desc_text;

            if ( $t_category_text ) {
                if ( $t_category_separator eq '::' ) {
                    my $err_text = $self->save_category( $c, $cat, $t_category_text, $t_base_text );
                    if ( defined $err_text ) {
                        $c->stash->{err} .= "ERROR: $err_text\n";
                        $c->stash->{ot} .= "ERROR: $err_text\n";
                    }
                }

            } else {
                $t_category_text = $self->get_category( $c, $cat, $t_base_text );
                $t_category_text = '_' unless defined $t_category_text;
                $t_category_separator = '' unless defined $t_category_separator;
            }

            $c->stash->{ot} .= sprintf( "%60s : %4d : ", "'$line'", $line_num) . "'$t_time_hour:$t_time_min' ($min_timestamp) - '$t_base_text' ($t_category_text $t_category_separator $t_desc_text)\n";

            if ( ! $first_item ) {
                my $time_diff_min = $self->get_time_diff( $c, $prev_min_timestamp, $min_timestamp );

                if ( $prev_category_text eq '_' ) {
                    $c->stash->{err} .= "UNKNOWN CATEGORY for '$prev_base_text'\n";
                    $c->stash->{ot} .= "UNKNOWN CATEGORY for '$prev_base_text'\n";
                }

                $self->add_time_diff( $c, $stat, $act_datetime, $prev_category_text, $prev_base_text, $prev_desc_text, $time_diff_min );

                $t_desc_text = '' unless $t_desc_text;
                $c->stash->{ot} .= sprintf("%67s : ", '') . " ---> '$prev_base_text' ($t_category_text $t_category_separator $t_desc_text) + $time_diff_min\n";
            }
            $prev_min_timestamp = $min_timestamp;
            $prev_category_text = $t_category_text;
            $prev_base_text = $t_base_text;
            $prev_desc_text = $t_desc_text;
            $first_item = 0;

        } else {
            $c->stash->{ot} .= sprintf( "%60s : %4d : ", "'$line'", $line_num) . "\n";
        }
    }


    foreach my $part ( @stat_parts ) {

       $data->{sort} .= "\n\n";
       $data->{sort} .= "---- part: $part --------------------------------------------\n";

        my @categories = ( sort keys %{$stat->{ $part }} );
        foreach my $category ( @categories ) {

            my $stat_part = $stat->{ $part }->{ $category };
            $data->{sort} .= "\n";
            $data->{sort} .= "category: $category\n";

            foreach my $key ( sort { $stat_part->{$b} <=> $stat_part->{$a} } keys %$stat_part ) {
                $data->{sort} .= "  " . $key . ' - ' . $stat_part->{$key} . "\n";
            }
        }
    }

    $data->{stat} = $stat;

    use Data::Dumper;
    $c->stash->{ot} = Dumper( $c->stash->{data} ) . $c->stash->{ot};

    return 1;
}

1;
