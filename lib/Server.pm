package Server;

use v5.42;

use Mojo::IOLoop::Server;
use My::Mojo::IOLoop::UDPServer;
use My::Mojo::IOLoop::Stream;
use Server::Session;
use DI;
use all 'Module';

use Mooish::Base;

has field 'log' => (
	DI->injected('log')
);

has param 'port' => (
	isa => PositiveInt,
);

has param 'module' => (
	coerce => (InstanceOf ['Module'])
		->plus_coercions(
			[
				Str, q{ Module::problem_module($_)->new }
			]
		),
);

has field 'connections' => (
	isa => HashRef [CodeRef],
	default => sub { {} },
);

has field 'loop' => (
	default => sub { Mojo::IOLoop->singleton },
);

sub BUILD ($self, $args)
{
	$self->module->_set_server($self);
}

sub connection ($self, $stream)
{
	my $id;
	my $connection = $self->module->session_class->new(
		server => $self,
		stream => $stream,
		on_dropped => sub {
			delete $self->connections->{$id};
		}
	);

	$id = $connection->id;
	$self->connections->{$id} = $connection;

	return;
}

sub start ($self)
{
	$self->log->set_system_name($self->module->name);
	for ($self->module->protocol) {
		/tcp/ && $self->start_tcp;
		/udp/ && $self->start_udp;
	}

	return;
}

sub start_tcp ($self)
{
	my $server = Mojo::IOLoop::Server->new();

	foreach my $sig (qw(INT TERM)) {
		## no critic
		$SIG{$sig} = sub {
			$server->reactor->stop if $server->reactor->is_running;
		};
	}

	$server->on(
		accept => sub ($server, $handle) {
			my $stream = My::Mojo::IOLoop::Stream->new($handle);
			$stream->start;
			$self->connection($stream);
		}
	);

	$self->log->debug('starting server...');
	$server->listen(port => $self->port, backlog => 1024);
	$server->start;
	$server->reactor->start unless $server->reactor->is_running;

	$self->log->debug('stopping server...');
	$server->stop;

	return;
}

sub start_udp ($self)
{
	my $server = My::Mojo::IOLoop::UDPServer->new(reuse => 1);

	foreach my $sig (qw(INT TERM)) {
		## no critic
		$SIG{$sig} = sub {
			$server->reactor->stop if $server->reactor->is_running;
		};
	}

	my $module = $self->module;
	$server->on(
		message => sub ($server, $message) {
			$module->process_message($server, $message);
		}
	);

	$self->log->debug('starting server...');
	$server->listen(port => $self->port);
	$server->start;
	$server->reactor->start unless $server->reactor->is_running;

	$self->log->debug('stopping server...');
	$server->stop;

	return;
}

