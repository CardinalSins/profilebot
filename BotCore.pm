package BotCore;
use strict;
use warnings;
use diagnostics;
use DBI;
use Data::Dumper;
use POE;
use JSON;
use IRC::Utils qw(NORMAL BOLD UNDERLINE REVERSE ITALIC FIXED WHITE BLACK BLUE GREEN RED BROWN PURPLE ORANGE YELLOW LIGHT_GREEN TEAL LIGHT_CYAN LIGHT_BLUE PINK GREY LIGHT_GREY);
use POSIX qw(strftime);
use utf8;

$Data::Dumper::Indent = 1;

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    $self->{birth} = time;
    $self->readconfig();
    $self->{IRC} = shift;
    $self->{DBH} = DBI->connect("dbi:mysql:dbname=$self->{options}{database}{name}", $self->{options}{database}{user}, $self->{options}{database}{pass});
    $self->loadusers();
    $self->loadmodules();
    my %colors = ( normal => NORMAL, bold => BOLD, underline => UNDERLINE, reverse => REVERSE, italic => ITALIC, fixed => FIXED,
                   white => WHITE, black => BLACK, blue => BLUE, green => GREEN, red => RED, brown => BROWN, purple => PURPLE,
                   orange => ORANGE, yellow => YELLOW, light_green => LIGHT_GREEN, teal => TEAL, light_cyan => LIGHT_CYAN,
                   light_blue => LIGHT_BLUE, pink => PINK, grey => GREY, gray => GREY, light_grey => LIGHT_GREY, light_gray => LIGHT_GREY );
    %{$self->{colors}} = %colors;
    $self->emit_event('startup');
    %{$self->{UNITS}} = (second => 1, minute => 60, hour => 3600, day => 86400, week => 604800, month => 2592000, year => 31536000);
    return $self;
}

sub transfer_game_ownership {
    my ($self, $where, $nick, $newhost) = @_;
    my %game = %{$self->{active_game}};
    my %players = %{$game{players}};
    my %player = %{$players{$nick}};
    my %newhost = %{$players{$newhost}};
    my $fg = $self->get_color('game');
    my $nt = $self->get_color('normal');
    $player{host} = 0;
    $newhost{host} = 1;
    %{$players{$nick}} = %player;
    %{$players{$newhost}} = %newhost;
    %{$game{players}} = %players;
    %{$self->{active_game}} = %game;
    my $message = "Very well, $fg" . "$newhost$nt is now hosting the game.";
    $self->respond($message, $where, $nick);
}

sub channel_voice {
    my ($self, $poco, $nick, $channel, $give) = @_;
    my $usermodes = $poco->nick_channel_modes($channel, $nick) or undef;
    if (defined $usermodes && index($usermodes, 'v') ==  -1 && $give) {
        $self->{IRC}->yield(mode => $channel => '+v' => $nick);
    }
    elsif (defined $usermodes && index($usermodes, 'v') !=  -1 && !$give) {
        $self->{IRC}->yield(mode => $channel => '-v' => $nick);
    }
}

sub register_command_namespace {
    my ($self, $prefix, $namespace) = @_;
    my %prefixes;
    if (defined $self->{command_handlers}) {
        %prefixes = %{$self->{command_handlers}};
    }
    return if defined $prefixes{$namespace};
    $prefixes{$namespace} = $prefix;
    %{$self->{command_handlers}} = %prefixes;
}

sub get_ref {
    my ($self, $option_path) = @_;
    my %options = %{$self->{options}};
    my $at = \%options; $at = ref $at ? $at->{$_} : undef for split /\./, $option_path;
    return \$at;
}

sub versions {
    my ($self, %versions) = @_;
    %{$self->{version}} = %versions;
}

sub getopts { # Used by poco-bot.pl
    my $self = shift;
    return %{$self->{'options'}};
}

sub get_color {
    my ($self, $color) = @_;
    if (!defined $self->{options}{colors}{$color}) {
        return $self->{colors}{normal};
    }
    my %colors = %{$self->{colors}};
    my $color_name = $self->{options}{colors}{$color};
    if (defined $colors{$color_name}) {
        return $colors{$color_name};
    }
    return $self->{colors}{normal};
}

sub loadmodules {
    my $self = shift;
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
    map { $self->emit_event('module_load_' . lc $_) } keys %{$self->{modules}};
    $self->debug("Loading modules ... done!");
}

sub respond {
    my ($self, $message, $where, $nick) = @_;
    my $recipient;
    $message = $self->get_color('normal') . $message;
    $self->{heap}->{seen_traffic} = 1;
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
    my ($package, $filename, $line) = caller;
    if (defined $package) {
        my $information = "$package registered handler for $event";
        $self->debug($information);
    }
    push @{$self->{events}{$event}}, \&$handler;
}

sub emit_event {
    my ($self, $event, @params) = @_;
    my ($package, $filename, $line) = caller;
    if (defined $package && defined $event) {
        $self->debug($package . '::' . $event);
    }
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
        %{$self->{options}} = %{JSON->new->utf8(1)->decode($config)};
        close FH;
    }
    $self->debug("Loading options ... done!");
}

sub saveconfig {
    my ($self, %options) = @_;
    %{$self->{options}} = %options;
    if (! -e ".config.json") {
        print("Error: Cannot find .config.json. Copy it to this directory, please.",1);
    }
    else {
        open (FH, '>.config.json');
        print FH JSON->new->utf8(1)->pretty(1)->encode($self->{options});
        close FH;
        # YAML::DumpFile(".config.json", %options);
        $self->readconfig();
    }
    $self->debug("Saving options ... done!");
}

sub loadusers {
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
    $self->debug("Loading users ... done!");
}

sub my_channel {
    my ($self, $where) = @_;
    my @conf_channels = @{$self->{options}{irc}{channels}};
    for my $i (0..$#conf_channels) {
        my %channel = %{$conf_channels[$i]};
        if (lc $channel{name} eq lc $where) {
            return 1;
        }
    }
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
    $self->{heap}->{seen_traffic} = 1;
    if ($where =~ /^#/) {
        return unless $self->my_channel($where);
    }
    my ($nick, undef) = split /!/, $who;
    return unless defined $self->get_user($nick);
    my %user = $self->get_user($nick);
    $user{seen} = time();
    $self->save_user($nick, %user);
    $self->emit_event('part_channel', $nick);
    delete $self->{users}{lc $nick};
    return 1;
}

sub userjoin {
    my ($self, $who, $where, $sender) = @_[OBJECT, ARG0, ARG1, SENDER];
    my $poco = $sender->get_heap();
    $self->{heap}->{seen_traffic} = 1;
    if ($where =~ /^#/) {
        return unless $self->my_channel($where);
    }
    my ($nick, undef) = split /!/, $who;
    $self->emit_event('reload_user', $nick);
    if (defined $self->get_user($nick)) {
        my %user = $self->get_user($nick);
        $user{seen} = time();
        $self->save_user($nick, %user);
        $self->emit_event('profile_found', $nick, $where, $poco);
    }
    $self->emit_event('join_channel', $nick);
    return 1;
}

sub userkicked {
    my ($self, $where, $nick) = @_[OBJECT, ARG1, ARG2];
    $self->{heap}->{seen_traffic} = 1;
    delete $self->{users}{lc $nick};
    return 1;
}

sub nickchange {
    my ($self, $who, $newnick, $sender) = @_[OBJECT, ARG0, ARG1, SENDER];
    my ($oldnick, undef) = split /!/, $who;
    my $poco = $sender->get_heap();
    $self->{heap}->{seen_traffic} = 1;
    $self->emit_event('new_nick', $newnick);
    $self->emit_event('nick_change', $oldnick, $newnick, $poco);
    delete $self->{users}{lc $oldnick};
}

sub debug {
    my $self = shift;
    (my $text = shift) =~ s/[\r\n]/ /g;
    my ($package, $filename, $line) = caller;
    my $die = shift;
    my $timestamp = strftime "%Y-%m-%d %R:%S", localtime;
    if ($self->{options}{debug} || $self->{options}{verbose}) {
        open(my $debugger,">>$self->{options}{debugfile}") or do {
            print("Error: Cannot open debug file: $!");
            return;
        };
        print $debugger $timestamp . ": $package.$line: $text\n";
        close($debugger);
    }
    if ($die) { die("$text\n"); }
    return $text;
}

sub heartbeat {
    my ($self, $kernel) = @_[OBJECT, KERNEL];
    $kernel->delay(heartbeat => $self->{options}{self_clock} );
    return if !$self->{users};
    my $online = keys %{$self->{users}};
}

sub onotice {
    my ($self, $message, $prefix, $target) = @_;
    $self->debug("Sending to $prefix$target: $message");
    $self->{IRC}->yield(notice => $prefix . $target => $message);
    return 1;
}

sub where_ok {
    my ($self, $where) = @_;
    if ($self->my_channel($where)) {
        return 1;
    }
    if (lc $where eq lc $self->{IRC}{INFO}{RealNick}) {
        return 1;
    }
    return 0;
}

sub my_channels {
    my $self = shift;
    my @channels;
    my @chans = @{$self->{options}{irc}{channels}};
    for my $cn (0..$#chans) {
        my %channel = %{$chans[$cn]};
        push @channels, $channel{name};
    }
    return @channels;
}

sub teaser_channels {
    my $self = shift;
    my @channels;
    my @chans = @{$self->{options}{irc}{channels}};
    for my $cn (0..$#chans) {
        my %channel = %{$chans[$cn]};
        if ($channel{teasers}) {
            push @channels, $channel{name};
        }
    }
    return @channels;
}

sub is_owner {
    my ($self, $nick) = @_;
    return $nick eq $self->{options}{irc}{owner};
}

sub is_chanop {
    my ($self, $nick, $poco) = @_;
    for my $channel ($self->my_channels()) {
        if ($poco->is_channel_operator($channel, $nick)) {
            return 1;
        }
    }
    return $self->is_owner($nick);
}

sub get_message {
    my ($self, $key) = @_;
    my $language = $self->{options}{language};
    my %languages = %{$self->{options}{languages}};
    my $message;
    if (defined $languages{$language}{lc $key}) {
        $message = $languages{$language}{lc $key};
    }
    else {
        $message = undef;
    }
    if (@_) {
        my %tpl_vals = @_;
        for my $key (keys %tpl_vals) {
            $message =~ s/{lc $key}/$tpl_vals{lc $key}/;
        }
    }
    return defined $message ? $message : 'MESSAGE_' . uc $key;
}

sub parse {
    my ($self, $sender, $who, $what, @target) = @_[OBJECT, SENDER, ARG0, ARG2, ARG1];
    $self->{heap}->{seen_traffic} = 1;
    my $where = $target[0][0];
    $self->debug("$who said $what in $where");
    my $irc = $self->{IRC};
    my ($nick, $userhost) = split /!/, $who;
    my @arg = split / /, $what;
    my $command = lc shift @arg;
    my $poco = $sender->get_heap();
    my $chanop = $self->is_chanop($nick, $poco);
    my $owner = $self->is_owner($nick);
    return if $nick =~ /^(Cuff\d+|Guest\d+|Perv\d+|mib_.+)/;
    my $prefix_characters = $self->{options}{prefix_characters};
    if ($what =~ /^([$prefix_characters])([^ ]+) ?(.*)/) {
        return unless defined $1 && grep (/$1/, values %{$self->{command_handlers}});
        my $key = $1;
        my %handlers = %{$self->{command_handlers}};
        my @command_handlers = grep { $handlers{$_} eq $key } keys %handlers;
        my $keyword = $2;
        my @arg;
        if (defined $3) {
            @arg = split / /, $3;
        }
        else {
            @arg = undef;
        }
        map { $self->emit_event($_ . "_command_$keyword", $nick, $where, $command, $chanop, $owner, $poco, @arg) } @command_handlers;
    }
}
1;