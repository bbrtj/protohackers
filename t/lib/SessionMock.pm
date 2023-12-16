package SessionMock;

use class;

has field 'data' => (
	isa => HashRef,
	default => sub { {} },
);

has field '_closed' => (
	writer => 1,
	default => !!0,
);

has field '_written' => (
	default => sub { [] },
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

