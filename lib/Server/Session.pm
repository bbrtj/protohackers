package Server::Session;

use v5.42;

use Mooish::Base;

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
		'close',
		'close_gracefully',
		'timeout',
	],
);

has param 'on_dropped' => (
	isa => CodeRef,
);

has field 'data' => (
	isa => HashRef,
	default => sub { {} },
);

with qw(
	Role::HasId
);

sub _dropped ($self)
{
	$self->log->debug('Dropped connection #' . $self->id);
	$self->on_dropped->();

	return;
}

sub BUILD ($self, $)
{
	$self->log->debug('New TCP connection #' . $self->id . ' from ' . $self->stream->handle->peerhost);
	my $module = $self->server->module;

	# react to tcp events
	my $stream = $self->stream;
	$stream->on(read => sub ($, $bytes) { $module->process_message($self, $bytes) });
	$stream->on(eof => sub ($) { $module->disconnected($self) });
	$stream->on(close => sub { $self->_dropped });
	$stream->on(error => sub ($, $err) { $self->log->error("TCP Error: $err") });
	$module->connected($self);

	return;
}

