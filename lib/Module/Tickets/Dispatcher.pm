package Module::Tickets::Dispatcher;

use v5.42;

use List::Util qw(any);
use Mooish::Base;

has param 'roads' => (
	isa => ArrayRef [PositiveOrZeroInt],
);

has param 'on_ticket' => (
	isa => CodeRef,
);

with qw(Module::Tickets::Role::NetworkDevice);

sub on_road ($self, $road_id)
{
	return any { $_ == $road_id } $self->roads->@*;
}

sub ticket ($self, $data)
{
	$self->on_ticket->($data);
	return;
}

