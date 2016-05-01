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
    $BotCore->register_handler('irc_command !config_option', \&BotCore::Modules::Admin::config_option);
}

sub config_option {
    my ($self, %options) = @_;
    return 1;
    $self->debug(Dumper(\%options));
    my @arg = split ' ', $options{what};
    my $command = lc shift @arg;
    my $config_option = shift @arg;
    my $config_value = join ' ', @arg;
    my %new_opts = %{$self->{options}};
    $new_opts{$config_option} = $config_value;
    %{$self->{options}} = %new_opts;
    my %option = ( $config_option => $config_value );
    $self->saveconfig();
    # $self->debug(Dumper(\%option));
    return 1;
}
1;