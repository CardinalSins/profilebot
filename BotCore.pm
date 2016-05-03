package BotCore;
use strict;
use warnings;
use diagnostics;
use DBI;
use Data::Dumper;
use Switch;
use POE;
use YAML;
use JSON;
use IRC::Utils qw(NORMAL BOLD UNDERLINE REVERSE ITALIC FIXED WHITE BLACK BLUE GREEN RED BROWN PURPLE ORANGE YELLOW LIGHT_GREEN TEAL LIGHT_CYAN LIGHT_BLUE PINK GREY LIGHT_GREY);

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
    my %colors = ( normal => NORMAL, bold => BOLD, underline => UNDERLINE, reverse => REVERSE, italic => ITALIC, fixed => FIXED,
                   white => WHITE, black => BLACK, blue => BLUE, green => GREEN, red => RED, brown => BROWN, purple => PURPLE,
                   orange => ORANGE, yellow => YELLOW, light_green => LIGHT_GREEN, teal => TEAL, light_cyan => LIGHT_CYAN,
                   light_blue => LIGHT_BLUE, pink => PINK, grey => GREY, gray => GREY, light_grey => LIGHT_GREY, light_gray => LIGHT_GREY );
    %{$self->{colors}} = %colors;
    $self->emit_event('load_pending');
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

sub respond {
    my ($self, $message, $where, $nick) = @_;
    my $recipient;
    if ($where eq $self->{IRC}{INFO}{RealNick}) {
        $self->{IRC}->yield(notice => $nick => $message);
    }
    else {
        $self->{IRC}->yield(privmsg => $self->{options}{botchan} => $message);
    }
    return 1;
}

sub register_handler {
    my ($self, $event, $handler) = @_;
    push @{$self->{events}{$event}}, \&$handler;
}

sub emit_event {
    my ($self, $event, @params) = @_;
    if (!$self->{events}{$event}) {
        $self->debug("Event $event triggered but no handler defined.");
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
    if (! -e ".config.json") {
        print("Error: Cannot find .config.json. Copy it to this directory, please.",1);
    }
    else {
        my $config;
        open (FH, '<.config.json');
        while (<FH>) {
            $config .= $_;
        }
        # $self->debug($config);
        %{$self->{options}} = %{decode_json($config)};
        # $self->debug(Dumper($self->{options}));
        close FH;
    }
    print "Done!\n";
}

sub saveconfig {
    print "Saving options... ";
    my ($self, %options) = @_;
    %{$self->{options}} = %options;
    if (! -e ".config.json") {
        print("Error: Cannot find .config.json. Copy it to this directory, please.",1);
    }
    else {
        open (FH, '>.config.json');
        print FH encode_json($self->{options});
        close FH;
        # YAML::DumpFile(".config.json", %options);
        $self->readconfig();
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
        if (!defined $user{orientation}) {
            $user{orientation} = 'undefined';
        }
        %{$self->{users}{lc $user{name}}} = %user;
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

sub get_user {
    my ($self, $name) = @_;
    if (exists $self->{users}{lc $name} && defined $self->{users}{lc $name}) {
        return %{$self->{users}{lc $name}};
    }
    return undef;
}

sub save_user {
    my ($self, $name, %data) = @_;
    %{$self->{users}{lc $name}} = %data;
}

sub userpart {
    my ($self, $who, $where) = @_[OBJECT, ARG0, ARG1];
    if ($where =~ /^#/) {
        return unless lc $where eq lc $self->{options}{botchan};
    }
    my ($nick, undef) = split /!/, $who;
    my %user = $self->get_user($nick);
    $user{seen} = time();
    $self->save_user($nick, %user);
    $self->emit_event('part_channel', $nick);
    delete $self->{users}{lc $nick};
    return 1;
}

sub userjoin {
    my ($self, $who, $where) = @_[OBJECT, ARG0, ARG1];
    if ($where =~ /^#/) {
        return unless lc $where eq lc $self->{options}{botchan};
    }
    my ($nick, undef) = split /!/, $who;
    $self->emit_event('reload_user', $nick);
    if (defined $self->get_user($nick)) {
        my %user = $self->get_user($nick);
        $user{seen} = time();
        $self->save_user($nick, %user);
        $self->emit_event('profile_found', $nick);
    }
    $self->emit_event('join_channel', $nick);
    return 1;
}

sub userkicked {
    my ($self, $where, $nick) = @_[OBJECT, ARG1, ARG2];
    delete $self->{users}{lc $nick};
    return 1;
}

sub nickchange {
    my ($self, $who, $newnick) = @_[OBJECT, ARG0, ARG1];
    my ($oldnick, undef) = split /!/, $who;
    $self->emit_event('new_nick', $newnick);
    $self->emit_event('nick_change', $oldnick, $newnick);
    delete $self->{users}{lc $oldnick};
}

sub debug {
    my $self = shift;
    (my $text = shift) =~ s/[\r\n]/ /g;
    my ($package, $filename, $line) = caller;
    my $die = shift;
    if ($self->{options}{debug} || $self->{options}{verbose}) {
        open(my $debugger,">>$self->{options}{debugfile}") or do {
            print("Error: Cannot open debug file: $!");
            return;
        };
        print $debugger scalar(localtime) . " $package.$line: $text\n";
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
    my $poco = $sender->get_heap();
    my $chanop = $poco->is_channel_operator($self->{options}{botchan}, $nick);
    my $owner = ($nick eq $self->{options}{owner});
    return if $nick =~ /^(Cuff\d+|Guest\d+|Perv\d+|mib_.+)/;
    if ($what =~ /^!([^ ]+) ?(.*)/) {
        my $keyword = $1;
        my @arg;
        if (defined $2) {
            @arg = split / /, $2;
        }
        else {
            @arg = undef;
        }
        $self->debug(Dumper(\@arg));
        $self->emit_event("user_command_$keyword", $nick, $where, $command, $chanop, $owner, @arg);
    }
    switch ($command) {
        case "!approve" {
            my $victim = shift @arg;
            my $message;
            if (!$chanop) {
                $message = "I regret that I am unfortunately quite unable to allow that. Good day.";
            }
            else {
                $self->emit_event('reload_user', $victim);
                if (!defined $self->get_user($victim)) {
                    $message = "Oh dear, I'm afraid I simply can't find that profile.";
                }
                else {
                    my %user = $self->get_user($victim);
                    if ($user{state} eq 'approved') {
                        $message = "Approving a profile twice would be the height of folly.";
                    }
                    else {
                        $message = "As you wish, I will sneer at them with slightly less contempt in the future.";
                        $self->emit_event('modify_state', $victim, 'approved');
                        $self->{IRC}->yield(mode => $self->{options}{botchan} => '+v' => $victim);
                    }
                }
            }
            $self->respond($message, $where, $nick);
        }
        case "!unapprove" {
            my $victim = shift @arg;
            my $message;
            if (!$chanop) {
                $message = "I regret that I am unfortunately quite unable to allow that. Good day.";
            }
            else {
                $self->emit_event('reload_user', $victim);
                if (!defined $self->get_user($victim)) {
                    $message = "Oh dear, I'm afraid I simply can't find that profile.";
                }
                else {
                    my %user = $self->get_user($victim);
                    if ($user{state} ne 'approved') {
                        $message = "I'm afraid they are quite out of approbation to remove.";
                    }
                    else {
                        $message = "Excellent choice. They are quite the rascal, are they not?";
                        $self->emit_event('modify_state', $victim, 'pending');
                        $self->{IRC}->yield(mode => $self->{options}{botchan}, '-v', $victim);
                    }
                }
            }
            $self->respond($message, $where, $nick);
        }
        case "!lock" {
            my $victim = shift @arg;
            my $message;
            if (!$chanop) {
                $message = "I regret that I am unfortunately quite unable to allow that. Good day.";
            }
            else {
                $self->emit_event('reload_user', $victim);
                if (!defined $self->get_user($victim)) {
                    $message = "Oh dear, I'm afraid I simply can't find that profile.";
                }
                else {
                    my %user = $self->get_user($victim);
                    if ($user{state} eq 'locked') {
                        $message = "I'm worried the key might break if I try to lock that profile again.";
                    }
                    else {
                        $message = "I've notified General Farthingworth that $victim is to be held incommunicado until further notice.";
                        $self->emit_event('modify_state', $victim, 'locked');
                    }
                }
            }
            $self->respond($message, $where, $nick);
        }
        case "!delete" {
            my $victim = shift @arg;
            my $message;
            if (!$chanop) {
                $message = "I regret that I am unfortunately quite unable to allow that. Good day.";
            }
            else {
                $self->emit_event('reload_user', $victim);
                if (!defined $self->get_user($victim)) {
                    $message = "Oh dear, I'm afraid I simply can't find that profile.";
                }
                else {
                    $message = "Splendid, I shall see $victim to the door post haste. And good riddance.";
                    $self->emit_event('delete_user', $victim);
                    $self->{IRC}->yield(mode => $self->{options}{botchan} => '-v' => $victim);
                    delete $self->{users}{lc $victim};
                }
            }
            $self->respond($message, $where, $nick);
        }
        case "!rules" {
            my $victim = shift @arg;
            my $message = "The rules for $self->{options}{botchan} can be found at $self->{options}{rules_url}";
            $self->respond($message, $where, $nick);
        }
        case "!profilecommands" {
            $self->{IRC}->yield(notice => $nick => "====== Profile Commands supported by PoCoProfileBot v1.0.0 ======");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_BLUE]}!setup@{[NORMAL]}:           Start the profile creation process.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_BLUE]}!age@{[NORMAL]}:             Set your age. Initiates the next step, if creating a profile.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_BLUE]}!gender@{[NORMAL]}:          Set your gender identity. Initiates the next step, if creating a profile.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_BLUE]}!orientation@{[NORMAL]}:     Set your orientation. Initiates the next step, if creating a profile.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_BLUE]}!role@{[NORMAL]}:            Set your role. Initiates the next step, if creating a profile.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_BLUE]}!location@{[NORMAL]}:        Set your location. Initiates the next step, if creating a profile.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_BLUE]}!kinks@{[NORMAL]}:           Set your kinks. Initiates the next step, if creating a profile.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_BLUE]}!limits@{[NORMAL]}:          Set your limits. Initiates the next step, if creating a profile.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_BLUE]}!description@{[NORMAL]}:     Set your description. Initiates the next step, if creating a profile.");
        }
        case "!commands" {
            $self->{IRC}->yield(notice => $nick => "====== General Commands supported by PoCoProfileBot v1.0.0 ======");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_GREEN]}!commands@{[NORMAL]}:        Show this help text.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_GREEN]}!info@{[NORMAL]}:            Show information about the bot.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_GREEN]}!rules@{[NORMAL]}:           Show the channel rules.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_GREEN]}!jeeves@{[NORMAL]}:          Alert the channel ops that you need assistance.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_GREEN]}!restrict@{[NORMAL]}:        Restrict viewing your profile to users with profiles only.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_GREEN]}!unrestrict@{[NORMAL]}:      Remove the restriction from your profile.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_GREEN]}!profilecommands@{[NORMAL]}: Show the profile-related commands.");
            $self->{IRC}->yield(notice => $nick => "@{[LIGHT_GREEN]}!allcommands@{[NORMAL]}:     Show all commands. May be text-heavy.");
            if ($chanop) {
                $self->{IRC}->yield(notice => $nick => "@{[TEAL]}!opcommands@{[NORMAL]}:      Show only the op commands.");
            }
        }
        case "!opcommands" {
            return unless $chanop;
            $self->{IRC}->yield(notice => $nick => "====== Admin Commands supported by PoCoProfileBot v1.0.0 ======");
            $self->{IRC}->yield(notice => $nick => "@{[TEAL]}!lock@{[NORMAL]}:            Lock a user's profile.");
            $self->{IRC}->yield(notice => $nick => "@{[TEAL]}!delete@{[NORMAL]}:          Delete a user's profile.@{[BOLD]} This is immediate and irreversible@{[NORMAL]}.");
            $self->{IRC}->yield(notice => $nick => "@{[TEAL]}!approve@{[NORMAL]}:         Approve a user's profile. Approved profiles can be viewed, pending will only show teasers.");
            $self->{IRC}->yield(notice => $nick => "@{[TEAL]}!unapprove@{[NORMAL]}:       Set a user's profile to pending.");
        }
        case "!jeeves" {
            my $message = "Yes, rather. A dreadful situation. I have summoned the gendarmes.";
            my $helptext = join ' ', @arg;
            $self->respond($message, $where, $nick);
            $self->{IRC}->yield(notice => $self->{options}{helper_prefix} . $self->{options}{botchan} => "$nick is seeking assistance: $helptext");
        }
    }
}
1;