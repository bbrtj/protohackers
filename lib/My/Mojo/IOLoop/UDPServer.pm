package My::Mojo::IOLoop::UDPServer;
use Mojo::Base 'Mojo::EventEmitter';

use Carp qw(croak);
use IO::Socket::IP;

has reactor => sub { Mojo::IOLoop->singleton->reactor }, weak => 1;

sub listen
{
	my ($self, $args) = (shift, ref $_[0] ? $_[0] : {@_});

	my $address = $args->{address} || '0.0.0.0';
	my $port = $args->{port};

	my %options;
	$options{Proto} = 'udp';
	$options{LocalAddr} = $address;
	$options{LocalAddr} =~ y/[]//d;
	$options{LocalPort} = $port if $port;
	my $handle = IO::Socket::IP->new(%options) or croak "Can't create listen socket: $@";
	$handle->blocking(0);
	@$self{qw(args handle)} = ($args, $handle);
}

sub start
{
	my ($self) = @_;

	$self->reactor->io($self->{handle} => sub { $self->_accept })->watch($self->{handle}, 1, 0);
}

sub stop
{
	my ($self) = @_;

	$self->reactor->remove($self->{handle});
}

sub _accept
{
	my ($self) = @_;

	$self->{handle}->recv(my $buffer, 131072);
	$self->emit(message => $buffer);
}

sub write
{
	my ($self, $data) = @_;

	if (length $data) {
		$self->{handle}->send($data, 131072);
	}
	return;
}

1;

