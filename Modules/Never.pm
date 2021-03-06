use strict;
use warnings;

package BotCore::Modules::Never;
use Data::Dumper;
use utf8;
use List::Util qw(shuffle min max);
use List::MoreUtils qw(uniq);

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub register_handlers {
    my ($self, $BotCore) = @_;
    $BotCore->register_handler('nick_change', \&BotCore::Modules::Never::rename_player);
    $BotCore->register_handler('part_channel', \&BotCore::Modules::Never::forget_player);
    $BotCore->register_handler('game_command_questions', \&BotCore::Modules::Never::list_questions);
    $BotCore->register_handler('game_command_add', \&BotCore::Modules::Never::add_question);
    $BotCore->register_handler('game_command_nhie', \&BotCore::Modules::Never::create_game);
    $BotCore->register_handler('game_command_nqp', \&BotCore::Modules::Never::ask_question);
    $BotCore->register_handler('game_command_boot', \&BotCore::Modules::Never::remove_player);
    $BotCore->register_handler('game_command_join', \&BotCore::Modules::Never::join_game);
    $BotCore->register_handler('game_command_resign', \&BotCore::Modules::Never::resign_game);
    $BotCore->register_handler('game_command_transfer', \&BotCore::Modules::Never::transfer_game);
    $BotCore->register_handler('game_command_start', \&BotCore::Modules::Never::start_game);
    $BotCore->register_handler('game_command_never', \&BotCore::Modules::Never::add_vote);
    $BotCore->register_handler('game_command_have', \&BotCore::Modules::Never::add_vote);
    $BotCore->register_handler('game_command_ever', \&BotCore::Modules::Never::add_vote);
    $BotCore->register_handler('game_command_players', \&BotCore::Modules::Never::list_players);
    $BotCore->register_handler('game_finished', \&BotCore::Modules::Never::show_summary);
    $BotCore->register_handler('ask_question', \&BotCore::Modules::Never::ask_question);
    $BotCore->register_handler('game_command_cancel', \&BotCore::Modules::Never::cancel_game);
    $BotCore->register_handler('module_load_never', \&BotCore::Modules::Never::namespace);
}

sub forget_player {
    my ($self, $nick, $where) = @_;
    my ($command, $chanop, $owner, $poco, @arg) = ('undef', 'undef'. 'undef', 'undef', ['undef']);
    return unless defined $self->{active_game};
    return unless defined $self->{active_game}{players}{$nick};
    delete $self->{active_game}{players}{$nick};
    $self->debug(Dumper(\%{$self->{active_game}}));
    my @playernames = keys %{$self->{active_game}{players}};
    my @responded = @{$self->{active_game}{current_round}{responded}};
    my @newresponded;
    my $players = scalar @playernames;
    for my $responder (@responded) {
        if ($responder ne $nick) {
            push @newresponded, $responder;
        }
    }
    @{$self->{active_game}{current_round}{responded}} = @newresponded;
    my $responders = scalar @newresponded;
    $nick = $self->{active_game}{host};
    if ($responders == $players) {
        $self->debug(Dumper(\@{$self->{active_game}{questions}{pending}}));
        if (@{$self->{active_game}{questions}{pending}}) {
            $self->emit_event('ask_question', $nick, $where, $command, $chanop, $owner, $poco, @arg);
        }
        else {
            $self->emit_event('game_finished', $nick, $where, $command, $chanop, $owner, $poco, @arg);
        }
    }
}

sub rename_player {
    my ($self, $old_nick, $new_nick, $poco) = @_;
    return unless defined $self->{active_game};
    return unless defined $self->{active_game}{players}{$old_nick};
    my %player = %{$self->{active_game}{players}{$old_nick}};
    %{$self->{active_game}{players}{$new_nick}} = %player;
    delete $self->{active_game}{players}{$old_nick};
    my @responded = @{$self->{active_game}{current_round}{responded}};
    my @newresponded;
    for my $responder (@responded) {
        if ($responder eq $old_nick) {
            push @newresponded, $new_nick;
        }
        else {
            push @newresponded, $responder;
        }
    }
    @{$self->{active_game}{current_round}{responded}} = @newresponded;
    $self->debug("Replaced $old_nick with $new_nick");
}

sub list_questions {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    my @questions = @{$self->{options}{games}{never}{questions}};
    open(my $fh,">:encoding(utf-8)", $self->{options}{questionfile}) or do {
        $self->debug("Error: Cannot open questions file: $!");
        return;
    };
    for my $question (@questions) {
        $question = ucfirst $question;
        $question =~ s/\.$//;
        print $fh $question . ".\n";
    }
    close $fh;
    my $message = "$nick: A list of my questions can be found at $self->{options}{questionurl}";
    $self->respond($message, $where, $nick);
}

sub add_question {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    my $question = join ' ', @arg;
    if (!$chanop && !$owner) {
        my $message = $self->get_message('permission_denied');
        $self->respond($message, $where, $nick);
        return 1;
    }
    my @questions = @{$self->{options}{games}{never}{questions}};
    push @questions, $question;
    @{$self->{options}{games}{never}{questions}} = sort(uniq(@questions));
    $self->saveconfig(%{$self->{options}});
    my $message = "I have added that question.";
    $self->respond($message, $where, $nick);
    return 1;
}

sub remove_player {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    return unless defined $self->{active_game};
    my %player = %{$self->{active_game}{players}{$nick}};
    if (!$player{host} && !$chanop && !$owner) {
        my $message = $self->get_message('permission_denied');
        $self->respond($message, $where, $nick);
        return 1;
    }
    my $victim = shift @arg;
    delete $self->{active_game}{players}{$victim};
    my $message = "$victim has been expunged.";
    $self->respond($message, $where, $nick);
}

sub list_players {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    return unless defined $self->{active_game};
    my @responded = @{$self->{active_game}{current_round}{responded}};
    my $na = $self->{colors}{red};
    my $fg = $self->get_color('game');
    my $nt = $self->get_color('normal');
    my @players;
    for my $player (keys %{$self->{active_game}{players}}) {
        if (grep /$player/, @responded) {
            push @players, "$fg$player$nt";
        }
        else {
            push @players, "$na$player$nt";
        }
    }
    my $playerlist = join ", ", @players;
    my $message = "Current players: $playerlist";
    $self->respond($message, $where, $nick);
}

sub ask_question {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    my %player = %{$self->{active_game}{players}{$nick}};
    if (!$player{host} && !$chanop && !$owner && $command eq '.nqp') {
        my $message = $self->get_message('permission_denied');
        $self->respond($message, $where, $nick);
        return 1;
    }
    my %game = %{$self->{active_game}};
    my @empty;
    @{$game{current_round}{responded}} = @empty;
    my $fg = $self->get_color('game');
    my $nt = $self->get_color('normal');
    my $question = shift @{$game{questions}{pending}};
    push @{$game{questions}{asked}}, $question;
    my $aq = scalar @{$game{questions}{pending}};
    my $nq = scalar @{$game{questions}{asked}};
    my $tq = $aq + $nq;
    my $message = "$nq/$tq: I have never been so foolish that I have ... $fg$question$nt.";
    if (!@{$game{questions}{pending}}) {
        $message .= " $fg" . "Final question$nt.";
    }
    $self->respond($message, $where, $nick);
    %{$self->{active_game}} = %game;
}

sub show_summary {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    return unless defined $self->{active_game};
    my %game = %{$self->{active_game}};
    my $fg = $self->get_color('game');
    my $nt = $self->get_color('normal');
    my $message = "Game finished. Player responses, in descending order of $fg" . "have$nt/$fg" . "never$nt ratio: ";
    $self->respond($message, $where, $nick);
    my @playerlist;
    for my $player (keys %{$game{players}}) {
        my %playerhash = %{$game{players}{$player}};
        $playerhash{name} = $player;
        if ($playerhash{have} == 0 || $playerhash{never} == 0) {
            if ($playerhash{have} == 0) {
                $playerhash{ratio} = 'Inf';
            }
            else {
                $playerhash{ratio} = 'NaN';
            }
        }
        else {
            $playerhash{ratio} = $playerhash{have} / $playerhash{never};
        }
        my $playerref = \%playerhash;
        push @playerlist, $playerref;
    }
    my @rankings = sort { $b->{ratio} <=> $a->{ratio} } @playerlist;
    for my $result (@rankings) {
        my %player = %{$result};
        $self->respond("$player{name}: $player{ratio} ($player{have}/$player{never})", $where, $nick)
    }
    delete $self->{active_game};
}

sub add_vote {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    return unless defined $self->{active_game};
    return unless $self->{active_game}{state} eq 'running';
    my $fg = $self->get_color('game');
    my $nt = $self->get_color('normal');
    my %game = %{$self->{active_game}};
    my %players = %{$game{players}};
    my @playernames = keys %players;
    @{$self->{active_game}{participants}} = keys %players;
    my @responded;
    my @pending_questions = @{$game{questions}{pending}};
    if (defined $game{current_round}{responded}) {
        @responded = @{$game{current_round}{responded}};
    }
    return if grep /$nick/, @{$game{current_round}{responded}};
    push @{$game{current_round}{responded}}, $nick;
    return unless defined $players{$nick};
    if ($command eq '.never') {
        $players{$nick}{never}++;
    }
    else {
        $players{$nick}{have}++;
    }
    my $playercount = scalar @playernames;
    my $respondedcount = scalar @{$game{current_round}{responded}};
    if (!@{$game{questions}{pending}} && $playercount == $respondedcount) {
        $self->emit_event('game_finished', $nick, $where, $command, $chanop, $owner, $poco, @arg);
        return 1;
    }
    my @pending_qs = @{$game{questions}{pending}};
    my $pending_count = scalar @pending_qs;
    if ($playercount == $respondedcount && $pending_count > 0) {
        $self->emit_event('ask_question', $nick, $where, $command, $chanop, $owner, $poco, @arg);
    }
    %{$self->{active_game}} = %game;
}

sub start_game {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    return unless defined $self->{active_game};
    my $fg = $self->get_color('game');
    my $nt = $self->get_color('normal');
    my %player = %{$self->{active_game}{players}{$nick}};
    if (!$player{host} && !$chanop && !$owner) {
        my $message = $self->get_message('permission_denied');
        $self->respond($message, $where, $nick);
        return 1;
    }
    $self->{active_game}{state} = 'running';
    my $message = "$fg$nick$nt has started the game. Use $fg.have$nt to indicate that you have experiened the listed situation, $fg.never$nt to indicate that you have not.";
    $self->respond($message, $where, $nick);
    $self->emit_event('ask_question', $nick, $where, $command, $chanop, $owner, $poco, @arg);
}

sub namespace {
    my $self = shift;
    $self->register_command_namespace('.', 'game');
}

sub cancel_game {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
    if (!defined $self->{active_game}) {
        my $message = "I'm afraid there's no game to cancel.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    my %player = $self->{active_game}{players}{$nick};
    if (!$player{host} && !$chanop && !$owner) {
        my $message = $self->get_message('permission_denied');
        $self->respond($message, $where, $nick);
        return 1;
    }
    my %players = %{$self->{active_game}{players}};
    my $fg = $self->get_color('game');
    my $nt = $self->get_color('normal');
    if (!defined $players{$nick}) {
        my $message = "You're not even playing this game, $fg$nick$nt. You must be at least game host to use that command.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    delete $self->{active_game};
    my $message = "As you wish. The game has ended.";
    $self->respond($message, $where, $nick);
    return 1;
}

sub create_game {
    my ($self, $nick, $where, $command, $chanop, $owner, $poco, @arg) = @_;
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
    $question_count = max(1, $question_count);
    my @shuffled_questions = shuffle(0..$#questions);
    my @selected_qns = @shuffled_questions[0..$question_count - 1];
    my @picks = @questions[@selected_qns];
    my $fg = $self->get_color('game');
    my $nt = $self->get_color('normal');
    my $message = "$fg$nick$nt is hosting a game of $fg" . "Never Have I Ever$nt with $fg" . $question_count;
    $message .= "$nt questions. Type $fg.join$nt to join. When enough players have joined, type $fg.start$nt to start the game.";
    my %player = (host => 1, never => 0, have => 0);
    my %players;
    %{$players{$nick}} = %player;
    my %game;
    my @responded;
    my %round;
    @{$round{responded}} = @responded;
    @{$game{participants}} = keys %players;
    %{$game{current_round}} = %round;
    %{$game{players}} = %players;
    $game{host} = $nick;
    $game{name} = 'never';
    $game{state} = 'preparing';
    my %qs;
    my @done;
    @{$qs{pending}} = @picks;
    @{$qs{asked}} = @done;
    %{$game{questions}} = %qs;
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
    if ($self->{active_game}{state} ne 'preparing') {
        my $message = "I'm afraid you can only join the game before it has been started.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    my $fg = $self->get_color('game');
    my $nt = $self->get_color('normal');
    my %game = %{$self->{active_game}};
    my %player = (host => 0, never => 0, have => 0, pass => 0);
    if (defined $game{players}{$nick}) {
        my $message = "You're already playing this game, $fg$nick$nt. Use $fg.resign$nt to resign.";
        $self->respond($message, $where, $nick);
        return 1;
    }
    %{$game{players}{$nick}} = %player;
    @{$game{participants}} = keys %{$game{players}};
    %{$self->{active_game}} = %game;
    my $message = "Welcome player $fg$nick$nt to the game.";
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