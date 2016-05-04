use strict;
use warnings;

package BotCore::Modules::Admin;
use Data::Dumper;
use Switch;

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub register_handlers {
    my ($self, $BotCore) = @_;
    $BotCore->register_handler('admin_notice', \&BotCore::Modules::Admin::admin_notice);
    $BotCore->register_handler('user_command_config', \&BotCore::Modules::Admin::config_option);
    $BotCore->register_handler('user_command_pending', \&BotCore::Modules::Admin::command_pending);
    $BotCore->register_handler('user_command_reload', \&BotCore::Modules::Admin::command_reload);
    $BotCore->register_handler('user_command_ok', \&BotCore::Modules::Admin::command_approve);
    $BotCore->register_handler('user_command_hide', \&BotCore::Modules::Admin::command_approve);
    $BotCore->register_handler('user_command_lock', \&BotCore::Modules::Admin::command_approve);
    $BotCore->register_handler('user_command_delete', \&BotCore::Modules::Admin::command_delete);
    $BotCore->register_handler('user_command_unlock', \&BotCore::Modules::Admin::command_approve);
}

sub admin_notice {
    my ($self, $message) = @_;
    my @chans = @{$self->{options}{irc}{channels}};
    for my $cn (0..$#chans) {
        my %channel = %{$chans[$cn]};
        $self->onotice($message, $channel{prefix}, $channel{name});
    }
}

sub command_delete {
    my ($self, $nick, $where, $command, $botadmin, $owner, @arg) = @_;
    my $victim = shift @arg;
    my $message = undef;
    if (!$botadmin) {
        $message = "I regret that I am unfortunately quite unable to allow that. Good day.";
    }
    else {
        $self->emit_event('reload_user', $victim);
        if (!defined $self->get_user($victim)) {
            $message = "Oh dear, I'm afraid I simply can't find that profile.";
        }
        else {
            my $fg = $self->get_color('variables');
            my $text = $self->get_color('text');
            $self->emit_event('admin_notice', "$fg$victim$text deleted by $fg$nick$text.");
            $self->emit_event('delete_user', $victim);
            map { $self->{IRC}->yield(mode => $_ => '-v' => $victim) } $self->my_channels();
            delete $self->{users}{lc $victim};
        }
    }
    if (defined $message) {
        $self->respond($message, $where, $nick);
    }
}

sub command_approve {
    my ($self, $nick, $where, $command, $botadmin, $owner, @arg) = @_;
    return unless $self->where_ok($where);
    my $victim = shift @arg;
    my $message = undef;
    if (!$botadmin) {
        $message = "I regret that I am unfortunately quite unable to allow that. Good day.";
    }
    else {
        $self->emit_event('reload_user', $victim);
        if (!defined $self->get_user($victim)) {
            $message = "Oh dear, I'm afraid I simply can't find that profile.";
        }
        else {
            my %user = $self->get_user($victim);
            my $state;
            switch ($command) {
                case "!ok" {
                    $state = 'approved';
                }
                case "!hide" {
                    $state = 'pending';
                }
                case "!lock" {
                    $state = 'locked';
                }
                case "!unlock" {
                    $state = 'approved';
                }
                else {
                    $state = 'pending';
                }
            }
            if ($user{state} eq $state) {
                $message = "Sorry, $victim is already $state.";
            }
            else {
                my $fg = $self->get_color('variables');
                my $text = $self->get_color('text');
                $self->emit_event('admin_notice', "$fg$victim$text state set to $state by $fg$nick$text.");
                $self->emit_event('modify_state', $victim, $state);
                if ($state eq 'approved') {
                    map { $self->{IRC}->yield(mode => $_ => '+v' => $victim) } $self->my_channels();
                }
                else {
                    map { $self->{IRC}->yield(mode => $_ => '-v' => $victim) } $self->my_channels();
                }
            }
        }
    }
    if (defined $message) {
        $self->respond($message, $where, $nick);
    }
}

sub config_option {
    my ($self, $nick, $where, $command, $botadmin, $owner, @arg) = @_;
    return unless $self->where_ok($where);
    return unless $owner;
    my $config_option = shift @arg;
    my $config_value = join ' ', @arg;
    my %new_opts = %{$self->{options}};
    $new_opts{$config_option} = $config_value;
    $self->saveconfig(%new_opts);
    return 1;
}

sub command_pending {
    my ($self, $nick, $where, $command, $botadmin, $owner, @arg) = @_;
    return unless $self->where_ok($where);
    return unless $owner || $botadmin;
    $self->emit_event('load_pending');
    my $message;
    if ($self->{pending_count} > 0) {
        my $fg = $self->get_color('variables');
        $message = "$self->{pending_count} users await approval. First $self->{options}{show_pending}: $fg" . join "$self->{colors}{normal}, $fg", @{$self->{pending}};
    }
    else {
        $message = "Checking ... no pending users found, good job.";
    }
    $self->respond($message, $where, $nick);
}

sub command_reload {
    my ($self, $nick, $where, $command, $botadmin, $owner, @arg) = @_;
    return unless $self->where_ok($where);
    return unless $owner;
    my $message = "Yes, effendi, it shall be done.";
    $self->respond($message, $where, $nick);
    kill URG => $$;
}
1;