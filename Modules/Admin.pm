use strict;
use warnings;

package BotCore::Modules::Admin;
use Data::Dumper;
use Switch;
use utf8;

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub register_handlers {
    my ($self, $BotCore) = @_;
    $BotCore->register_handler('admin_notice', \&BotCore::Modules::Admin::admin_notice);
    $BotCore->register_handler('user_command_die', \&BotCore::Modules::Admin::command_perish);
    $BotCore->register_handler('user_command_config', \&BotCore::Modules::Admin::config_option);
    $BotCore->register_handler('user_command_confdel', \&BotCore::Modules::Admin::config_delete);
    $BotCore->register_handler('user_command_pending', \&BotCore::Modules::Admin::command_pending);
    $BotCore->register_handler('user_command_reload', \&BotCore::Modules::Admin::command_reload);
    $BotCore->register_handler('user_command_ok', \&BotCore::Modules::Admin::command_approve);
    $BotCore->register_handler('user_command_okay', \&BotCore::Modules::Admin::command_approve);
    $BotCore->register_handler('user_command_hide', \&BotCore::Modules::Admin::command_approve);
    $BotCore->register_handler('user_command_lock', \&BotCore::Modules::Admin::command_approve);
    $BotCore->register_handler('user_command_delete', \&BotCore::Modules::Admin::command_delete);
    $BotCore->register_handler('user_command_unlock', \&BotCore::Modules::Admin::command_approve);
    $BotCore->register_handler('user_command_message', \&BotCore::Modules::Admin::command_message);
    $BotCore->register_handler('user_command_nl', \&BotCore::Modules::Admin::add_language);
}

sub add_language {
    my ($self, $nick, $where, $command, $botadmin, $owner, @arg) = @_;
    return unless $owner or $botadmin;
    my $language = shift @arg;
    return if defined $self->{options}{languages}{$language};
    my %options = %{$self->{options}};
    my %blank = (enabled => 1);
    %{$options{languages}{$language}} = %blank;
    $self->saveconfig(%options);
}

sub command_perish {
    my ($self, $nick, $where, $command, $botadmin, $owner, @arg) = @_;
    return unless $owner or $botadmin;
    $self->{IRC}->yield(ctcp => $where => "ACTION salutes $nick.");
    $self->{IRC}->yield(shutdown => "Meh.");
}

sub admin_notice {
    my ($self, $message) = @_;
    my @chans = @{$self->{options}{irc}{channels}};
    for my $cn (0..$#chans) {
        my %channel = %{$chans[$cn]};
        $self->debug("Sending to $channel{helpers}$channel{name}: $message");
        $self->onotice($message, $channel{helpers}, $channel{name});
    }
}

sub command_message {
    my ($self, $nick, $where, $command, $botadmin, $owner, @arg) = @_;
    return unless $owner;
    my $message_key = shift @arg;
    my $message_text = join ' ', @arg;
    my %options = %{$self->{options}};
    my %language = %{$options{languages}{$self->{options}{language}}};
    $language{lc $message_key} = $message_text;
    %{$options{languages}{$self->{options}{language}}} = %language;
    $self->saveconfig(%options);
}

sub command_delete {
    my ($self, $nick, $where, $command, $botadmin, $owner, @arg) = @_;
    my $victim = shift @arg;
    my $message = undef;
    if (!$botadmin) {
        $message = $self->get_message('permission_denied');
    }
    else {
        $self->emit_event('reload_user', $victim);
        if (!defined $self->get_user($victim)) {
            $message = $self->get_message('404');
        }
        else {
            my $fg = $self->get_color('variables');
            my $text = $self->get_color('text');
            my %tpl_vars = (victim => $fg . $victim . $text,
                            nick => $fg . $nick . $text);
            my $message = $self->get_message('op_deleted_user', %tpl_vars);
            $self->debug($message);
            $self->emit_event('admin_notice', $message);
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
        $message = $self->get_message('permission_denied');
    }
    else {
        $self->emit_event('reload_user', $victim);
        if (!defined $self->get_user($victim)) {
            $message = $self->get_message('404');
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

sub config_delete {
    my ($self, $nick, $where, $command, $botadmin, $owner, @arg) = @_;
    return unless $self->where_ok($where);
    return unless $owner;
    my $config_option = shift @arg;
    return unless defined $self->{options}{$config_option};
    my %options = %{$self->{options}};
    delete $options{$config_option};
    $self->saveconfig(%options);
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
        $message = "There are $self->{pending_count} hopefuls seeking your approval. ";
        if ($self->{pending} > 15)  {
            $message .= "First $self->{options}{show_pending}: $fg";
        }
        $message .= join $self->get_color('normal') . ", $fg", @{$self->{pending}};
    }
    else {
        $message = $self->get_message('no_pending');
    }
    $self->respond($message, $where, $nick);
}

sub command_reload {
    my ($self, $nick, $where, $command, $botadmin, $owner, @arg) = @_;
    return unless $self->where_ok($where);
    return unless $owner;
    my $message = $self->get_message('sir_sammich');
    $self->respond($message, $where, $nick);
    kill URG => $$;
}
1;