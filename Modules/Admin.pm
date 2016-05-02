use strict;
use warnings;

package BotCore::Modules::Admin;
use Data::Dumper;

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub register_handlers {
    my ($self, $BotCore) = @_;
    $BotCore->register_handler('user_command !config', \&BotCore::Modules::Admin::config_option);
}

sub config_option {
    my ($self, $nick, $chanop, $target, $command, @arg) = @_;
    my $config_option = shift @arg;
    my $config_value = join ' ', @arg;
    my %new_opts = %{$self->{options}};
    $self->debug('Old: ' . Dumper(\%new_opts));
    $new_opts{$config_option} = $config_value;
    $self->debug('New: ' . Dumper(\%new_opts));
    $self->saveconfig(%new_opts);
    return 1;
}
1;