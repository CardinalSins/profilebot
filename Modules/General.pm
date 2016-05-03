use strict;
use warnings;

package BotCore::Modules::General;
use IRC::Utils qw(NORMAL BOLD UNDERLINE REVERSE ITALIC FIXED WHITE BLACK BLUE GREEN RED BROWN PURPLE ORANGE YELLOW LIGHT_GREEN TEAL LIGHT_CYAN LIGHT_BLUE PINK GREY LIGHT_GREY);

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub register_handlers {
    my ($self, $BotCore) = @_;
    $BotCore->register_handler('user_command_info', \&BotCore::Modules::General::command_info);
    $BotCore->register_handler('user_command_edit', \&BotCore::Modules::General::command_edit);
}

sub command_edit {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    my $message = "That command does not exist. Just update the value you want to update. Use @{[LIGHT_BLUE]}!profilecommands@{[NORMAL]} to find out how.";
    $self->respond($message, $where, $nick);
    return 1;
}

sub command_info {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    my $message = $self->{options}{info_string};
    $self->respond($message, $where, $nick);
    return 1;
}
1;