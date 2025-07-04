package Module::Tickets;

use v5.42;

use Module::Tickets::System;

use Mooish::Base;

extends 'Module';

has field 'system' => (
	isa => InstanceOf ['Module::Tickets::System'],
	default => sub { Module::Tickets::System->new },
);

my sub enc_str ($str)
{
	my $len = length $str;
	die 'invalid string, max length is 255'
		if $len > 255;

	return pack 'CA*', $len, $str;
}

my sub dec_str ($str, $offset)
{
	$str = substr $str, $$offset;
	die 'invalid string offset' unless length $str;

	my ($len, $ret) = unpack 'CA*', $str;
	die 'invalid string, length not satisfied' unless length $ret >= $len;

	$$offset += $len + 1;
	return substr $ret, 0, $len;
}

my sub enc_uint ($len, $value)
{
	my $size = $len / 8;
	my $type = $size == 1
		? 'C'
		: $size == 2
		? 'n'
		: $size == 4
		? 'N'
		: undef
		;

	die 'invalid uint size'
		unless defined $type;

	return pack $type, $value;
}

my sub dec_uint ($len, $str, $offset)
{
	$str = substr $str, $$offset;
	die 'invalid string offset' unless length $str;

	my $size = $len / 8;
	my $type = $size == 1
		? 'C'
		: $size == 2
		? 'n'
		: $size == 4
		? 'N'
		: undef
		;

	die 'invalid uint size'
		unless defined $type;

	die "invalid uint$len, length not satisfied"
		unless length $str >= $size;

	$$offset += $size;
	return unpack $type, $str;
}

use constant HEARTBEAT_INTERVAL => 0.1;

use constant TYPE_PLATE => 0x20;
use constant TYPE_WANT_HEARTBEAT => 0x40;
use constant TYPE_NEW_CAMERA => 0x80;
use constant TYPE_NEW_DISPATCHER => 0x81;

use constant TYPE_ERROR => 0x10;
use constant TYPE_TICKET => 0x21;
use constant TYPE_HEARTBEAT => 0x41;

sub parse_plate ($self, $message, $offset)
{
	my %ret;
	$ret{plate} = dec_str($message, $offset);
	$ret{timestamp} = dec_uint(32 => $message, $offset);

	return \%ret;
}

sub parse_want_heartbeat ($self, $message, $offset)
{
	my %ret;
	$ret{interval} = dec_uint(32 => $message, $offset);

	return \%ret;
}

sub parse_new_camera ($self, $message, $offset)
{
	my %ret;
	$ret{road_id} = dec_uint(16 => $message, $offset);
	$ret{mile} = dec_uint(16 => $message, $offset);
	$ret{limit} = dec_uint(16 => $message, $offset);

	return \%ret;
}

sub parse_new_dispatcher ($self, $message, $offset)
{
	my %ret = (roads => []);
	my $numroads = dec_uint(8 => $message, $offset);
	while ($numroads--) {
		push $ret{roads}->@*, dec_uint(16 => $message, $offset);
	}

	return \%ret;
}

sub try_parse_message ($self, $session, $message, $offset)
{
	state %types = (
		(TYPE_PLATE) => \&parse_plate,
		(TYPE_WANT_HEARTBEAT) => \&parse_want_heartbeat,
		(TYPE_NEW_CAMERA) => \&parse_new_camera,
		(TYPE_NEW_DISPATCHER) => \&parse_new_dispatcher,
	);

	my $offset_snapshot = $$offset;
	my $type = dec_uint(8 => $message, $offset);
	if (!$types{$type}) {
		$self->raise_error($session, "invalid message type $type", !!0);
		return !!1;
	}

	try {
		my $data = $types{$type}->($self, $message, $offset);
		$data->{type} = $type;
		return $data;
	}
	catch ($e) {
		$$offset = $offset_snapshot;
		return undef;
	}
}

sub dispatch_error ($self, $data)
{
	return enc_str($data);
}

sub dispatch_ticket ($self, $data)
{
	return
		enc_str($data->{plate})
		. enc_uint(16 => $data->{road})
		. enc_uint(16 => $data->{mile1})
		. enc_uint(32 => $data->{timestamp1})
		. enc_uint(16 => $data->{mile2})
		. enc_uint(32 => $data->{timestamp2})
		. enc_uint(16 => int($data->{speed} * 100))
		;
}

sub dispatch_heartbeat ($self, $)
{
	return '';
}

sub dispatch ($self, $session, $type, $data)
{
	state %types = (
		(TYPE_ERROR) => \&dispatch_error,
		(TYPE_TICKET) => \&dispatch_ticket,
		(TYPE_HEARTBEAT) => \&dispatch_heartbeat,
	);

	$self->raise_error("invalid outbound message type $type") unless $types{$type};
	$session->write(chr($type) . $types{$type}->($self, $data));
}

sub raise_error ($self, $session, $message, $raise = !!1)
{
	$self->dispatch($session, TYPE_ERROR, $message);
	die "Client error: $message" if $raise;
}

sub react ($self, $session, $data)
{
	weaken $self;
	my $id = $session->id;

	if ($data->{type} eq TYPE_NEW_CAMERA) {
		$self->raise_error($session, 'device already registered')
			if $session->data->{device};

		$session->data->{device} = $self->system->add_camera($id, $data);
		$self->log->debug('registering camera for road ' . $data->{road_id});
	}
	elsif ($data->{type} eq TYPE_NEW_DISPATCHER) {
		$self->raise_error($session, 'device already registered')
			if $session->data->{device};

		$data->{on_ticket} = sub ($data) { $self->dispatch($session, TYPE_TICKET, $data) };
		$session->data->{device} = $self->system->add_dispatcher($id, $data);
		$self->log->debug('registering dispatcher for roads: ' . join ', ', $data->{roads}->@*);
	}
	elsif ($data->{type} eq TYPE_WANT_HEARTBEAT) {
		if ($session->data->{heartbeat}) {
			$self->raise_error($session, 'zero heartbeat')
				unless $data->{interval} == 0;

			$self->server->loop->remove($session->data->{heartbeat});
		}
		elsif ($data->{interval} > 0) {
			$session->data->{heartbeat} = $self->server->loop->recurring(
				HEARTBEAT_INTERVAL * $data->{interval},
				sub {
					$self->dispatch($session, TYPE_HEARTBEAT, undef);
				}
			);
		}
	}
	elsif ($data->{type} eq TYPE_PLATE) {
		my $camera = $self->system->cameras->{$id};

		$self->raise_error($session, 'device is not a camera')
			unless $camera;

		$camera->plate($data->{plate}, $data->{timestamp});
	}
}

sub connected ($self, $session)
{
	$session->timeout(60);
	$session->data->{buffer} = '';
	$session->data->{device} = undef;
	$session->data->{heartbeat} = undef;
	return;
}

sub disconnected ($self, $session)
{
	if ($session->data->{heartbeat}) {
		$self->server->loop->remove($session->data->{heartbeat});
	}

	if ($session->data->{device}) {
		$self->system->remove_device($session->id);
	}

	$self->log->debug("session " . $session->id . " had extra data: " . unpack 'H*', $session->data->{buffer})
		unless $session->data->{buffer} eq '';

	return $self->SUPER::disconnected($session);
}

sub process_message ($self, $session, $message)
{
	$session->data->{buffer} .= $message;
	while (my $buffer = $session->data->{buffer}) {
		try {
			my $offset = 0;
			my $ret = $self->try_parse_message($session, $buffer, \$offset);
			$session->data->{buffer} = substr $buffer, $offset;

			if (ref $ret) {
				$self->react($session, $ret);
			}
			elsif ($ret) {
				next;
			}
			else {
				last;
			}
		}
		catch ($e) {
			$self->log->debug("Caught error: $e");
		}
	}
	return;
}

