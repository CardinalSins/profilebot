#!/usr/bin/env perl

## REQUIRES:
# POE::Component::IRC   libpoe-component-irc-perl
# Switch                libswitch-perl
# YAML                  libyaml-perl
# Module::Refresh       libmodule-refresh-perl

use warnings;
use strict;
use Data::Dumper;
$Data::Dumper::Indent = 1;

use POE qw(Component::IRC::State);
# use POE;
# use POE::Component::IRC;
use BotCore;
use Module::Refresh;

# Thanks to encryptio, a useful tool for debugging parameters: print "$_: $_[$_]\n" for 0 .. $#_; die;
# Create the component that will represent an IRC network.
my ($irc) = POE::Component::IRC::State->spawn(Flood=>1);
my $BotCore = new BotCore($irc);

$irc->{modrefresh} = Module::Refresh->new();

# Create the bot session.  The new() call specifies the events the bot
# knows about and the functions that will handle those events.
POE::Session->create(
    object_states => [
        $BotCore => {
            heartbeat  => 'heartbeat',
            irc_nick   => 'nickchange',
            irc_join   => 'userjoin',
            irc_part   => 'userpart',
            irc_quit   => 'userpart',
            irc_kick   => 'userkicked',
            irc_public => 'parse',
            irc_msg    => 'parse',
        },
    ],
    inline_states => {
        irc_disconnected => \&bot_reconnect,
        irc_error        => \&bot_reconnect,
        irc_socketerr    => \&bot_reconnect,
        _start           => \&bot_start,
        irc_001          => \&on_connect,
        signal           => \&reload_mods,
    },
    heap => { irc => $irc },
);

my $version = "v1.0.0";

# The bot session has started.  Register this bot with the "magnet"
# IRC component.  Select a nickname.  Connect to a server.
sub bot_start {
    my $kernel  = $_[KERNEL];
    my $heap    = $_[HEAP];
    my $session = $_[SESSION];
    my %opts = $BotCore->getopts();
    $kernel->sig(URG => 'signal');
    $kernel->delay( heartbeat => $opts{self_clock} );
    $irc->yield( register => "all" );

    $irc->yield( connect =>
          { Nick => $opts{botnick},
            Username => $opts{botuser},
            Ircname  => $opts{botrlnm},
            Server   => $opts{server},
            Port     => $opts{port},
          }
    );
}

# The bot has successfully connected to a server.  Join a channel.
sub on_connect {
    my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
    my %opts = $BotCore->getopts();
    $BotCore->{kernel} = $kernel;
    $BotCore->emit_event('connect');
    $irc->yield( join => $opts{botchan} );
    print "Connected, going to background\n";
}

sub bot_reconnect {
    my $kernel = $_[KERNEL];
    $kernel->delay( connect  => 60 );
}

sub reload_mods {
    no warnings 'redefine';
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    $heap->{irc}->{modrefresh}->refresh();
    $kernel->sig_handled();
    use warnings;
}

$poe_kernel->run();
exit 0;
