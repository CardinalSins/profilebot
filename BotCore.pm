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
        $self->{IRC}->yield(privmsg => $where => $message);
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

sub onotice {
    my ($self, $message, $target) = @_;
    $self->debug("Sending $message to $self->{options}{helper_prefix}$self->{options}{botchan}.");
    $self->{IRC}->yield(notice => $self->{options}{helper_prefix} . $target => $message);
    return 1;
}

sub where_ok {
    my ($self, $where) = @_;
    if ($where eq $self->{options}{botchan}) {
        return 1;
    }
    if ($where eq $self->{options}{adminchan}) {
        return 1;
    }
    if ($where eq $self->{IRC}{INFO}{RealNick}) {
        return 1;
    }
    return 0;
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
        $self->emit_event("user_command_$keyword", $nick, $where, $command, $chanop, $owner, @arg);
    }
}
1;