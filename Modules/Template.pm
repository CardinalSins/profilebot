use strict;
use warnings;

package BotCore::Modules::__Template__;

sub new {
    my $class = shift;
    my $self = {};
    bless($self, $class);
    return $self;
}

sub register_handlers {
    my ($self, $BotCore) = @_;
    $BotCore->register_handler('__template__', \&BotCore::Modules::__Template__::__HANDLER__);
}

sub __HANDLER__ {
    my ($self, @params) = @_;
    return 1;
}
1;