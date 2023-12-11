package Server;

use Mojo::IOLoop;
use Server::Session;
use all 'Server::Module';

use class;

has injected 'log';

has param 'port' => (
	isa => PositiveInt,
);

has param 'module' => (
	coerce => (InstanceOf ['Server::Module'])
		->plus_coercions(
			[
				Str, q{ Server::Module::problem_module($_)->new }
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
	my $connection = Server::Session->new(
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
	$self->log->debug('starting server...');

	foreach my $sig (qw(INT TERM)) {
		## no critic
		$SIG{$sig} = sub {
			Mojo::IOLoop->stop;
		};
	}

	Mojo::IOLoop->server(
		{
			port => $self->port,
			reuse => 1,
		} => sub ($, $stream, $) {
			$self->connection($stream);
		}
	);

	Mojo::IOLoop->start;
	$self->log->debug('stopping server...');

	return;
}

