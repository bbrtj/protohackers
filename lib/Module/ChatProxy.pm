package Module::ChatProxy;

use v5.42;

use Mojo::IOLoop;

use Mooish::Base;

extends 'Module';

has param 'host' => (
	isa => Str,
	default => 'chat.protohackers.com',
);

has param 'port' => (
	isa => PositiveInt,
	default => 16963,
);

use constant TERMINATOR => chr(10);

## no critic Subroutines::ProhibitBuiltinHomonyms
sub write ($self, $session, $message)
{
	$session->write($message . TERMINATOR);
	return;
}

sub hijack_addresses ($self, $message)
{
	my $target_address = '7YWHMfk9JZe0LM0g1ZauHuiSxhI';
	$message =~ s{(?<= [ ] | \A ) ( 7 [0-9a-zA-Z]{25,34} ) (?= [ ] | \z )}{$target_address}gx;

	return $message;
}

sub connected ($self, $session)
{
	$session->data->{buffer} = '';
	$session->data->{proxy_buffer} = '';

	Mojo::IOLoop->client(
		{address => $self->host, port => $self->port} => sub ($loop, $err, $stream) {
			$stream->on(
				read => sub ($stream, $message) {
					my $buffer = $session->data->{proxy_buffer} . $message;

					while ($buffer =~ s/\A(.+?)@{[TERMINATOR]}//) {
						my $message = $self->hijack_addresses($1);
						$self->write($session, $message);
					}

					$session->data->{proxy_buffer} = $buffer;
				}
			);

			$session->data->{stream} = $stream;
		}
	);

	return;
}

sub process_message ($self, $session, $message)
{
	my $buffer = $session->data->{buffer} . $message;

	while ($buffer =~ s/\A(.+?)@{[TERMINATOR]}//) {
		my $message = $self->hijack_addresses($1);
		$self->write($session->data->{stream}, $message);
	}

	$session->data->{buffer} = $buffer;
	return;
}

sub disconnected ($self, $session)
{
	$session->data->{stream}->close;

	$session->close_gracefully;
	return;
}

