package BotCore;
use strict;
use warnings;
use diagnostics;
use DBI;
use Data::Dumper;
use Switch;
use POE;
use YAML;

$Data::Dumper::Indent = 1;

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    $self->readconfig();
    $self->{IRC} = shift;
    $self->{DBH} = DBI->connect("dbi:mysql:dbname=$self->{options}{dbname}", $self->{options}{dbuser}, $self->{options}{dbpass});
    $self->loadusers();
    $self->loadmodules();
    %{$self->{UNITS}} = (second => 1, minute => 60, hour => 3600, day => 86400, week => 604800, month => 2592000, year => 31536000);
    open(my $pidfile,">.irpg.pid");
    print $pidfile getpgrp(0) . "\n";
    close $pidfile;
    return $self;
}

sub loadmodules {
    my $self = shift;
    print "Loading modules... ";
    opendir(my $moddir, $self->{options}{moduledir});
    while (my $file = readdir $moddir) {
        next if !($file =~ /\.pm$/);
        next if  $file eq 'Template.pm';
        my $modname = $file;
        $modname =~ s/\.pm$//;
        require "$self->{options}{moduledir}/$modname.pm";
        my $modpack = "BotCore::Modules::" . $modname;
        $self->{modules}{$modname} = $modpack->new();
        $self->{modules}{$modname}->register_handlers($self);
    }
    print "Done!\n";
}

sub register_handler {
    my ($self, $event, $handler) = @_;
    push @{$self->{events}{$event}}, \&$handler;
}

sub emit_event {
    my ($self, $event, @params) = @_;
    if (!$self->{events}{$event}) {
        $self->debug("No handler defined for event: $event");
        return;
    }
    my @handlers = @{$self->{events}{$event}};
    for my $handler (0..$#handlers) {
        my $handler = $handlers[$handler];
        &$handler($self, @params);
    }
}

sub readconfig {
    print "Loading options... ";
    my $self = shift;
    if (! -e ".config.yaml") {
        print("Error: Cannot find .config.yaml. Copy it to this directory, please.",1);
    }
    else {
        $self->{options} = YAML::LoadFile(".config.yaml");
    }
    print "Done!\n";
}

sub loadusers {
    print "Loading users... ";
    my $self = shift;
    my $dbh = $self->{DBH};
    my $statement = $dbh->prepare("SELECT id, name, age, gender, orientation, role, location, kinks, limits, description, state, restricted, host, created, updated, seen FROM user");
    $statement->execute();
    while (my $userrow = $statement->fetchrow_hashref()) {
        my %user = %$userrow;
        %{$self->{users}{$user{name}}} = %user;
    }
    print "Done!\n";
}

sub mkpass {
    my $self = shift;
    my ($password, $salt) = @_;
    my $hasher = Digest::SHA1->new;
    $hasher->add($password . $salt);
    return $hasher->hexdigest;
}

sub userpart {
    my ($self, $who, $where) = @_[OBJECT, ARG0, ARG1];
    if ($where =~ /^#/) {
        return unless lc $where eq lc $self->{options}{botchan};
    }
    my ($nick, undef) = split /!/, $who;
    $self->{users}{$nick}{seen} = time();
    $self->emit_event('part_channel', $nick);
    return 1;
}

sub userjoin {
    my ($self, $who, $where) = @_[OBJECT, ARG0, ARG1];
    if ($where =~ /^#/) {
        return unless lc $where eq lc $self->{options}{botchan};
    }
    my ($nick, undef) = split /!/, $who;
    if (exists $self->{users}{$nick}) {
        $self->{users}{$nick}{seen} = time();
        $self->emit_event('profile_found', $nick);
    }
    $self->emit_event('join_channel', $nick);
    return 1;
}

sub userkicked {
    my ($self, $where, $nick) = @_[OBJECT, ARG1, ARG2];
    $self->{users}{$nick}{online} = 0;
    $self->saveuser($nick);
    delete $self->{users}{$nick};
    return 1;
}

sub nickchange {
    my ($self, $who, $newnick) = @_[OBJECT, ARG0, ARG1];
    my ($oldnick, undef) = split /!/, $who;
    $self->emit_event('new_nick', $newnick);
    $self->emit_event('nick_change', $oldnick, $newnick);
    delete $self->{users}{$oldnick};
}

sub debug {
    my $self = shift;
    (my $text = shift) =~ s/[\r\n]//g;
    my $die = shift;
    if ($self->{options}{debug} || $self->{options}{verbose}) {
        open(my $debugger,">>$self->{options}{debugfile}") or do {
            print("Error: Cannot open debug file: $!");
            return;
        };
        print $debugger scalar(localtime) . " $text\n";
        close($debugger);
    }
    if ($die) { die("$text\n"); }
    return $text;
}

sub getopts {
    my $self = shift;
    return %{$self->{'options'}};
}

sub heartbeat {
    my ($self, $kernel) = @_[OBJECT, KERNEL];
    $kernel->delay(heartbeat => $self->{options}{self_clock} );
    return if !$self->{users};
    my $online = keys %{$self->{users}};
}

sub parse {
    my ($self, $sender, $who, $what, @target) = @_[OBJECT, SENDER, ARG0, ARG2, ARG1];
    my $where = $target[0][0];
    print "$who said $what in $where\n";
    my $irc = $self->{IRC};
    my ($nick, $userhost) = split /!/, $who;
    my @arg = split / /, $what;
    my $command = lc shift @arg;
    switch ($command) {
        case "!setup" {
            return if exists $self->{users}{$nick};
            my %user;
            $user{name} = $nick;
            $user{host} = split /@/, $userhost;
            $user{state} = 'new';
            $user{created} = time();
            $user{seen} = time();
            $user{updated} = time();
            $user{restricted} = '0';
            %{$self->{users}{$nick}} = %user;
            $self->emit_event('user_created', $nick);
        }
        case '!age' {
            my $age = join ' ', @arg;
            $self->emit_event('command_age', $nick, $age);
        }
        case '!info' {
            my $message = "This is PoCoProfileBot v1.0.0, written in less than 48 hours by CardinalSins.";
            my $recipient;
            if ($where eq $self->{IRC}{INFO}{RealNick}) {
                $recipient = $nick;
            }
            else {
                $recipient = $self->{options}{botchan};
            }
            $self->{IRC}->yield(privmsg => $recipient => $message)
        }
        case '!gender' {
            my $gender = join ' ', @arg;
            $self->emit_event('command_gender', $nick, $gender);
        }
        case '!orientation' {
            my $orientation = join ' ', @arg;
            $self->emit_event('command_orientation', $nick, $orientation);
        }
        case '!limits' {
            my $limits = join ' ', @arg;
            $self->emit_event('command_limits', $nick, $limits);
        }
        case '!kinks' {
            my $kinks = join ' ', @arg;
            $self->emit_event('command_kinks', $nick, $kinks);
        }
        case '!role' {
            my $role = join ' ', @arg;
            $self->emit_event('command_role', $nick, $role);
        }
        case '!location' {
            my $location = join ' ', @arg;
            $self->emit_event('command_location', $nick, $location);
        }
        case '!description' {
            my $description = join ' ', @arg;
            $self->emit_event('command_description', $nick, $description);
        }
        case '!restrict' {
            my $description = join ' ', @arg;
            $self->emit_event('command_restrict', $nick);
        }
        case '!unrestrict' {
            my $description = join ' ', @arg;
            $self->emit_event('command_unrestrict', $nick);
        }
        case "reload" {
            return unless $nick eq $self->{options}{owner};
            $irc->yield(privmsg => $nick => "Yes, effendi, it shall be done.");
            kill URG => $$;
        }
        case "!view" {
            $self->emit_event('view_command', $nick, $where, @arg);
        }
        case "!approve" {
            my $victim = shift @arg;
            my $poco_object = $sender->get_heap();
            my $val = $poco_object->is_channel_operator($self->{options}{botchan}, $nick);
            my $message;
            if (!$val) {
                $message = "I regret that I am unfortunately quite unable to allow that. Good day.";
                return 1;
            }
            else {
                if (!exists $self->{users}{$victim}) {
                    $message = "Oh dear, I'm afraid I simply can't find that profile.";
                }
                else {
                    my %user = %{$self->{users}{$victim}};
                    if ($user{state} eq 'approved') {
                        $message = "Approving a profile twice would be the height of folly.";
                    }
                    else {
                        $message = "Very well, I shall notify the appropriate authorities.";
                        $self->emit_event('modify_state', $victim, 'approved');
                    }
                }
            }
            my $recipient;
            if ($where eq $self->{IRC}{INFO}{RealNick}) {
                $recipient = $nick;
            }
            else {
                $recipient = $self->{options}{botchan};
            }
            $self->{IRC}->yield(privmsg => $recipient => $message);
        }
        case "!unapprove" {
            my $victim = shift @arg;
            my $poco_object = $sender->get_heap();
            my $val = $poco_object->is_channel_operator($self->{options}{botchan}, $nick);
            my $message;
            if (!$val) {
                $message = "I regret that I am unfortunately quite unable to allow that. Good day.";
                return 1;
            }
            else {
                if (!exists $self->{users}{$victim}) {
                    $message = "Oh dear, I'm afraid I simply can't find that profile.";
                }
                else {
                    my %user = %{$self->{users}{$victim}};
                    if ($user{state} ne 'approved') {
                        $message = "I'm afraid they are quite out of approbation to remove.";
                    }
                    else {
                        $message = "Very well, I shall notify the appropriate authorities.";
                        $self->emit_event('modify_state', $victim, 'pending');
                    }
                }
            }
            my $recipient;
            if ($where eq $self->{IRC}{INFO}{RealNick}) {
                $recipient = $nick;
            }
            else {
                $recipient = $self->{options}{botchan};
            }
            $self->{IRC}->yield(privmsg => $recipient => $message);
        }
        case "!lock" {
            my $victim = shift @arg;
            my $poco_object = $sender->get_heap();
            my $val = $poco_object->is_channel_operator($self->{options}{botchan}, $nick);
            my $message;
            if (!$val) {
                $message = "I regret that I am unfortunately quite unable to allow that. Good day.";
                return 1;
            }
            else {
                if (!exists $self->{users}{$victim}) {
                    $message = "Oh dear, I'm afraid I simply can't find that profile.";
                }
                else {
                    my %user = %{$self->{users}{$victim}};
                    if ($user{state} eq 'locked') {
                        $message = "I'm worried the key might break if I try to lock that profile again.";
                    }
                    else {
                        $message = "Very well, I shall notify the appropriate authorities.";
                        $self->emit_event('modify_state', $victim, 'locked');
                    }
                }
            }
            my $recipient;
            if ($where eq $self->{IRC}{INFO}{RealNick}) {
                $recipient = $nick;
            }
            else {
                $recipient = $self->{options}{botchan};
            }
            $self->{IRC}->yield(privmsg => $recipient => $message);
        }
        case "!lock" {
            my $victim = shift @arg;
            my $poco_object = $sender->get_heap();
            my $val = $poco_object->is_channel_operator($self->{options}{botchan}, $nick);
            my $message;
            if (!$val) {
                $message = "I regret that I am unfortunately quite unable to allow that. Good day.";
                return 1;
            }
            else {
                if (!exists $self->{users}{$victim}) {
                    $message = "Oh dear, I'm afraid I simply can't find that profile.";
                }
                else {
                    $message = "As you wish. I shall see them to the door.";
                    $self->emit_event('delete_user', $victim);
                    delete $self->{users}{$victim};
                }
            }
            my $recipient;
            if ($where eq $self->{IRC}{INFO}{RealNick}) {
                $recipient = $nick;
            }
            else {
                $recipient = $self->{options}{botchan};
            }
            $self->{IRC}->yield(privmsg => $recipient => $message);
        }
        case "!rules" {
            my $victim = shift @arg;
            my $poco_object = $sender->get_heap();
            my $val = $poco_object->is_channel_operator($self->{options}{botchan}, $nick);
            my $message = "The rules for $self->{options}{botchan} can be found at $self->{options}{rules_url}";
            my $recipient;
            if ($where eq $self->{IRC}{INFO}{RealNick}) {
                $recipient = $nick;
            }
            else {
                $recipient = $self->{options}{botchan};
            }
            $self->{IRC}->yield(privmsg => $recipient => $message);
        }
        case "!jeeves" {
            my $poco_object = $sender->get_heap();
            my $val = $poco_object->is_channel_operator($self->{options}{botchan}, $nick);
            my $message = "Yes, rather. A dreadful situation. I have summoned the gendarmes.";
            my $recipient;
            if ($where eq $self->{IRC}{INFO}{RealNick}) {
                $recipient = $nick;
            }
            else {
                $recipient = $self->{options}{botchan};
            }
            $self->{IRC}->yield(privmsg => $recipient => $message);
            $self->{IRC}->yield(notice => $self->{options}{helper_prefix} . $self->{options}{botchan} => "$nick is seeking assistance.");
        }
    }
}
1;