use strict;
use warnings;

package BotCore::Modules::Profiles;
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
    $BotCore->register_handler('modify_state', \&BotCore::Modules::Profiles::set_state);
    $BotCore->register_handler('nick_change', \&BotCore::Modules::Profiles::check_new_nick);
    $BotCore->register_handler('profile_found', \&BotCore::Modules::Profiles::show_teaser);
    $BotCore->register_handler('user_created', \&BotCore::Modules::Profiles::start_interview);
    $BotCore->register_handler('user_command_view', \&BotCore::Modules::Profiles::view_command);
    $BotCore->register_handler('user_command_restrict', \&BotCore::Modules::Profiles::restrict);
    $BotCore->register_handler('user_command_age', \&BotCore::Modules::Profiles::enter_age);
    $BotCore->register_handler('user_command_gender', \&BotCore::Modules::Profiles::enter_gender);
    $BotCore->register_handler('user_command_orientation', \&BotCore::Modules::Profiles::enter_orientation);
    $BotCore->register_handler('user_command_role', \&BotCore::Modules::Profiles::enter_role);
    $BotCore->register_handler('user_command_location', \&BotCore::Modules::Profiles::enter_location);
    $BotCore->register_handler('user_command_kinks', \&BotCore::Modules::Profiles::enter_kinks);
    $BotCore->register_handler('user_command_limits', \&BotCore::Modules::Profiles::enter_limits);
    $BotCore->register_handler('user_command_description', \&BotCore::Modules::Profiles::enter_description);
    $BotCore->register_handler('user_command_setup', \&BotCore::Modules::Profiles::command_setup);
}

sub set_state {
    my ($self, $nick, $state) = @_;
    return unless defined $self->get_user($nick);
    my %victim = $self->get_user($nick);
    $victim{state} = $state;
    $self->save_user($nick, %victim);
    $self->emit_event('user_edited', $nick);
}

sub check_new_nick {
    my ($self, $old, $new) = @_;
    if (defined $self->get_user($old)) {
        return if defined $self->get_user($new);
        return unless $self->{users}{lc $new}{state} eq 'approved';
        map { $self->{IRC}->yield(mode => $_ => '-v' => $new) } $self->my_channels();
    }
    else {
        return unless defined $self->get_user($new);
        return unless $self->{users}{lc $new}{state} eq 'approved';
        map { $self->{IRC}->yield(mode => $_ => '+v' => $new) } $self->my_channels();
    }
}

sub show_teaser {
    my ($self, $nick) = @_;
    return unless defined $self->get_user($nick);
    my %user = $self->get_user($nick);
    return unless exists $user{state};
    return unless ($user{state} eq 'approved' || $user{state} eq 'pending');
    my $fg = $self->get_color('variables');
    my $text = $self->get_color('text');
    my $message = $text . "Teaser profile for $fg$nick$text: Age: $fg$user{age}$text ";
    $message .= "Gender Identity: $fg$user{gender}$text ";
    $message .= "Orientation: $fg$user{orientation}$text ";
    $message .= "Role: $fg$user{role}$text ";
    $message .= "To see the rest, use $self->{colors}{bold}$fg!view $nick$text.";
    map { $self->{IRC}->yield(privmsg => $_ => $message) } $self->teaser_channels();
    map { $self->{IRC}->yield(mode => $_ => '+v' => $nick) } $self->my_channels();
}

sub restrict {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    return unless defined $self->get_user($nick);
    my %user = $self->get_user($nick);
    my $message;
    if ($user{restricted} == 1 || $user{restricted} eq '1') {
        $message = sprintf('Ok, %s. Your profile has been made available to all users.', $nick);
        $user{restricted} = 0;
    }
    else {
        $message = sprintf('Ok, %s. Your profile has been restricted to users with profiles only.', $nick);
        $user{restricted} = 1;
    }
    $self->save_user($nick, %user);
    $self->emit_event('user_edited', $nick);
    $self->respond($message, $where, $nick);
}

sub view_command {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    my $profile = shift @arg;
    $self->emit_event('reload_user', $profile);
    if (!defined $self->get_user($profile)) {
        my $message = sprintf('Sorry, %s, no profile found under %s. Try a different name.', $nick, $profile);
        $self->respond($message, $where, $nick);
        return 1;
    }
    else {
        my %user = $self->get_user($profile);
        my $possessive = (lc(substr $profile, -1) eq 's' ? $profile . "'" : $profile . "'s" );
        my $state = $user{state};
        my $oplocked;
        if ($state ne 'approved' && !($chanop || $owner)) {
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
            $self->respond($message, $where, $nick);
            return 1;
        }
        if ($user{restricted} && (!defined $self->get_user($nick) || $self->{users}{lc $nick}{state} ne 'approved') && !$chanop) {
            my $possessive = (lc(substr $profile, -1) eq 's' ? $profile . "'" : $profile . "'s" );
            my $message = sprintf('Sorry, %s. %s profile has been restricted to users with approved profiles only. Create a profile or get yours approved by the ops and try again.', $nick, $possessive);
            $self->respond($message, $where, $nick);
            return 1;
        }
        my $fg = $self->get_color('variables');
        my $text = $self->get_color('text');
        my $userstate = ((($chanop || $owner) && $state ne 'approved') ? "[$self->{colors}{red}" . uc $state . "$text] " : $text);
        my $message = $userstate . "Roleplay profile for $fg$user{name}$text: ";
        $message .= $text . "Age$text: $fg$user{age} ";
        $message .= $text . "Gender Identity$text: $fg$user{gender} ";
        $message .= $text . "Orientation$text: $fg$user{orientation} ";
        $message .= $text . "Preferred Role$text: $fg$user{role} ";
        $message .= $text . "Location$text: $fg$user{location} ";
        $self->{IRC}->yield(notice => $nick => $message);
        $self->{IRC}->yield(notice => $nick => $userstate . $text . "Kinks$text: $fg$user{kinks}");
        $self->{IRC}->yield(notice => $nick => $userstate . $text . "Limits$text: $fg$user{limits}");
        $self->{IRC}->yield(notice => $nick => $userstate . $text . "Description$text: $fg$user{description}");
    }
    return 1;
}

sub command_setup {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    return if defined $self->get_user($nick);
    my %user;
    $user{name} = $nick;
    $user{host} = $nick . '@' . $where;
    $user{state} = 'new';
    $user{created} = time();
    $user{seen} = time();
    $user{updated} = time();
    $user{restricted} = '1';
    $self->save_user($nick, %user);
    $self->emit_event('user_created', $nick);
}

sub start_interview {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    $self->{IRC}->yield(privmsg => $nick => "Welcome to the PoCoProfileBot 1.0.0 interrogation process.");
    $self->{IRC}->yield(privmsg => $nick => "Note that all responses will be limited to 500 characters.");
    $self->{IRC}->yield(privmsg => $nick => "Please begin by entering your age using the command !age, e.g. !age 20 or !age Older Than The Universe.");
}

sub enter_age {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    return unless defined $self->get_user($nick);
    my %user = $self->get_user($nick);
    $user{age} = join ' ', @arg;
    my $response = "Thank you. Your age has been set to $user{age}.";
    if ($user{state} eq 'new') {
        $response .= 'Now enter your gender identity using !gender. ';
        $response .= 'This can be as basic or elaborate as you like, e.g. ';
        $response .= '!gender XX or !gender The Manliest Man That Ever Manned.';
        $user{state} = 'aged';
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    $self->save_user($nick, %user);
    $self->emit_event('user_edited', $nick);
}

sub enter_gender {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    return unless defined $self->get_user($nick);
    my %user = $self->get_user($nick);
    $user{gender} = join ' ', @arg;
    my $response = "Thank you. Your gender identity has been set to $user{gender}.";
    if ($user{state} eq 'aged') {
        $response .= 'Now enter your orientation using !orientation. ';
        $response .= 'For example !orientation lesbian or !orientation I only play with left-handed redheaded men between 35 and 37 years old.';
        $user{state} = 'gendered';
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    $self->save_user($nick, %user);
    $self->emit_event('user_edited', $nick);
}

sub enter_orientation {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    return unless defined $self->get_user($nick);
    my %user = $self->get_user($nick);
    $user{orientation} = join ' ', @arg;
    my $response = "Thank you. Your orientation has been set to $user{orientation}.";
    if ($user{state} eq 'gendered') {
        $response .= 'Now enter your limits using !limits. ';
        $response .= 'For example !limits pain or !limits People who misspell HUMOUR.';
        $user{state} = 'oriented';
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    $self->save_user($nick, %user);
    $self->emit_event('user_edited', $nick);
}

sub enter_limits {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    return unless defined $self->get_user($nick);
    my %user = $self->get_user($nick);
    $user{limits} = join ' ', @arg;
    my $response = "Thank you. Your limits have been set to $user{limits}.";
    if ($user{state} eq 'oriented') {
        $response .= 'Now enter your kinks using !kinks. ';
        $response .= 'For example !kinks spanking or !kinks People who can spell HUMOUR, COLOUR, and HONOUR correctly.';
        $user{state} = 'limited';
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    $self->save_user($nick, %user);
    $self->emit_event('user_edited', $nick);
}

sub enter_kinks {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    return unless defined $self->get_user($nick);
    my %user = $self->get_user($nick);
    $user{kinks} = join ' ', @arg;
    my $response = "Thank you. Your kinks have been set to $user{kinks}.";
    if ($user{state} eq 'limited') {
        $response .= 'Now enter your preferred role using !role. ';
        $response .= 'This can be what role you prefer within BDSM; e.g. !role top, or !role masochist. ';
        $response .= 'Alternatively, you can list the type of character you tend to roleplay, e.g. !role Roman legionnaire or !role Comic book superhero. ';
        $user{state} = 'kinky';
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    $self->save_user($nick, %user);
    $self->emit_event('user_edited', $nick);
}

sub enter_role {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    return unless defined $self->get_user($nick);
    my %user = $self->get_user($nick);
    $user{role} = join ' ', @arg;
    my $response = "Thank you. Your role has been set to $user{role}.";
    if ($user{state} eq 'kinky') {
        $response .= ' Now enter a location using !location. ';
        $response .= 'You can use actual locations, like London or Seattle. You can use fictional locations, like Minas Tirith or Draenor. ';
        $response .= 'You can even use conceptual locations, like In a State of Confusion.';
        $user{state} = 'roled';
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    $self->save_user($nick, %user);
    $self->emit_event('user_edited', $nick);
}

sub enter_location {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    return unless defined $self->get_user($nick);
    my %user = $self->get_user($nick);
    $user{location} = join ' ', @arg;
    my $response = "Thank you. Your location has been set to $user{location}.";
    if ($user{state} eq 'roled') {
        $response .= ' Now describe yourself using !description. ';
        $response .= 'This is a free-form field and you can enter as much or as little as you like.';
        $user{state} = 'located';
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    $self->save_user($nick, %user);
    $self->emit_event('user_edited', $nick);
}

sub enter_description {
    my ($self, $nick, $where, $command, $chanop, $owner, @arg) = @_;
    return unless defined $self->get_user($nick);
    my %user = $self->get_user($nick);
    $user{description} = join ' ', @arg;
    my $response = "Thank you. Your description has been set to $user{description}.";
    if ($user{state} eq 'located') {
        $user{state} = 'pending';
        $response .= " We're all done here. Happy perving!";
        my $message = sprintf('%s has created a profile for your viewing pleasure!', $nick);
        map { $self->{IRC}->yield(privmsg => $_ => $message) } $self->teaser_channels();
        $self->save_user($nick, %user);
        $self->emit_event('profile_found', $nick);
    }
    $self->{IRC}->yield(privmsg => $nick => $response);
    $self->save_user($nick, %user);
    $self->emit_event('user_edited', $nick);
}
1;