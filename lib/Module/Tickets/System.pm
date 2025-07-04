package Module::Tickets::System;

use v5.42;

use Module::Tickets::Camera;
use Module::Tickets::Dispatcher;
use Module::Tickets::Plate;

use Mooish::Base;

has field 'cameras' => (
	isa => HashRef [InstanceOf ['Module::Tickets::Camera']],
	default => sub { {} },
);

has field 'dispatchers' => (
	isa => HashRef [InstanceOf ['Module::Tickets::Dispatcher']],
	default => sub { {} },
);

has field 'plates' => (
	isa => HashRef [InstanceOf ['Module::Tickets::Plate']],
	default => sub { {} },
);

has field 'tickets' => (
	isa => ArrayRef,
	default => sub { [] },
);

sub add_camera ($self, $id, $data)
{
	$self->cameras->{$id} = Module::Tickets::Camera->new(system => $self, $data->%*);
	return $self->cameras->{$id};
}

sub add_dispatcher ($self, $id, $data)
{
	$self->dispatchers->{$id} = Module::Tickets::Dispatcher->new(system => $self, $data->%*);
	$self->drain_tickets;
	return $self->dispatchers->{$id};
}

sub remove_device ($self, $id)
{
	delete $self->cameras->{$id};
	delete $self->dispatchers->{$id};
	return;
}

sub dispatcher_for_road ($self, $road_id)
{
	my @dispatchers;
	foreach my $dispatcher (values $self->dispatchers->%*) {
		push @dispatchers, $dispatcher if $dispatcher->on_road($road_id);
	}

	return $dispatchers[int(rand scalar @dispatchers)];
}

sub cameras_between ($self, $camera_from, $camera_to)
{
	my $road_id = $camera_from->road_id;
	my $from = $camera_from->mile;
	my $to = $camera_to->mile;

	my @cameras = ($camera_from, $camera_to);
	foreach my $camera (values $self->cameras->%*) {
		next unless $camera->on_road($road_id);
		my $mile = $camera->mile;

		push @cameras, $camera
			if $from < $mile < $to;
	}

	return \@cameras;
}

sub plate_seen ($self, $id, $camera, $timestamp)
{
	my $plate = $self->plates->{$id};
	if (!$plate) {
		$plate = Module::Tickets::Plate->new(id => $id);
		$self->plates->{$id} = $plate;
	}

	my @pairs = $plate->add_observation($camera, $timestamp);
	my $ticket;
	foreach my $pair (@pairs) {
		my $cameras = $self->cameras_between($pair->{camera1}, $pair->{camera2});
		if ($plate->check_limit($pair, map { $_->limit } $cameras->@*)) {
			$ticket = $pair;
			last;
		}
	}

	if ($ticket) {
		my %ticket_data = (
			plate => $id,
			road => $ticket->{camera1}->road_id,
			mile1 => $ticket->{camera1}->mile,
			timestamp1 => $ticket->{timestamp1},
			mile2 => $ticket->{camera2}->mile,
			timestamp2 => $ticket->{timestamp2},
			speed => $ticket->{speed},
		);

		$self->dispatch_ticket(\%ticket_data);
		$self->drain_tickets;
	}

	return;
}

sub dispatch_ticket ($self, $data)
{
	push $self->tickets->@*, $data;
	return;
}

sub drain_tickets ($self)
{
	my %dispatchers;
	my @undrained;

	foreach my $ticket_data ($self->tickets->@*) {
		my $road_id = $ticket_data->{road};
		my $dispatcher = $dispatchers{$road_id} //= $self->dispatcher_for_road($road_id);

		if ($dispatcher) {
			$dispatcher->ticket($ticket_data);
		}
		else {
			push @undrained, $ticket_data;
		}
	}

	$self->tickets->@* = @undrained;
	return;
}

