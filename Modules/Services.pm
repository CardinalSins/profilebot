use strict;
use warnings;


package BotCore::Modules::Services;
use Data::Dumper;
use utf8;

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub register_handlers {
    my ($self, $BotCore) = @_;
    $BotCore->register_handler('connect', \&BotCore::Modules::Services::authenticate);
}

sub authenticate {
    my $self = shift;
    my $authcommand = $self->{options}{irc}{services}{auth_string};
    my %template_values = %{$self->{options}{irc}{services}{template_values}};
    my @tpl_vars = keys %template_values;
    for my $key (@tpl_vars) {
        $authcommand =~ s/<$key>/$self->{options}{irc}{services}{template_values}{$key}/;
    }
    $self->{IRC}->yield(privmsg => $self->{options}{irc}{services}{auth_command} => $authcommand);
    return 1;
}
1;