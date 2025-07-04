package Module::Tickets::Camera;

use v5.42;

use Mooish::Base;

has param 'road_id' => (
	isa => PositiveOrZeroInt,
);

has param 'mile' => (
	isa => PositiveOrZeroInt,
);

has param 'limit' => (
	isa => PositiveOrZeroInt,
);

with qw(Module::Tickets::Role::NetworkDevice);

sub on_road ($self, $road_id)
{
	return $self->road_id == $road_id;
}

sub plate ($self, $plate, $timestamp)
{
	$self->system->plate_seen($plate, $self, $timestamp);
	return;
}

