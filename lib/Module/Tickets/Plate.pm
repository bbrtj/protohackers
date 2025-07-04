package Module::Tickets::Plate;

use v5.42;

use List::BinarySearch qw(binsearch_pos);
use List::Util qw(min);

use Mooish::Base;

has param 'id' => (
	isa => Str,
);

has field 'seen' => (
	isa => HashRef [ArrayRef [Tuple [InstanceOf ['Module::Tickets::Camera'], PositiveOrZeroInt]]],
	default => sub { {} },
);

has field 'tickets' => (
	isa => HashRef [Bool],
	default => sub { {} },
);

use constant SEC_PER_HOUR => 60 * 60;
use constant SEC_PER_DAY => SEC_PER_HOUR * 24;

my sub day_from_timestamp ($timestamp)
{
	return int($timestamp / SEC_PER_DAY);
}

sub _calc_speed ($self, $on_road, $pos1, $pos2)
{
	my $distance = abs($on_road->[$pos1][0]->mile - $on_road->[$pos2][0]->mile);
	my $time = abs($on_road->[$pos1][1] - $on_road->[$pos2][1]);
	my $speed = $distance / $time * SEC_PER_HOUR;

	return {
		speed => $speed,
		timestamp1 => $on_road->[$pos1][1],
		timestamp2 => $on_road->[$pos2][1],
		camera1 => $on_road->[$pos1][0],
		camera2 => $on_road->[$pos2][0],
	};
}

sub add_observation ($self, $camera, $timestamp)
{
	my $road = $camera->road_id;
	$self->seen->{$road} //= [];
	my $on_road = $self->seen->{$road};
	my $pos = binsearch_pos { $a <=> $b->[1] } $timestamp, $on_road->@*;
	splice $on_road->@*, $pos, 0, [$camera, $timestamp];

	my @pairs;

	if ($pos > 0) {
		push @pairs, $self->_calc_speed($on_road, $pos - 1, $pos);
	}

	if ($pos < $on_road->$#*) {
		push @pairs, $self->_calc_speed($on_road, $pos, $pos + 1);
	}

	return @pairs;
}

sub check_limit ($self, $pair, @limits)
{
	my $limit = min @limits;
	if ($pair->{speed} > $limit && !$self->got_ticket($pair->{timestamp1}) && !$self->got_ticket($pair->{timestamp2})) {
		$self->remember_ticket($pair->{timestamp1});
		$self->remember_ticket($pair->{timestamp2});
		return !!1;
	}

	return !!0;
}

sub got_ticket ($self, $timestamp)
{
	return !!1 if $self->tickets->{day_from_timestamp($timestamp)};
	return !!0;
}

sub remember_ticket ($self, $timestamp)
{
	$self->tickets->{$timestamp} = 1;
	$self->tickets->{day_from_timestamp($timestamp)} = 1;
	return;
}

