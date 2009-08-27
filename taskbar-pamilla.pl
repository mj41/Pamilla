#!/usr/bin/perl

use utf8;
use Wx;

use FindBin qw($RealBin);

use vars qw($ID_QUIT $ID_ABOUT $ID_LAST_USED);
( $ID_QUIT, $ID_ABOUT, $ID_LAST_USED ) = ( 10000 .. 10020 );

use vars qw($CLIPBOADR_PATH);
$CLIPBOADR_PATH =  $RealBin . '/../pamilla-data/';

# every program must have a Wx::App-derive class
package MyApp;

use strict;
use vars qw(@ISA);


@ISA=qw(Wx::App);

# this is called automatically on object creation
sub OnInit {
  my( $this ) = @_;

  # create new MyFrame
  my( $frame ) = MyFrame->new( "Minimal wxPerl app",
                   Wx::Point->new( 50, 50 ),
                   Wx::Size->new( 450, 350 )
    );

  # set it as top window (so the app will automatically close when
  # the last top window is closed)
  #$this->SetTopWindow( $frame );

  # show the frame
  #$frame->Show( 1 );

  1;
}

package MyFrame;

use strict;
use vars qw(@ISA);

@ISA=qw(Wx::Frame);

use JSON qw(to_json from_json);
use Time::HiRes qw(time sleep);

use Wx qw(wxBITMAP_TYPE_ICO wxMENU_TEAROFF wxBITMAP_TYPE_ICO);
use Wx::Event qw(EVT_MENU EVT_CLOSE EVT_TIMER);
use Wx::Event qw(EVT_TASKBAR_LEFT_DOWN EVT_TASKBAR_RIGHT_DOWN);

use Wx qw(wxTheClipboard wxDF_TEXT);
use Wx::DND;

use Win32::API 0.20;


# Parameters: title, position, size
sub new {
    my( $class ) = shift;
    my( $this ) = $class->SUPER::new( undef, -1, $_[0], $_[1], $_[2] );

    # load an icon and set it as frame icon

    my $icon = Wx::Icon->new('icon/icon.ico', wxBITMAP_TYPE_ICO);
    #my $icon = Wx::GetWxPerlIcon();
    $this->SetIcon( $icon );

    # create the menus
    my( $mfile ) = Wx::Menu->new( undef, wxMENU_TEAROFF );
    my( $mhelp ) = Wx::Menu->new();

    my( $ID_ABOUT ) = ( 1 );
    $mhelp->Append( $ID_ABOUT, "&About...\tCtrl-A", "Show about dialog" );
    $mfile->Append( $main::ID_QUIT, "E&xit\tAlt-X", "Quit this program" );

    my( $mbar ) = Wx::MenuBar->new();

    $mbar->Append( $mfile, "&File" );
    $mbar->Append( $mhelp, "&Help" );

    $this->SetMenuBar( $mbar );

    # declare that events coming from menu items with the given
    # id will be handled by these routines
    EVT_MENU( $this, $main::ID_QUIT, sub { $this->Close; } );
    EVT_MENU( $this, $ID_ABOUT, \&OnAbout );
    EVT_CLOSE( $this, \&OnClose );

    # create a status bar (note that the status bar that gets created
    # has three panes, see the OnCreateStatusBar callback below
    $this->CreateStatusBar( 1 );
    # and show a message
    $this->SetStatusText( "Welcome to wxPerl!", 1 );

    $this->{TIMER} = Wx::Timer->new( $this, 1 );
    $this->{TIMER}->Start( 250 );
    EVT_TIMER( $this, 1, \&OnTimer );


    # on MSW only, create task bar icon
    if( Wx::wxMSW() ) {
        my $tmp = Wx::TaskBarIcon->new();
        $tmp->SetIcon( $icon, "Click on me!" );
        $this->{TASKBARICON} = $tmp;


        my @tb_items_order = qw/paused dictionary/;
        my $tb_items = {
            'paused' => {
                name => 'paused'
            },
            'dictionary' => {
                name => 'dictionary'
            },
        };
        my $num = 0;
        foreach my $name ( @tb_items_order ) {
            $tb_items->{$name}->{id} = $main::ID_LAST_USED + $num;
            $num++;
        };

        my $menu = Wx::Menu->new();

        foreach my $item_name ( @tb_items_order ) {
            $menu->AppendRadioItem(
                $tb_items->{$item_name}->{id},
                $tb_items->{$item_name}->{name}
            );
        }

        $menu->AppendSeparator();
        $menu->Append( $main::ID_QUIT, "quit" );

        my $click = sub {
            my( $this, $event ) = @_;
            $this->PopupMenu( $menu );
        };


        my $GetConsoleTitle = new Win32::API('kernel32', 'GetConsoleTitle', 'PN', 'N');
        my $FindWindow = new Win32::API('user32', 'FindWindow', 'PP', 'N');
        my $ShowWindow = new Win32::API('user32', 'ShowWindow', 'NN', 'N');

        my $title = 'Pamilla';
        my $hw = $FindWindow->Call( 0, $title );
        $ShowWindow->Call( $hw, 0 ); # SW_HIDE

        $this->{selected_item} = @tb_items_order[0];
        my $sub_select_takbar = sub {
            my ( $sub_this, $event, $item_rawname ) = @_;

            if ( $item_rawname ne $this->{selected_item} ) {
                my $empty_tdobj = Wx::TextDataObject->new( '' );
                wxTheClipboard->Open;
                wxTheClipboard->SetData( $empty_tdobj );
                wxTheClipboard->Close;

            }
            if ( $item_rawname eq 'paused' ) {
                $ShowWindow->Call( $hw, 0 ); # SW_HIDE
            } else {
                $ShowWindow->Call( $hw, 3 ); # SW_SHOWMAXIMIZED
            }

            $this->{selected_item} = $item_rawname;

        };

        my $sub_quit = sub {
            $ShowWindow->Call( $hw, 0 ); # SW_HIDE
            $this->Close();
        };

        EVT_TASKBAR_LEFT_DOWN( $tmp, $click );
        EVT_TASKBAR_RIGHT_DOWN( $tmp, $click );
        EVT_MENU( $tmp, $main::ID_QUIT, $sub_quit );

        foreach my $item_name ( @tb_items_order ) {
            my $id = $tb_items->{$item_name}->{id};
            EVT_MENU( $tmp, $id, sub {
                $sub_select_takbar->( @_, $item_name );
            });
        }
    }


    return $this;
}


sub dump_to_file {
    my( $this, $data ) = @_;

    my $json_text = to_json( $data );
    my $fpath = $main::CLIPBOADR_PATH . 'clipboard.json';

    my $fh;
    open ( $fh, '>', $fpath ) || die "Can't open file '$fpath' for write: $!";
    print $fh $json_text;
    close $fh;


    return 1;
}


sub OnTimer {
    my( $this ) = shift;

    wxTheClipboard->Open;

    my $text = '';
    if( wxTheClipboard->IsSupported( wxDF_TEXT ) ) {
        my $data = Wx::TextDataObject->new;
        my $ok = wxTheClipboard->GetData( $data );
        if( $ok ) {
            my $clb_text = $data->GetText;

            my $selected_changed = ( (not defined $this->{prev_selected_item}) || $this->{selected_item} ne $this->{prev_selected_item} );
            $this->{prev_selected_item} = $this->{selected_item} if $selected_changed;

            my $clb_text_changed = ( (not defined $this->{prev_clb_text}) || $clb_text ne $this->{prev_clb_text} );
            $this->{prev_clb_text} = $clb_text if $clb_text_changed;

            if ( $selected_changed || $clb_text_changed ) {
                my $data = {
                    'selected' => $this->{selected_item},
                    'clipboard_text' => $clb_text,
                    'timestamp' => time()
                };
                $this->dump_to_file($data);
            }

        } else {
            Wx::LogMessage( "Error pasting text data" );
            $text = '';
        }
    }
    wxTheClipboard->Close;

    #$this->{TIMER}->Stop;
}


# this is an addition to demonstrate virtual callbacks...
# it ignores all parameters and creates a status bar with three fields
sub OnCreateStatusBar {
  my( $this ) = shift;
  my( $status ) = Wx::StatusBar->new( $this, -1 );

  $status->SetFieldsCount( 2 );

  $status;
}


# called when the user selects the 'Exit' menu item
sub OnQuit {
  my( $this, $event ) = @_;

  # closes the frame
  $this->Close( 1 );
}


sub OnClose {
  my $this = shift;

  Wx::Log::SetActiveTarget( $this->{OLDLOG} );
  $this->{TASKBARICON}->Destroy
    if defined $this->{TASKBARICON};

  $this->Destroy;
}


sub DESTROY {
    my $this = shift;
    $this->{TIMER}->Destroy;
}


use Wx qw(wxOK wxICON_INFORMATION wxVERSION_STRING);

# called when the user selects the 'About' menu item
sub OnAbout {
  my( $this, $event ) = @_;

  # display a simple about box
  Wx::MessageBox( "This is the about dialog of minimal sample.\n" .
          "Welcome to wxPerl " . $Wx::VERSION . "\n" .
          wxVERSION_STRING,
          "About minimal", wxOK | wxICON_INFORMATION,
          $this );
}

package main;

# create an instance of the Wx::App-derived class
my( $app ) = MyApp->new();
# start processing events
$app->MainLoop();

# Local variables: #
# mode: cperl #
# End: #
