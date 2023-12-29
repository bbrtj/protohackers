package UDPServerMock;

use class;

has field '_written' => (
	lazy => sub { [] },
	clearer => 1,
);

sub write ($self, $bytes)
{
	push $self->_written->@*, $bytes;
}

