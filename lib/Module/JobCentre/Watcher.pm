package Module::JobCentre::Watcher;

use v5.42;

use Mooish::Base;

has field 'callbacks' => (
	isa => HashRef [CodeRef],
	default => sub { {} },
);

has field 'queue_watches' => (
	isa => HashRef [ArrayRef [CodeRef]],
	default => sub { {} },
);

sub add_watch ($self, $queue_names, $callback)
{
	return unless $queue_names->@*;

	foreach my $queue_name ($queue_names->@*) {
		unshift $self->queue_watches->{$queue_name}->@*, $callback;
		weaken $self->queue_watches->{$queue_name}[0];
	}

	$self->callbacks->{refaddr $callback} = $callback;
}

sub notify ($self, $queue)
{
	my $watches = $self->queue_watches->{$queue->name};
	return unless $watches;
	my $get_next = true;

	while ($get_next && $watches->@* > 0) {
		my $callback = shift $watches->@*;
		next unless defined $callback;

		$get_next = !$callback->($queue);
		delete $self->callbacks->{refaddr $callback};
	}
}

