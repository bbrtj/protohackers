package SessionMock;

use v5.42;

use Mooish::Base;

my $last_id = 0;
has field 'id' => (
	default => sub { ++$last_id },
);

has field 'data' => (
	isa => HashRef,
	default => sub { {} },
);

has field '_closed' => (
	writer => 1,
	default => !!0,
);

has field '_written' => (
	lazy => sub { [] },
	clearer => 1,
);

has 'timeout' => (
	is => 'rw',
);

sub close ($self)
{
	$self->_set_closed(!!1);
}

sub close_gracefully ($self)
{
	$self->close;
}

sub write ($self, $bytes)
{
	push $self->_written->@*, $bytes;
}

