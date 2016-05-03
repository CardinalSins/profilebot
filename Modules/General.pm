use strict;
use warnings;

package BotCore::Modules::General;
use Data::Dumper;

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
    $BotCore->register_handler('user_command_profilecommands', \&BotCore::Modules::General::show_profile_commands);
    $BotCore->register_handler('user_command_opcommands', \&BotCore::Modules::General::show_op_commands);
    $BotCore->register_handler('user_command_commands', \&BotCore::Modules::General::show_commands);
    $BotCore->register_handler('user_command_colors', \&BotCore::Modules::General::show_colors);
}

sub command_edit {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    my $fg = $self->{colors}{$self->{options}{variable_color}};
    my $text = $self->{colors}{$self->{options}{text_color}};
    my $message = "That command does not exist. Just update the value you want to update. Use $fg!profilecommands$text to find out how.";
    $self->respond($message, $where, $nick);
    return 1;
}

sub command_info {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    my $message = $self->{options}{info_string};
    $self->respond($message, $where, $nick);
    return 1;
}

sub show_colors {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
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
    #NORMAL BOLD UNDERLINE REVERSE ITALIC FIXED WHITE BLACK BLUE GREEN RED BROWN PURPLE ORANGE YELLOW LIGHT_GREEN TEAL LIGHT_CYAN LIGHT_BLUE PINK GREY LIGHT_GREY
    $self->{IRC}->yield(notice => $nick => "$normal        $bold             $underline");
    $self->{IRC}->yield(notice => $nick => "$reverse       $italic           $fixed");
    $self->{IRC}->yield(notice => $nick => "$black         $grey      $light_grey    $white");
    $self->{IRC}->yield(notice => $nick => "$light_cyan    $teal      $light_blue    $blue");
    $self->{IRC}->yield(notice => $nick => "$yellow        $orange    $red           $brown");
    $self->{IRC}->yield(notice => $nick => "$purple        $pink      $light_green   $green");
}

sub show_profile_commands {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    my $fg = $self->{colors}{$self->{options}{variable_color}};
    my $text = $self->{colors}{$self->{options}{text_color}};
    $self->{IRC}->yield(notice => $nick => "====== Profile Commands supported by PoCoProfileBot v1.0.0 ======");
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
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    my $fg = $self->{colors}{$self->{options}{base_color}};
    my $og = $self->{colors}{$self->{options}{op_color}};
    my $text = $self->{colors}{$self->{options}{text_color}};
    $self->{IRC}->yield(notice => $nick => "====== General Commands supported by PoCoProfileBot v1.0.0 ======");
    $self->{IRC}->yield(notice => $nick => "$fg!commands$text:        Show this help text.");
    $self->{IRC}->yield(notice => $nick => "$fg!info$text:            Show information about the bot.");
    $self->{IRC}->yield(notice => $nick => "$fg!rules$text:           Show the channel rules.");
    $self->{IRC}->yield(notice => $nick => "$fg!jeeves$text:          Alert the channel ops that you need assistance.");
    $self->{IRC}->yield(notice => $nick => "$fg!restrict$text:        Restrict viewing your profile to users with profiles only.");
    $self->{IRC}->yield(notice => $nick => "$fg!unrestrict$text:      Remove the restriction from your profile.");
    $self->{IRC}->yield(notice => $nick => "$fg!profilecommands$text: Show the profile-related commands.");
    if ($chanop || $owner) {
        $self->{IRC}->yield(notice => $nick => "$og!opcommands$text:      Show only the op commands.");
    }
}

sub show_op_commands {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    return unless $chanop || $owner;
    my $fg = $self->{colors}{$self->{options}{base_color}};
    my $og = $self->{colors}{$self->{options}{op_color}};
    my $text = $self->{colors}{$self->{options}{text_color}};
    $self->{IRC}->yield(notice => $nick => "====== Admin Commands supported by PoCoProfileBot v1.0.0 ======");
    $self->{IRC}->yield(notice => $nick => "$og!lock$text:            Lock a user's profile.");
    $self->{IRC}->yield(notice => $nick => "$og!delete$text:          Delete a user's profile. $self->{colors}{bold}This is immediate and irreversible$text.");
    $self->{IRC}->yield(notice => $nick => "$og!approve$text:         Approve a user's profile. Approved profiles can be viewed, pending will only show teasers.");
    $self->{IRC}->yield(notice => $nick => "$og!unapprove$text:       Set a user's profile to pending.");
}
1;