package ServerMock;

use v5.42;

use Mojo::IOLoop;

use Mooish::Base;

has field 'loop' => (
	default => sub { Mojo::IOLoop->singleton },
);

