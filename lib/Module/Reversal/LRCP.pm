package Module::Reversal::LRCP;

use v5.42;

use DI;
use Module::Reversal::LRCP::Session;
use Module::Reversal::LRCP::X::IncorrectMessage;
use List::Util qw(min);

use Mooish::Base;

use constant PROTOCOL_SEP => '/';
use constant PROTOCOL_ESC => '\\';
use constant PROTOCOL_ESC_MAGIC => "\x00\x21\x37\x00";
use constant PROTOCOL_MAX_MESSAGE_LENGTH => 1000 - 1;
use constant LRCPLength => StrLength [0, PROTOCOL_MAX_MESSAGE_LENGTH];
use constant LRCPNumber => IntRange[0, 2147483648 - 1];

has field 'log' => (
	DI->injected('log')
);

has field 'sessions' => (
	isa => HashRef [InstanceOf ['Module::Reversal::LRCP::Session']],
	default => sub { {} },
);

my sub make ($self, @parts)
{
	state $sep = PROTOCOL_SEP;
	state $esc = PROTOCOL_ESC;

	foreach my $part (@parts) {
		$part =~ s{\Q$esc\E}{$esc$esc}g;
		$part =~ s{\Q$sep\E}{$esc$sep}g;
	}

	return (join PROTOCOL_SEP, '', @parts, '');
}

my sub make_data ($self, $id, $offset, $up_to, $data)
{
	state $max_len = int(PROTOCOL_MAX_MESSAGE_LENGTH / 2);

	return $self->&make('data', $id, $offset, substr $data, $offset, min $max_len, $up_to - $offset);
}

sub validate_message_connect ($self, @parts)
{
	Module::Reversal::LRCP::X::IncorrectMessage->throw('bad connect request')
		unless @parts == 1 && LRCPNumber->check($parts[0]);
}

sub handle_message_connect ($self, $id)
{
	my $session = $self->sessions->{$id} //= Module::Reversal::LRCP::Session->new;
	return $self->&make('ack', $id, $session->data_len);
}

sub validate_message_close ($self, @parts)
{
	Module::Reversal::LRCP::X::IncorrectMessage->throw('bad close request')
		unless @parts == 1 && LRCPNumber->check($parts[0]);
}

sub handle_message_close ($self, $id)
{
	delete $self->sessions->{$id};
	return $self->&make('close', $id);
}

sub validate_message_data ($self, @parts)
{
	Module::Reversal::LRCP::X::IncorrectMessage->throw('bad data request')
		unless @parts == 3
		&& LRCPNumber->check($parts[0])
		&& LRCPNumber->check($parts[1])
		&& length $parts[2];
}

sub handle_message_data ($self, $id, $pos, $data)
{
	my $session = $self->sessions->{$id};
	if (!$session) {
		return $self->&make('close', $id);
	}

	$session->add_data($pos, $data);
	return $self->&make('ack', $id, $session->data_len);
}

sub validate_message_ack ($self, @parts)
{
	Module::Reversal::LRCP::X::IncorrectMessage->throw('bad ack request')
		unless @parts == 2
		&& LRCPNumber->check($parts[0])
		&& LRCPNumber->check($parts[1]);
}

sub handle_message_ack ($self, $id, $size)
{
	my $session = $self->sessions->{$id};
	if (!$session) {
		return $self->&make('close', $id);
	}

	# already received
	if ($session->ack_bytes >= $size) {
		return ();
	}

	$session->set_ack_bytes($size);

	# peer misbehaving
	if ($size > $session->sent_bytes) {
		return $self->handle_message_close($id);
	}

	# send next packet
	if ($size < $session->sent_bytes) {
		return $self->send_buffer($id);
	}

	return ();
}

sub handle_message ($self, $message)
{
	try {
		Module::Reversal::LRCP::X::IncorrectMessage->throw('bad length')
			unless LRCPLength->check($message);

		state $sep = quotemeta PROTOCOL_SEP;
		state $esc = quotemeta PROTOCOL_ESC;
		state $escmagic = quotemeta PROTOCOL_ESC_MAGIC;
		state $splitsep = qr{(*nlb:$escmagic)$sep};

		$message =~ s{(($esc){1, 2})}{length $1 == 2 ? PROTOCOL_ESC : PROTOCOL_ESC_MAGIC}ge;
		my @parts = split $splitsep, $message, -1;
		@parts = map { s{$escmagic}{}gr } @parts;

		my $empty_front = shift @parts;
		my $empty_back = pop @parts;
		my $type = shift @parts;

		Module::Reversal::LRCP::X::IncorrectMessage->throw('bad message')
			if length $empty_front || length $empty_back;
		Module::Reversal::LRCP::X::IncorrectMessage->throw('bad type')
			unless $type;

		my $handle_method = $self->can("handle_message_$type");
		my $validate_method = $self->can("validate_message_$type");
		Module::Reversal::LRCP::X::IncorrectMessage->throw('bad type')
			unless $handle_method;

		$self->$validate_method(@parts)
			if $validate_method;
		return $self->$handle_method(@parts);
	}
	catch ($e) {
		die $e
			unless $e isa 'Module::Reversal::LRCP::X::IncorrectMessage';

		$self->log->debug($e);
		# ignore incorrect messages
		return ();
	}
}

sub mark_session_send ($self, $id, $len = undef)
{
	my $session = $self->sessions->{$id};
	$session->set_sent_bytes($len // $session->data_len);
}

sub send_buffer ($self, $id)
{
	my $session = $self->sessions->{$id};
	return $self->&make_data($id, $session->ack_bytes, $session->sent_bytes, $session->data);
}

