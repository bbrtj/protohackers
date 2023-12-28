package Server;

use Mojo::IOLoop::Server;
use My::Mojo::IOLoop::Stream;
use Server::Session;
use all 'Module';

use class;

has injected 'log';

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
	my $server = Mojo::IOLoop::Server->new(reuse => 1);

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
	$server->listen(port => $self->port);
	$server->start;
	$server->reactor->start unless $server->reactor->is_running;

	$self->log->debug('stopping server...');
	$server->stop;

	return;
}

