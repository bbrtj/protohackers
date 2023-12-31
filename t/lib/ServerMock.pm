package ServerMock;

use Mojo::IOLoop;

use class;

has field 'loop' => (
	default => sub { Mojo::IOLoop->singleton },
);

