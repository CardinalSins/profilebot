use strict;
use warnings;

package BotCore::Modules::Profiles;
use Data::Dumper;
use Switch;
use IRC::Utils qw(NORMAL BOLD UNDERLINE REVERSE ITALIC FIXED WHITE BLACK BLUE GREEN RED BROWN PURPLE ORANGE YELLOW LIGHT_GREEN TEAL LIGHT_CYAN LIGHT_BLUE PINK GREY LIGHT_GREY);

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub register_handlers {
    my ($self, $BotCore) = @_;
    $BotCore->register_handler('modify_state', \&BotCore::Modules::Profiles::set_state);
    $BotCore->register_handler('nick_change', \&BotCore::Modules::Profiles::check_new_nick);
    $BotCore->register_handler('error_message', \&BotCore::Modules::Profiles::error_message);
    $BotCore->register_handler('profile_found', \&BotCore::Modules::Profiles::show_teaser);
    $BotCore->register_handler('view_command', \&BotCore::Modules::Profiles::view_command);
    $BotCore->register_handler('user_created', \&BotCore::Modules::Profiles::start_interview);
    $BotCore->register_handler('user_restricted', \&BotCore::Modules::Profiles::restricted);
    $BotCore->register_handler('user_unrestricted', \&BotCore::Modules::Profiles::unrestricted);
    $BotCore->register_handler('command_restrict', \&BotCore::Modules::Profiles::restrict);
    $BotCore->register_handler('command_unrestrict', \&BotCore::Modules::Profiles::unrestrict);
    $BotCore->register_handler('command_age', \&BotCore::Modules::Profiles::enter_age);
    $BotCore->register_handler('command_gender', \&BotCore::Modules::Profiles::enter_gender);
    $BotCore->register_handler('command_orientation', \&BotCore::Modules::Profiles::enter_orientation);
    $BotCore->register_handler('command_role', \&BotCore::Modules::Profiles::enter_role);
    $BotCore->register_handler('command_location', \&BotCore::Modules::Profiles::enter_location);
    $BotCore->register_handler('command_kinks', \&BotCore::Modules::Profiles::enter_kinks);
    $BotCore->register_handler('command_limits', \&BotCore::Modules::Profiles::enter_limits);
    $BotCore->register_handler('command_description', \&BotCore::Modules::Profiles::enter_description);
    $BotCore->register_handler('command_setup', \&BotCore::Modules::Profiles::command_setup);
    $BotCore->register_handler('already_restricted', \&BotCore::Modules::Profiles::already_restricted);
    $BotCore->register_handler('already_unrestricted', \&BotCore::Modules::Profiles::already_unrestricted);
}

sub set_state {
    my ($self, $nick, $state) = @_;
    return unless exists $self->{users}{$nick};
    my %victim = %{$self->{users}{$nick}};
    $victim{state} = $state;
    %{$self->{users}{$nick}} = %victim;
    $self->emit_event('user_edited', $nick);
}

sub check_new_nick {
    my ($self, $old, $new) = @_;
    if (exists $self->{users}{$old}) {
        return if exists $self->{users}{$new};
        $self->{IRC}->yield(mode => $self->{options}{botchan}, '-v', $new);
    }
    else {
        return unless exists $self->{users}{$new};
        $self->{IRC}->yield(mode => $self->{options}{botchan}, '+v', $new);
    }
}

sub show_teaser {
    my ($self, $name) = @_;
    return unless exists $self->{users}{$name};
    return unless exists $self->{users}{$name}{state};
    return unless ($self->{users}{$name}{state} eq 'approved' || $self->{users}{$name}{state} eq 'pending'); 
    my %user = %{$self->{users}{$name}};
    my $message = "@{[LIGHT_GREY]}Teaser profile for @{[LIGHT_BLUE]}$name@{[NORMAL]}: @{[LIGHT_GREY]}Age@{[NORMAL]}: ";
    $message .= "@{[LIGHT_BLUE]}$user{age}@{[LIGHT_GREY]} Gender Identity@{[NORMAL]}: @{[LIGHT_BLUE]}$user{gender} ";
    $message .= "@{[LIGHT_GREY]}Orientation@{[NORMAL]}: @{[LIGHT_BLUE]}$user{orientation} @{[LIGHT_GREY]}Role@{[NORMAL]}: ";
    $message .= "@{[LIGHT_BLUE]}$user{role}@{[LIGHT_GREY]} To see the rest, use @{[BOLD]}@{[LIGHT_BLUE]}!view $name@{[NORMAL]}.";
    $self->debug('The message: ' . $message);
    $self->{IRC}->yield(privmsg => $self->{options}{botchan} => $message);
    $self->{IRC}->yield(mode => "$self->{options}{botchan} +v $name");
}

sub error_message {
    my $self = shift;
    my $channel_view = shift;
    my $message = shift;
    my $nick = undef;
    if (!$channel_view) {
        $nick = shift;
    }
    if (!$channel_view) {
        $self->{IRC}->yield(privmsg => $nick => $message);
    }
    else {
        $self->{IRC}->yield(privmsg => $self->{options}{botchan} => $message);
    }
}

sub restrict {
    my ($self, $nick, $target) = @_;
    return unless exists $self->{users}{$nick};
    my %user = %{$self->{users}{$nick}};
    if ($user{restricted} == 1 || $user{restricted} eq '1') {
        $self->emit_event('already_restricted', $nick, $target);
        return 1;
    }
    $user{restricted} = 1;
    %{$self->{users}{$nick}} = %user;
    $self->emit_event('user_edited', $nick);
    $self->emit_event('user_restricted', $nick, $target);
}

sub restricted {
    my ($self, $nick, $target) = @_;
    my $channel_view;
    if ($target eq $self->{IRC}{INFO}{RealNick}) {
        $channel_view = 0;
    }
    else {
        $channel_view = 1;
    }
    my $message = sprintf('Ok, %s. Your profile has been restricted to users with profiles only.', $nick);
    $self->emit_event('error_message', $channel_view, $message, $nick);
}

sub already_restricted {
    my ($self, $nick, $target) = @_;
    my $channel_view;
    if ($target eq $self->{IRC}{INFO}{RealNick}) {
        $channel_view = 0;
    }
    else {
        $channel_view = 1;
    }
    my $message = sprintf('Your profile has already been restricted, %s.', $nick);
    $self->emit_event('error_message', $channel_view, $message, $nick);
}

sub already_unrestricted {
    my ($self, $nick, $target) = @_;
    my $channel_view;
    if ($target eq $self->{IRC}{INFO}{RealNick}) {
        $channel_view = 0;
    }
    else {
        $channel_view = 1;
    }
    my $message = sprintf('Your profile is already available to anyone, %s.', $nick);
    $self->emit_event('error_message', $channel_view, $message, $nick);
}

sub unrestrict {
    my ($self, $nick, $target) = @_;
    return unless exists $self->{users}{$nick};
    my %user = %{$self->{users}{$nick}};
    if ($user{restricted} == 0 || $user{restricted} eq '0') {
        $self->emit_event('already_unrestricted', $nick, $target);
        return 1;
    }
    $user{restricted} = 0;
    %{$self->{users}{$nick}} = %user;
    $self->emit_event('user_edited', $nick);
    $self->emit_event('user_unrestricted', $nick, $target);
}

sub unrestricted {
    my ($self, $nick, $target) = @_;
    my $channel_view;
    if ($target eq $self->{IRC}{INFO}{RealNick}) {
        $channel_view = 0;
    }
    else {
        $channel_view = 1;
    }
    my $message = sprintf('Ok, %s. Your profile has been made available to all users.', $nick);
    $self->emit_event('error_message', $channel_view, $message, $nick);
}

sub view_command {
    my ($self, $who, $target, @arg) = @_;
    my $profile = $arg[0];
    $self->emit_event('reload_user', $profile);
    my ($nick, $userhost) = split /!/, $who;
    my $channel_view;
    my $message;
    if ($target eq $self->{IRC}{INFO}{RealNick}) {
        $channel_view = 0;
    }
    else {
        $channel_view = 1;
    }
    my %profiles = %{$self->{users}};
    if (!exists $profiles{$profile}) {
        $message = sprintf('Sorry, %s, no profile found under %s. Try a different name.', $nick, $profile);
        $self->emit_event('error_message', $channel_view, $message, $nick);
        return 1;
    }
    else {
        my %user = %{$self->{users}{$profile}};
        my $possessive = (lc(substr $profile, -1) eq 's' ? $profile . "'" : $profile . "'s" );
        my $state = $user{state};
        if ($state ne 'approved') {
            my $message;
            switch ($state) {
                case "pending" {
                    $message = sprintf('Sorry, %s. %s profile is pending approval. Please try again later.', $nick, $possessive);
                }
                case "locked" {
                    $message = sprintf('Sorry, %s. %s profile has been locked. Please try again later.', $nick, $possessive);
                }
                else {
                    $message = sprintf('Sorry, %s. %s profile is not available yet. Please try again later.', $nick, $possessive);
                }
            }
            $self->emit_event('error_message', $channel_view, $message, $nick);
            return 1;
        }
        if ($user{restricted} && !exists($self->{users}{$nick})) {
            my $possessive = (lc(substr $profile, -1) eq 's' ? $profile . "'" : $profile . "'s" );
            $message = sprintf('Sorry, %s. %s profile has been restricted to users with profiles only. Create a profile and try again.', $nick, $possessive);
            $self->emit_event('error_message', $channel_view, $message, $nick);
            return 1;
        }
        my $message = "@{[LIGHT_GREY]}Roleplay profile for @{[LIGHT_BLUE]}$profile@{[NORMAL]}: @{[LIGHT_GREY]}Age@{[NORMAL]}: ";
        $message .= "@{[LIGHT_BLUE]}$user{age}@{[LIGHT_GREY]} Gender Identity@{[NORMAL]}: @{[LIGHT_BLUE]}$user{gender} ";
        $message .= "@{[LIGHT_GREY]}Orientation@{[NORMAL]}: @{[LIGHT_BLUE]}$user{orientation} @{[LIGHT_GREY]}Preferred Role@{[NORMAL]}: ";
        $message .= "@{[LIGHT_BLUE]}$user{role}@{[LIGHT_GREY]} Location@{[NORMAL]}: @{[LIGHT_BLUE]}$user{location} ";
        $self->{IRC}->yield(notice => $nick => $message);
        $self->{IRC}->yield(notice => $nick => sprintf('Kinks: %s', $user{kinks}));
        $self->{IRC}->yield(notice => $nick => sprintf('Limits: %s', $user{limits}));
        $self->{IRC}->yield(notice => $nick => sprintf('Description: %s', $user{description}));
    }
    return 1;
}

sub start_interview {
    my ($self, $nick) = @_;
    $self->{IRC}->yield(privmsg => $nick => "Welcome to the PoCoProfileBot 1.0.0 interrogation process.");
    $self->{IRC}->yield(privmsg => $nick => "Note that all responses will be limited to 500 characters.");
    $self->{IRC}->yield(privmsg => $nick => "Please begin by entering your age using the command !age, e.g. !age 20 or !age Older Than The Universe.");
}

sub enter_age {
    my ($self, $nick, $age) = @_;
    return unless exists $self->{users}{$nick};
    my %user = %{$self->{users}{$nick}};
    $user{age} = $age;
    my $response = sprintf('Thank you. Your age has been set to %s. ', $age);
    if ($user{state} eq 'new') {
        $response .= 'Now enter your gender identity using !gender. ';
        $response .= 'This can be as basic or elaborate as you like, e.g. ';
        $response .= '!gender XX or !gender The Manliest Man That Ever Manned.';
        $user{state} = 'aged';
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    %{$self->{users}{$nick}} = %user;
    $self->emit_event('user_edited', $nick);
}

sub enter_gender {
    my ($self, $nick, $gender) = @_;
    return unless exists $self->{users}{$nick};
    my %user = %{$self->{users}{$nick}};
    $user{gender} = $gender;
    my $response = sprintf('Thank you. Your gender identity has been set to %s. ', $gender);
    if ($user{state} eq 'aged') {
        $response .= 'Now enter your orientation using !orientation. ';
        $response .= 'For example !orientation lesbian or !orientation I only play with left-handed redheaded men between 35 and 37 years old.';
        $user{state} = 'gendered';
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    %{$self->{users}{$nick}} = %user;
    $self->emit_event('user_edited', $nick);
}

sub enter_orientation {
    my ($self, $nick, $orientation) = @_;
    return unless exists $self->{users}{$nick};
    my %user = %{$self->{users}{$nick}};
    $user{orientation} = $orientation;
    my $response = sprintf('Thank you. Your orientation has been set to %s. ', $orientation);
    if ($user{state} eq 'gendered') {
        $response .= 'Now enter your limits using !limits. ';
        $response .= 'For example !limits pain or !limits People who misspell HUMOUR.';
        $user{state} = 'oriented';
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    %{$self->{users}{$nick}} = %user;
    $self->emit_event('user_edited', $nick);
}

sub enter_limits {
    my ($self, $nick, $limits) = @_;
    return unless exists $self->{users}{$nick};
    my %user = %{$self->{users}{$nick}};
    $user{limits} = $limits;
    my $response = sprintf('Thank you. Your limits have been set to %s. ', $limits);
    if ($user{state} eq 'oriented') {
        $response .= 'Now enter your kinks using !kinks. ';
        $response .= 'For example !kinks spanking or !kinks People who can spell HUMOUR, COLOUR, and HONOUR correctly.';
        $user{state} = 'limited';
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    %{$self->{users}{$nick}} = %user;
    $self->emit_event('user_edited', $nick);
}

sub enter_kinks {
    my ($self, $nick, $kinks) = @_;
    return unless exists $self->{users}{$nick};
    my %user = %{$self->{users}{$nick}};
    $user{kinks} = $kinks;
    my $response = sprintf('Thank you. Your kinks have been set to %s. ', $kinks);
    if ($user{state} eq 'limited') {
        $response .= 'Now enter your preferred role using !role. ';
        $response .= 'This can be what role you prefer within BDSM; e.g. !role top, or !role masochist. ';
        $response .= 'Alternatively, you can list the type of character you tend to roleplay, e.g. !role Roman legionnaire or !role Comic book superhero. ';
        $user{state} = 'kinked';
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    %{$self->{users}{$nick}} = %user;
    $self->emit_event('user_edited', $nick);
}

sub enter_role {
    my ($self, $nick, $role) = @_;
    return unless exists $self->{users}{$nick};
    my %user = %{$self->{users}{$nick}};
    $user{role} = $role;
    my $response = sprintf('Thank you. Your role has been set to %s.', $role);
    if ($user{state} eq 'kinked') {
        $response .= ' Now enter a location using !location. ';
        $response .= 'You can use actual locations, like London or Seattle. You can use fictional locations, like Minas Tirith or Draenor. ';
        $response .= 'You can even use conceptual locations, like In a State of Confusion.';
        $user{state} = 'roled';
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    %{$self->{users}{$nick}} = %user;
    $self->emit_event('user_edited', $nick);
}

sub enter_location {
    my ($self, $nick, $location) = @_;
    return unless exists $self->{users}{$nick};
    my %user = %{$self->{users}{$nick}};
    $user{location} = $location;
    my $response = sprintf('Thank you. Your location has been set to %s.', $location);
    if ($user{state} eq 'roled') {
        $response .= ' Now describe yourself using !description. ';
        $response .= 'This is a free-form field and you can enter as much or as little as you like.';
        $user{state} = 'located';
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    %{$self->{users}{$nick}} = %user;
    $self->emit_event('user_edited', $nick);
}

sub enter_description {
    my ($self, $nick, $description) = @_;
    return unless exists $self->{users}{$nick};
    my %user = %{$self->{users}{$nick}};
    $user{description} = $description;
    my $response = sprintf('Thank you. Your description has been set to %s.', $description);
    if ($user{state} eq 'located') {
        $user{state} = 'pending';
        $response .= " We're all done here. Happy perving!";
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    %{$self->{users}{$nick}} = %user;
    $self->emit_event('user_edited', $nick);
    my $message = sprintf('%s has created a profile for your viewing pleasure!', $nick);
    $self->{IRC}->yield(privmsg => $self->{options}{botchan} => $message);
    $self->emit_event('profile_found', $nick);
}
1;