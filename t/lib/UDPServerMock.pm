package UDPServerMock;

use v5.42;

use Mooish::Base;

extends 'My::Mojo::IOLoop::UDPServer';

has field '_written' => (
	lazy => sub { [] },
	clearer => 1,
);

sub write ($self, $bytes)
{
	push $self->_written->@*, $bytes;
}

