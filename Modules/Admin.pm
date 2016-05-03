use strict;
use warnings;

package BotCore::Modules::Admin;
use Data::Dumper;
use IRC::Utils qw(NORMAL BOLD UNDERLINE REVERSE ITALIC FIXED WHITE BLACK BLUE GREEN RED BROWN PURPLE ORANGE YELLOW LIGHT_GREEN TEAL LIGHT_CYAN LIGHT_BLUE PINK GREY LIGHT_GREY);

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub register_handlers {
    my ($self, $BotCore) = @_;
    $BotCore->register_handler('user_command_config', \&BotCore::Modules::Admin::config_option);
    $BotCore->register_handler('user_command_pending', \&BotCore::Modules::Admin::command_pending);
    $BotCore->register_handler('user_command_reload', \&BotCore::Modules::Admin::command_reload);
}

sub config_option {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    return unless $owner;
    my $config_option = shift @arg;
    my $config_value = join ' ', @arg;
    my %new_opts = %{$self->{options}};
    $new_opts{$config_option} = $config_value;
    $self->saveconfig(%new_opts);
    return 1;
}

sub command_pending {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    return unless $owner || $chanop;
    $self->emit_event('load_pending');
    my $message = "Users pending approval: $self->{colors}{light_blue}" . join "$self->{colors}{normal}, $self->{colors}{light_blue}", @{$self->{pending}};
    $self->respond($message, $where, $nick);
}

sub command_reload {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    return unless $owner;
    my $message = "Yes, effendi, it shall be done.";
    $self->respond($message, $where, $nick);
    kill URG => $$;
}
1;