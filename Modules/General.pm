use strict;
use warnings;

package BotCore::Modules::General;
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
    $BotCore->register_handler('user_command_info', \&BotCore::Modules::General::command_info);
    $BotCore->register_handler('user_command_rules', \&BotCore::Modules::General::command_rules);
    $BotCore->register_handler('user_command_edit', \&BotCore::Modules::General::command_edit);
    $BotCore->register_handler('user_command_profilecommands', \&BotCore::Modules::General::show_profile_commands);
    $BotCore->register_handler('user_command_opcommands', \&BotCore::Modules::General::show_op_commands);
    $BotCore->register_handler('user_command_commands', \&BotCore::Modules::General::show_commands);
    $BotCore->register_handler('user_command_colours', \&BotCore::Modules::General::show_colors);
    $BotCore->register_handler('user_command_colors', \&BotCore::Modules::General::show_colors);
    $BotCore->register_handler('user_command_stats', \&BotCore::Modules::General::show_stats);
    $BotCore->register_handler('module_load_general', \&BotCore::Modules::General::namespace);
}

sub namespace {
    my $self = shift;
    $self->debug("Registering namespace user for key !");
    $self->register_command_namespace('!', 'user');
}

sub show_stats {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    $self->emit_event('load_stats');
    my $fg = $self->get_color('variables');
    my $nr = $self->{colors}{normal};
    my $message = "I have been awake for $fg$self->{uptime}$nr seconds. ";
    $message .= "I currently know of $fg$self->{all_users}$nr users. $fg$self->{approved_users}$nr fully ";
    $message .= "approved, and $fg$self->{locked_users}$nr in solitary confinement. ";
    if ($self->{pending_users}) {
        $message .= "Of the remainder, $fg$self->{pending_users}$nr are patiently waiting for approval."
    }
    $self->respond($message, $where, $nick);
}

sub command_rules {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    my $message = "The rules for $self->{options}{botchan} can be found at $self->{options}{rules_url}";
    $self->respond($message, $where, $nick);
}

sub command_jeeves {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    my $message = "Yes, rather. A dreadful situation. I have summoned the gendarmes.";
    my $helptext = join ' ', @arg;
    $self->respond($message, $where, $nick);
    $message = "$nick is seeking assistance: $helptext";
    $self->emit_event('admin_notice', $message);
}

sub command_edit {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    my $fg = $self->get_color('variables');
    my $text = $self->get_color('text');
    my $message = "That command does not exist. Just update the value you want to update. Use $fg!profilecommands$text to find out how.";
    $self->respond($message, $where, $nick);
    return 1;
}

sub command_info {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    my $message = "I am $self->{version}{name} v$self->{version}{version}, written by $self->{version}{author}. My genome can be found at $self->{version}{homepage} and my blog at $self->{version}{blog}";
    $self->respond($message, $where, $nick);
    return 1;
}

sub show_colors {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    my $normal = $self->{colors}{normal} . 'normal' . $self->{colors}{normal};
    my $bold = $self->{colors}{bold} . 'bold' . $self->{colors}{normal};
    my $underline = $self->{colors}{underline} . 'underline' . $self->{colors}{normal};
    my $reverse = $self->{colors}{reverse} . 'reverse' . $self->{colors}{normal};
    my $italic = $self->{colors}{italic} . 'italic' . $self->{colors}{normal};
    my $fixed = $self->{colors}{fixed} . 'fixed' . $self->{colors}{normal};
    my $white = $self->{colors}{white} . 'white' . $self->{colors}{normal};
    my $black = $self->{colors}{reverse} . 'black' . $self->{colors}{normal};
    my $blue = $self->{colors}{blue} . 'blue' . $self->{colors}{normal};
    my $green = $self->{colors}{green} . 'green' . $self->{colors}{normal};
    my $red = $self->{colors}{red} . 'red' . $self->{colors}{normal};
    my $brown = $self->{colors}{brown} . 'brown' . $self->{colors}{normal};
    my $purple = $self->{colors}{purple} . 'purple' . $self->{colors}{normal};
    my $orange = $self->{colors}{orange} . 'orange' . $self->{colors}{normal};
    my $yellow = $self->{colors}{yellow} . 'yellow' . $self->{colors}{normal};
    my $teal = $self->{colors}{teal} . 'teal' . $self->{colors}{normal};
    my $pink = $self->{colors}{pink} . 'pink' . $self->{colors}{normal};
    my $grey = $self->{colors}{grey} . 'grey' . $self->{colors}{normal};
    my $light_green = $self->{colors}{light_green} . 'light_green' . $self->{colors}{normal};
    my $light_blue = $self->{colors}{light_blue} . 'light_blue' . $self->{colors}{normal};
    my $light_grey = $self->{colors}{light_grey} . 'light_grey' . $self->{colors}{normal};
    my $light_cyan = $self->{colors}{light_cyan} . 'light_cyan' . $self->{colors}{normal}; #
    $self->{IRC}->yield(notice => $nick => "$normal        $bold             $underline");
    $self->{IRC}->yield(notice => $nick => "$reverse       $italic           $fixed");
    $self->{IRC}->yield(notice => $nick => "$black         $grey      $light_grey    $white");
    $self->{IRC}->yield(notice => $nick => "$light_cyan    $teal      $light_blue    $blue");
    $self->{IRC}->yield(notice => $nick => "$yellow        $orange    $red           $brown");
    $self->{IRC}->yield(notice => $nick => "$purple        $pink      $light_green   $green");
}

sub show_profile_commands {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    my $fg = $self->get_color('variables');
    my $text = $self->get_color('text');
    $self->{IRC}->yield(notice => $nick => "====== Profile Commands supported by PoCoProfileBot v1.0.0 ======");
    $self->{IRC}->yield(notice => $nick => "$fg!restrict$text:        Toggle restricting your profile to users with profiles only.");
    $self->{IRC}->yield(notice => $nick => "$fg!setup$text:           Start the profile creation process.");
    $self->{IRC}->yield(notice => $nick => "$fg!age$text:             Set your age. Initiates the next step, if creating a profile.");
    $self->{IRC}->yield(notice => $nick => "$fg!gender$text:          Set your gender identity. Initiates the next step, if creating a profile.");
    $self->{IRC}->yield(notice => $nick => "$fg!orientation$text:     Set your orientation. Initiates the next step, if creating a profile.");
    $self->{IRC}->yield(notice => $nick => "$fg!role$text:            Set your role. Initiates the next step, if creating a profile.");
    $self->{IRC}->yield(notice => $nick => "$fg!location$text:        Set your location. Initiates the next step, if creating a profile.");
    $self->{IRC}->yield(notice => $nick => "$fg!kinks$text:           Set your kinks. Initiates the next step, if creating a profile.");
    $self->{IRC}->yield(notice => $nick => "$fg!limits$text:          Set your limits. Initiates the next step, if creating a profile.");
    $self->{IRC}->yield(notice => $nick => "$fg!description$text:     Set your description. Initiates the next step, if creating a profile.");
}

sub show_commands {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    my $fg = $self->get_color('base');
    my $og = $self->get_color('op');
    my $vg = $self->get_color('variables');
    my $text = $self->get_color('text');
    $self->{IRC}->yield(notice => $nick => "====== General Commands supported by PoCoProfileBot v1.0.0 ======");
    $self->{IRC}->yield(notice => $nick => "$fg!commands$text:          Show this help text.");
    $self->{IRC}->yield(notice => $nick => "$fg!info$text:              Show information about the bot.");
    $self->{IRC}->yield(notice => $nick => "$fg!colors$text:            Show which color names the bot supports for normal people.");
    $self->{IRC}->yield(notice => $nick => "$fg!colours$text:           Show which colour names the bot supports for English people.");
    $self->{IRC}->yield(notice => $nick => "$fg!rules$text:             Show the channel rules.");
    $self->{IRC}->yield(notice => $nick => "$fg!jeeves$text:            Alert the channel ops that you need assistance.");
    $self->{IRC}->yield(notice => $nick => "$vg!profilecommands$text:   Show the profile-related commands.");
    if ($chanop || $owner) {
        $self->{IRC}->yield(notice => $nick => "$og!opcommands$text:        Show only the op commands.");
    }
}

sub show_op_commands {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    return unless $chanop || $owner;
    my $fg = $self->get_color('base');
    my $og = $self->get_color('op');
    my $text = $self->get_color('text');
    $self->{IRC}->yield(notice => $nick => "====== Admin Commands supported by PoCoProfileBot v1.0.0 ======");
    $self->{IRC}->yield(notice => $nick => "$og!lock$text:            Lock a user's profile.");
    $self->{IRC}->yield(notice => $nick => "$og!delete$text:          Delete a user's profile. $self->{colors}{bold}This is immediate and irreversible$text.");
    $self->{IRC}->yield(notice => $nick => "$og!ok$text:              Approve a user's profile. Approved profiles can be viewed, pending will only show teasers.");
    $self->{IRC}->yield(notice => $nick => "$og!okay$text:            Approve a user's profile. Approved profiles can be viewed, pending will only show teasers.");
    $self->{IRC}->yield(notice => $nick => "$og!hide$text:            Set a user's profile to pending.");
}
1;