package Server::Session;

use class;

has param 'server' => (
	isa => InstanceOf ['Server'],
	weak_ref => 1,
	handles => [
		'log'
	],
);

has param 'stream' => (
	handles => [
		'write',
	],
);

has param 'on_dropped' => (
	isa => CodeRef,
);

has field 'session_data' => (
	isa => HashRef,
	default => sub { {} },
);

with qw(
	Role::HasId
);

sub BUILD ($self, $)
{
	$self->log->debug('New TCP connection #' . $self->id . ' from ' . $self->stream->handle->peerhost);
	my $module = $self->server->module;

	# react to tcp events
	my $stream = $self->stream;
	$stream->on(read => sub ($, $bytes) { $module->process_message($self, $bytes) });
	$stream->on(close => sub { $self->dropped });
	$stream->on(error => sub ($, $err) { $self->log->error("TCP Error: $err") });
	$stream->timeout($module->timeout);

	return;
}

sub dropped ($self)
{
	$self->log->debug('Dropped connection #' . $self->id);
	$self->on_dropped->();

	return;
}

