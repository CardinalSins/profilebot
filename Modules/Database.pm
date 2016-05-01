use strict;
use warnings;

package BotCore::Modules::Database;
use Data::Dumper;

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub register_handlers {
    my ($self, $BotCore) = @_;
    $BotCore->register_handler('join_channel', \&BotCore::Modules::Database::loaduser);
    $BotCore->register_handler('new_nick', \&BotCore::Modules::Database::loaduser);
    $BotCore->register_handler('user_created', \&BotCore::Modules::Database::new_user);
    $BotCore->register_handler('user_edited', \&BotCore::Modules::Database::saveuser);
    $BotCore->register_handler('reload_user', \&BotCore::Modules::Database::find_user);
    $BotCore->register_handler('delete_user', \&BotCore::Modules::Database::delete_user);
}

sub delete_user {
    my $self = shift;
    my $nick = shift;
    return unless defined $self->get_user($nick);
    my $dbh = $self->{DBH};
    my %user = $self->get_user($nick);
    my $query = 'DELETE FROM user WHERE name = ? LIMIT 1';
    my $statement = $dbh->prepare($query);
    $statement->execute($user{name});
}

sub new_user {
    my $self = shift;
    my $nick = shift;
    return unless defined $self->get_user($nick);
    my %user = $self->get_user($nick);
    my $dbh = $self->{DBH};
    my $query = "INSERT INTO user (name, age, gender, orientation, role, location, kinks, limits, description, restricted, host, state, created, updated, seen) ";
    $query .= "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";
    $query .= " ON DUPLICATE KEY UPDATE ";
    $query .= "age=VALUES(age), ";
    $query .= "gender=VALUES(gender), ";
    $query .= "orientation=VALUES(orientation), ";
    $query .= "role=VALUES(role), ";
    $query .= "location=VALUES(location), ";
    $query .= "kinks=VALUES(kinks), ";
    $query .= "limits=VALUES(limits), ";
    $query .= "description=VALUES(description), ";
    $query .= "restricted=VALUES(restricted), ";
    $query .= "host=VALUES(host), ";
    $query .= "state=VALUES(state), ";
    $query .= "created=VALUES(created), ";
    $query .= "updated=VALUES(updated), ";
    $query .= "seen=VALUES(seen)";
    my $statement = $dbh->prepare($query);
    $statement->execute($user{name},
                        $user{age},
                        $user{gender},
                        $user{orientation},
                        $user{role},
                        $user{location},
                        $user{kinks},
                        $user{limits},
                        $user{description},
                        $user{restricted},
                        $user{host},
                        'new',
                        time(),
                        time(),
                        time());
    $self->emit_event('reload_user', $nick);
    return 1;
}

sub loaduser {
    my $self = shift;
    my $username = shift;
    my $dbh = $self->{DBH};
    $self->debug("Loading user $username.");
    my $statement = $dbh->prepare("SELECT id, name, age, gender, orientation, role, location, kinks, limits, description, restricted, host, state, created, updated, seen FROM user WHERE name = ?");
    $statement->execute($username);
    my $row = $statement->fetchrow_hashref() or return 1;
    my %user = %{$row};
    $self->debug("$username loaded.");
    %{$self->{users}{lc $user{name}}} = %user;
    return 1;
}

sub find_user {
    my $self = shift;
    my $username = shift;
    my $dbh = $self->{DBH};
    $self->debug("Loading user $username.");
    my $statement = $dbh->prepare("SELECT id, name, age, gender, orientation, role, location, kinks, limits, description, restricted, host, state, created, updated, seen FROM user WHERE name LIKE ?");
    $statement->execute($username);
    my $row = $statement->fetchrow_hashref() or return 1;
    my %user = %{$row};
    $self->debug("$username loaded.");
    $self->save_user($user{name}, %user);
    return 1;
}

sub saveuser {
    my $self = shift;
    my $nick = shift;
    $self->debug("Saving $nick");
    my %user = $self->get_user($nick);
    my $dbh = $self->{DBH};
    my $query = "UPDATE user SET age = ?, gender = ?, orientation = ?, role = ?, location = ?, kinks = ?, ";
    $query .= "limits = ?, description = ?, restricted = ?, host = ?, state = ?, seen = ?, updated = ? WHERE id = $user{id} LIMIT 1";
    $self->debug($query);
    $self->debug(Dumper(\%user));
    my $statement = $dbh->prepare($query) or do{ print $!; die;};
    $statement->execute($user{age}, $user{gender}, $user{orientation}, $user{role},
                        $user{location}, $user{kinks}, $user{limits}, $user{description},
                        $user{restricted}, $user{host}, $user{state}, time(), time()) or do{ $self->debug($!); };
    $self->emit_event('reload_user', $nick);
    $self->debug("$nick saved.");
    return 1;
}

1;