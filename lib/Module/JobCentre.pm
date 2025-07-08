package Module::JobCentre;

use v5.42;

use DI;
use X::BadData;
use List::Util qw(first);
use Mojo::JSON qw(encode_json decode_json);

use Module::JobCentre::Queue;
use Module::JobCentre::Watcher;

use Mooish::Base;

# NOTE: this module requires increasing kern.ipc.somaxconn on FreeBSD to 1024
# NOTE: this module should be run with USE_UV env var

extends 'Module';

has field 'numid_gen' => (
	DI->injected('numid_gen')
);

has field 'queues' => (
	isa => HashRef [InstanceOf ['Module::JobCentre::Queue']],
	default => sub { {} },
);

has field 'watcher' => (
	isa => InstanceOf ['Module::JobCentre::Watcher'],
	default => sub { Module::JobCentre::Watcher->new },
);

my sub respond ($self, $session, $data)
{
	$session->write(encode_json($data) . "\n");
}

my sub handle_put ($self, $session, $data)
{
	state $validator = Dict [
		queue => Str,
		job => HashRef,
		pri => PositiveOrZeroInt,
	];

	X::BadData->throw('bad put request data format')
		unless $validator->check($data);

	$data->{id} = $self->numid_gen->next_id;
	$self->&respond($session, {status => 'ok', id => $data->{id}});
	$self->get_queue(delete $data->{queue})->add($data);
}

my sub handle_get ($self, $session, $data)
{
	state $validator = Dict [
		queues => (ArrayRef [Str])->where(q{ $_->@* > 0 }),
		wait => Optional [InstanceOf ['JSON::PP::Boolean']],
	];

	X::BadData->throw('bad get request data format')
		unless $validator->check($data);

	my $max_priority;
	my $max_priority_queue;
	foreach my $queue ($data->{queues}->@*) {
		my $this_item = $self->get_queue($queue)->peek;
		if (defined $this_item && (!defined $max_priority || $this_item->{pri} > $max_priority)) {
			$max_priority = $this_item->{pri};
			$max_priority_queue = $queue;
		}
	}

	my sub handle_response ($queue)
	{
		return false unless $session->data->{connected};
		my %item = $queue->take->%*;
		$item{queue} = $queue->name;
		$item{status} = 'ok';

		push $session->data->{taken_jobs}->@*, $item{id};
		$self->&respond($session, \%item);
		return true;
	}

	if (defined $max_priority_queue) {
		handle_response($self->get_queue($max_priority_queue));
	}
	elsif ($data->{wait}) {
		$self->watcher->add_watch(
			$data->{queues},
			sub ($queue) {
				return handle_response($queue);
			}
		);
	}
	else {
		$self->&respond($session, {status => 'no-job'});
	}

}

my sub handle_delete ($self, $session, $data)
{
	state $validator = Dict [
		id => PositiveInt,
	];

	X::BadData->throw('bad delete request data format')
		unless $validator->check($data);

	my $id = $data->{id};
	my $queue = first { $_->has_job($id) } values $self->queues->%*;

	if (defined $queue) {
		$queue->remove($id);
		$self->&respond($session, {status => 'ok'});
	}
	else {
		$self->&respond($session, {status => 'no-job'});
	}
}

my sub abort ($self, $id)
{
	my $queue = first { $_->has_job($id) } values $self->queues->%*;

	return false
		unless defined $queue;

	$queue->restore($id);
	return true;
}

my sub handle_abort ($self, $session, $data)
{
	state $validator = Dict [
		id => PositiveInt,
	];

	X::BadData->throw('bad abort request data format')
		unless $validator->check($data);

	my $id = $data->{id};
	my $job_arr = $session->data->{taken_jobs};
	my $job_count = $job_arr->@*;
	$job_arr->@* = grep { $_ ne $id } $job_arr->@*;

	X::BadData->throw('job not taken by this client')
		unless $job_count > $job_arr->@*;

	if ($self->&abort($id)) {
		$self->&respond($session, {status => 'ok'});
	}
	else {
		$self->&respond($session, {status => 'no-job'});
	}
}

sub connected ($self, $session)
{
	$session->timeout(60);
	$session->data->{connected} = true;
	$session->data->{buffer} = '';
	$session->data->{taken_jobs} = [];
	return;
}

sub disconnected ($self, $session)
{
	$session->data->{connected} = false;

	foreach my $id ($session->data->{taken_jobs}->@*) {
		$self->&abort($id);
	}
}

sub get_queue ($self, $name)
{
	return $self->queues->{$name} //= Module::JobCentre::Queue->new(
		name => $name,
		watcher => $self->watcher,
	);
}

sub handle_packet ($self, $session, $data)
{
	state %known_types = (
		put => \&handle_put,
		get => \&handle_get,
		delete => \&handle_delete,
		abort => \&handle_abort,
	);

	my $decoded;
	try {
		$decoded = decode_json($data);
	}
	catch ($e) {
		X::BadData->throw('bad json');
	}

	X::BadData->throw('bad input format') unless ref $decoded eq 'HASH';

	my $type = delete $decoded->{request};
	X::BadData->throw('bad request type') unless $type && exists $known_types{$type};

	$known_types{$type}->($self, $session, $decoded);
}

sub process_message ($self, $session, $message)
{
	$session->data->{buffer} .= $message;
	while ($session->data->{buffer} =~ s/^(.*?)\n//) {
		try {
			my $data = $1;
			$self->log->debug("new packet: $data");
			$self->handle_packet($session, $data);
		}
		catch ($e) {
			$self->log->debug("Caught exception: $e");

			if ($e isa 'X::ShouldDisconnect') {
				$session->close_gracefully;
				last;
			}
			elsif ($e isa 'X::BadData') {
				$self->&respond($session, {status => 'error', error => $e->msg});
			}
		}
	}
}

