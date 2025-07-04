package My::Mojo::IOLoop::Stream;
use Mojo::Base 'Mojo::IOLoop::Stream';

use Errno qw(EAGAIN ECONNRESET EINTR EWOULDBLOCK);
has read_eof => 0;

sub eof
{
	my $self = shift;

	$self->read_eof(1);
	$self->emit('eof');
}

sub _read
{
	my $self = shift;

	return $self if $self->read_eof;
	if (defined(my $read = $self->{handle}->sysread(my $buffer, 131072, 0))) {
		$self->{read} += $read;
		return $read == 0 ? $self->eof : $self->emit(read => $buffer)->_again;
	}

	# Retry
	return undef if $! == EAGAIN || $! == EINTR || $! == EWOULDBLOCK;

	# Closed (maybe real error)
	$! == ECONNRESET ? $self->close : $self->emit(error => $!)->close;
}

1;

