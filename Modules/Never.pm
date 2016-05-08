use strict;
use warnings;

package BotCore::Modules::Never;
use Data::Dumper;
use utf8;
use List::Util qw(shuffle min max);

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub register_handlers {
    my ($self, $BotCore) = @_;
    $BotCore->register_handler('never_command_never', \&BotCore::Modules::Never::start_game);
    $BotCore->register_handler('never_command_join', \&BotCore::Modules::Never::join_game);
    $BotCore->register_handler('never_command_resign', \&BotCore::Modules::Never::resign_game);
    $BotCore->register_handler('never_command_transfer', \&BotCore::Modules::Never::transfer_game);
    # $BotCore->register_handler('never_command_start', \&BotCore::Modules::Never::start_game);
    # $BotCore->register_handler('never_command_never', \&BotCore::Modules::Never::add_never);
    # $BotCore->register_handler('never_command_ever', \&BotCore::Modules::Never::add_ever);
    $BotCore->register_handler('never_command_cancel', \&BotCore::Modules::Never::cancel_game);
    $BotCore->register_handler('module_load_never', \&BotCore::Modules::Never::namespace);
}

sub namespace {
    my $self = shift;
    $self->register_command_namespace('.', 'never');
}

sub cancel_game {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    if (!defined $self->{active_game}) {
        my $message = "I'm afraid there's no game to cancel.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    my %game = %{$self->{active_game}};
    my %players = %{$game{players}};
    my $fg = $self->get_color('game');
    my $nt = $self->get_color('normal');
    if (!defined $players{$nick}) {
        my $message = "You're not even playing this game, $fg$nick$nt. You must be at least game host to use that command.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    my %player = %{$players{$nick}};
    if (!$player{host} && !$chanop && !$owner) {
        my $message = $self->get_message('permission_denied');
        $self->respond($message, $where, $nick);
        return 1;
    }
    delete $self->{active_game};
    my $message = "As you wish. The game has ended.";
    $self->respond($message, $where, $nick);
    return 1;
}

sub start_game {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    $self->debug(Dumper(\@arg));
    if (defined $self->{active_game}) {
        my $message = "My apologies, it would be boorish to start a game when there is already one in progress.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    if (!$chanop && !$owner) {
        my $message = $self->get_message('permission_denied');
        $self->respond($message, $where, $nick);
        return 1;
    }
    my @questions = @{$self->{options}{games}{never}{questions}};
    my $question_count = min(int(shift @arg), scalar @questions);
    $self->debug("QC: $question_count");
    $question_count = max(1, $question_count);
    my @shuffled_questions = shuffle(0..$#questions);
    my @selected_qns = @shuffled_questions[0..$question_count - 1];
    my @picks = @questions[@selected_qns];
    my $fg = $self->get_color('game');
    my $nt = $self->get_color('normal');
    my $message = "$fg$nick$nt is hosting a game of $fg" . "Never Have I Ever$nt with $fg" . $question_count . "$nt questions. Type $fg.join$nt to join.";
    my %player = (host => 1, never => 0, have => 0, pass => 0);
    my %players;
    %{$players{$nick}} = %player;
    my %game;
    %{$game{players}} = %players;
    $game{name} = 'never';
    @{$game{questions}} = @picks;
    $self->respond($message, $where, $nick);
    %{$self->{active_game}} = %game;
}

sub join_game {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    if (!defined $self->{active_game}) {
        my $message = "Well, this is embarrassing. I can't seem to find a current game.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    my $fg = $self->get_color('game');
    my $nt = $self->get_color('normal');
    my %game = %{$self->{active_game}};
    my %player = (host => 0, never => 0, have => 0, pass => 0);
    my %players = %{$game{players}};
    if (defined($players{$nick})) {
        my $message = "You're already playing this game, $fg$nick$nt. Use $fg.resign$nt to resign.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    %{$players{$nick}} = %player;
    %{$game{players}} = %players;
    %{$self->{active_game}} = %game;
    my $message = "Welcome player $fg$nick$nt to the game. Use $fg.start$nt to start the game or $fg" . ".cancel$nt to cancel.";
    $self->respond($message, $where, $nick);
}

sub resign_game {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    if (!defined $self->{active_game}) {
        my $message = "Well, this is embarrassing. I can't seem to find a current game.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    my $fg = $self->get_color('game');
    my $nt = $self->get_color('normal');
    my %game = %{$self->{active_game}};
    my %player = (never => 0, have => 0, pass => 0);
    my %players = %{$game{players}};
    if (!defined($players{$nick})) {
        my $message = "I'm afraid I have to insist that you join the game before resigning, $fg$nick$nt.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    delete $players{$nick};
    %{$game{players}} = %players;
    %{$self->{active_game}} = %game;
    my $message = "$fg$nick$nt has resigned from the game. And there was $fg" . "weeping$nt, and there was $fg" . "wailing$nt, and there was $fg" . "gnashing of teeth$nt.";
    $self->respond($message, $where, $nick);
}

sub transfer_game {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    if (!defined $self->{active_game}) {
        my $message = "I'm afraid there's no game to transfer.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    my %game = %{$self->{active_game}};
    my %players = %{$game{players}};
    my $newhost = shift @arg;
    if (!defined $players{$newhost}) {
        my $message = "I do apologise, I can only transfer the game to a current player.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    my $fg = $self->get_color('game');
    my $nt = $self->get_color('normal');
    if ($chanop || $owner) {
        $self->transfer_game_ownership($where, $nick, $newhost);
        return 1;
    }
    if (!defined $players{$nick}) {
        my $message = "You're not playing this game, $fg$nick$nt. You must be game host to use that command.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    my %player = %{$players{$nick}};
    if (!$player{host}) {
        my $message = "Only the game host may transfer the game.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    $self->transfer_game_ownership($where, $nick, $newhost);
    return 1;
}
1;