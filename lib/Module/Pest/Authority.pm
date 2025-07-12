package Module::Pest::Authority;

use v5.42;

use DI;
use Module::Pest::Protocol qw(encode_message decode_message);
use My::Mojo::IOLoop::Stream;
use List::Util qw(first);
use Carp qw(croak);
use Data::Dumper;

use Mooish::Base;

has field 'log' => (
	DI->injected('log'),
);

has param 'site' => (
	isa => Int,
	writer => 1,
);

has param 'client' => (
);

has field '_buffer' => (
	default => sub { '' },
	writer => 1,
);

has field '_stream' => (
	isa => InstanceOf ['My::Mojo::IOLoop::Stream'],
	writer => 1,
);

# species => { min, max }
has field 'target_populations' => (
	isa => HashRef,
	writer => 1,
);

# species => [hash, hash, ...]
has field 'policies' => (
	isa => HashRef,
	default => sub { {} },
);

has field '_message_queue' => (
	isa => ArrayRef [HashRef],
	default => sub { [] },
);

has field '_ready' => (
	isa => Bool,
	writer => 1,
	default => false,
);

has field '_on_ready' => (
	isa => CodeRef,
	writer => 1,
	predicate => 1,
	clearer => 1,
);

has field 'alive' => (
	isa => Bool,
	default => true,
	writer => 1,
);

sub BUILD ($self, @)
{
	$self->client->on(connect => sub { $self->setup(@_) });

	push $self->_message_queue->@*,
		{
			message => {
				name => 'hello',
			},
			expected => 'hello',
		},
		{
			message => {
				name => 'dial_authority',
				site => $self->site,
			},
			expected => 'target_populations',
		};
}

sub setup ($self, $, $handle)
{
	weaken $self;

	# try keep this stream open as long as possible
	my $stream = My::Mojo::IOLoop::Stream->new($handle);
	$stream->timeout(600);
	$self->_set_stream($stream);
	$stream->start;

	# assume we always get one full packet per message (since there is nothing
	# separating the messages)
	$stream->on(
		read => sub ($, $bytes) {
			$self->process_message($bytes);
		}
	);

	$stream->on(eof => sub { $self->set_alive(false) });
	$stream->on(close => sub { $self->set_alive(false) });

	$self->_try_push_queue;
}

sub process_message ($self, $message)
{
	$self->_set_buffer($self->_buffer . $message);

	while (length $self->_buffer) {
		try {
			my $pos = 0;
			my $data = decode_message($self->_buffer, \$pos);
			$self->_set_buffer(substr $self->_buffer, $pos);

			$self->received($data);
		}
		catch ($e) {
			if ($e isa 'X::PartialData') {
				last;
			}

			if ($e isa 'X::BadData') {
				$self->send(
					{
						name => 'error',
						message => $e->msg,
					}
				);
			}

			$self->log->debug("$e");
			$self->stream->close_gracefully;
			last;
		}
	}
}

sub send ($self, $message)
{
	$self->log->debug('auth ' . $self->site . ' <-- ' . Dumper($message));
	$self->_stream->write(encode_message($message));
}

sub _try_push_queue ($self)
{
	my $next = $self->_message_queue->[0];

	return unless defined $next;
	return unless defined $next->{message};

	$self->send(delete $next->{message});
}

sub policy_commit ($self, $species, $id)
{
	my $policies = $self->policies->{$species};
	my $policy = first { $_->{action} ne 'inaction' && !defined $_->{id} } $policies->@*;
	$policy->{id} = $id;

	$self->policy_unset($species);
	$self->_try_push_queue;
}

sub policy_set ($self, $species, $action)
{
	push $self->_message_queue->@*, {
		message => {
			name => 'create_policy',
			species => $species,
			action => $action,
		},
		expected => 'policy_result',
		species => $species,
		action => $action,
	} unless $action eq 'inaction';

	push $self->policies->{$species}->@*, {
		action => $action,
	};
}

sub policy_unset ($self, $species)
{
	my $policies = $self->policies->{$species};

	for my $ind (reverse 0 .. $policies->$#* - 1) {
		my $policy = $policies->[$ind];

		if ($policy->{action} ne 'inaction') {
			next unless defined $policy->{id};

			push $self->_message_queue->@*, {
				message => {
					name => 'delete_policy',
					policy => $policy->{id},
				},
				expected => 'ok',
				species => $species,
			};
		}

		splice $policies->@*, $ind, 1;
	}
}

sub set_policy ($self, $policy)
{
	if (defined $policy->{action}) {
		$self->policy_set($policy->{species}, $policy->{action});
	}

	$self->_try_push_queue;
}

sub received ($self, $message)
{
	$self->log->debug('auth ' . $self->site . ' --> ' . Dumper($message));
	my $next = $self->_message_queue->[0];

	die "got error: $message->{message}" if $message->{name} eq 'error';
	X::BadData->throw('unexpected message') unless defined $next;
	X::BadData->throw('not yet expecting data') if defined $next->{message};
	X::BadData->throw("expected $next->{expected}, not $message->{name}") unless $next->{expected} eq $message->{name};
	shift $self->_message_queue->@*;

	if ($message->{name} eq 'hello') {

		# do nothing
	}
	elsif ($message->{name} eq 'target_populations') {
		my @populations = $message->{populations}->@*;
		$self->set_target_populations({map { delete $_->{species} => $_ } @populations});

		# open for business
		$self->_set_ready(true);
		if ($self->_has_on_ready) {
			$self->run($self->_on_ready);
			$self->_clear_on_ready;
		}
	}
	elsif ($message->{name} eq 'policy_result') {
		$self->policy_commit($next->{species}, $message->{policy});
	}
	elsif ($message->{name} eq 'ok') {

		# nothing
	}
	else {
		X::BadData->throw("unsupported authority message $message->{name}");
	}

	$self->_try_push_queue;
}

sub run ($self, $cb)
{
	return $cb->($self)
		if $self->_ready;

	if ($self->_has_on_ready) {
		my $old_cb = $self->_on_ready;
		my $new_cb = $cb;
		$cb = sub {
			$old_cb->(@_);
			$new_cb->(@_);
		};
	}

	$self->_set_on_ready($cb);
}

