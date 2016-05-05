#!/usr/bin/env perl

## REQUIRES:
# POE::Component::IRC   libpoe-component-irc-perl
# Switch                libswitch-perl
# JSON                  libyaml-perl
# Module::Refresh       libmodule-refresh-perl
# Proc::Fork            libproc-fork-perl
# DBI                   libdbd-mysql-perl

use warnings;
use strict;
use utf8;
use Data::Dumper;
$Data::Dumper::Indent = 1;

use POE qw(Component::IRC::State);
use BotCore;
use Module::Refresh;
use Proc::Fork;


run_fork {
    child {
        our ($irc) = POE::Component::IRC::State->spawn(Flood => 1, UseSSL => 1);
        our $BotCore = new BotCore($irc);
        sub bot_start {
            # The bot session has started. Select a nickname. Connect to a server.
            my $kernel  = $_[KERNEL];
            my $heap    = $_[HEAP];
            my $session = $_[SESSION];
            our $BotCore;
            ($BotCore->{kernel}, $BotCore->{heap}, $BotCore->{session}) = ($kernel, $heap, $session);
            my %opts = $BotCore->getopts();
            $kernel->sig(URG => 'signal');
            $kernel->delay( heartbeat => $opts{self_clock} );
            $irc->yield( register => "all" );

            $irc->yield( connect =>
                  { Nick => $opts{irc}{nick},
                    Username => $opts{irc}{user},
                    Ircname  => $opts{irc}{real},
                    Server   => $opts{irc}{server},
                    Port     => $opts{irc}{port},
                  }
            );
        }

        sub terminate {
            $BotCore->debug('Terminating.');
            $poe_kernel->stop();
            exit 0;
        }

        sub bot_do_autoping {
            my ($kernel, $heap) = @_[KERNEL, HEAP];
            $kernel->post(poco_irc => userhost => "my-nickname")
                unless $heap->{seen_traffic};
            $heap->{seen_traffic} = 0;
            $kernel->delay(autoping => 150);
        }

        # The bot has successfully connected to a server.  Join a channel.
        sub on_connect {
            my ( $kernel, $heap ) = @_[ KERNEL, HEAP ];
            our $BotCore;
            my %opts = $BotCore->getopts();
            $BotCore->emit_event('connect');
            my @channels = @{$opts{irc}{channels}};
            for my $cn (0..$#channels) {
                my %channel = %{$channels[$cn]};
                if (defined $channel{key}) {
                    $irc->yield( join => $channel{name} => $channel{key} );
                }
                else {
                    $irc->yield( join => $channel{name} );
                }
            }
            $BotCore->debug("Connected, going to background");
        }

        sub bot_reconnect {
            my $kernel = $_[KERNEL];
            $kernel->delay( autoping  => undef );
            $kernel->delay( connect  => 10 );
        }

        sub reload_mods {
            no warnings 'redefine';
            my ($kernel, $heap) = @_[KERNEL, HEAP];
            $heap->{irc}->{modrefresh}->refresh();
            $kernel->sig_handled();
            use warnings;
        }
        my %version = ( version => '1.0.0',
                        name => 'PoCoProfileBot',
                        author => 'CardinalSins',
                        homepage => 'https://github.com/CardinalSins/profilebot',
                        blog => 'http://rphaven-cuff-link.tumblr.com/' );
        $BotCore->versions(%version);

        $irc->{modrefresh} = Module::Refresh->new();

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
        $poe_kernel->run();
    }
    parent {
        my $child_pid = shift;
        # waitpid $child_pid, 0;
        open(my $pidfile,">.bot.pid");
        print $pidfile $child_pid . "\n";
        close $pidfile;
    }
    retry {
        my $attempts = shift;
        # what to do if fork() fails:
        # return true to try again, false to abort
        return if $attempts > 5;
        sleep 1, return 1;
    }
    error {
        die "Couldn't fork: $!\n";
    }
};
