package Module::Reversal::LRCP;

use v5.42;

use DI;
use Module::Reversal::LRCP::Session;
use Module::Reversal::LRCP::X::IncorrectMessage;
use List::Util qw(min);

use Mooish::Base;

use constant PROTOCOL_RETRANSMISSION => 3;
use constant PROTOCOL_DISCONNECTION => 60;
use constant PROTOCOL_SEP => '/';
use constant PROTOCOL_ESC => '\\';
use constant PROTOCOL_ESC_MAGIC => "\x00\x21\x37\x00";
use constant PROTOCOL_MAX_MESSAGE_LENGTH => 1000 - 1;
use constant LRCPLength => StrLength [0, PROTOCOL_MAX_MESSAGE_LENGTH];
use constant LRCPNumber => IntRange [0, 2147483648 - 1];

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
	state $step = int(PROTOCOL_MAX_MESSAGE_LENGTH / 10);

	for (my $max_len = PROTOCOL_MAX_MESSAGE_LENGTH - $step ; $max_len > $step ; $max_len -= $step) {
		my $out = $self->&make('data', $id, $offset, substr $data, $offset, min $max_len, $up_to - $offset);
		return $out if LRCPLength->check($out);
	}

	die 'could not make_data - bad config?';
}

sub validate_message_connect ($self, @parts)
{
	Module::Reversal::LRCP::X::IncorrectMessage->throw('bad connect request')
		unless @parts == 1 && LRCPNumber->check($parts[0]);
}

sub handle_message_connect ($self, $server, $id)
{
	my $session = $self->sessions->{$id} //= Module::Reversal::LRCP::Session->new(
		server => $server,
		disconnection_sub => sub { $self->handle_message_close($server, $id) },
	);

	$session->write($self->&make('ack', $id, $session->data_len));
}

sub validate_message_close ($self, @parts)
{
	Module::Reversal::LRCP::X::IncorrectMessage->throw('bad close request')
		unless @parts == 1 && LRCPNumber->check($parts[0]);
}

sub handle_message_close ($self, $server, $id)
{
	$self->sessions->{$id}->end_session;
	delete $self->sessions->{$id};
	$server->write($self->&make('close', $id));
}

sub validate_message_data ($self, @parts)
{
	Module::Reversal::LRCP::X::IncorrectMessage->throw('bad data request')
		unless @parts == 3
		&& LRCPNumber->check($parts[0])
		&& LRCPNumber->check($parts[1])
		&& length $parts[2];
}

sub handle_message_data ($self, $server, $id, $pos, $data)
{
	my $session = $self->sessions->{$id};
	if (!$session) {
		$server->write($self->&make('close', $id));
		return;
	}

	$self->log->debug(sprintf 'got data of length %s at pos %s from session %s', length $data, $pos, $id);
	$session->add_data($pos, $data);
	$session->write($self->&make('ack', $id, $session->data_len));
}

sub validate_message_ack ($self, @parts)
{
	Module::Reversal::LRCP::X::IncorrectMessage->throw('bad ack request')
		unless @parts == 2
		&& LRCPNumber->check($parts[0])
		&& LRCPNumber->check($parts[1]);
}

sub handle_message_ack ($self, $server, $id, $size)
{
	my $session = $self->sessions->{$id};
	if (!$session) {
		$server->write($self->&make('close', $id));
		return;
	}

	# already received
	if ($session->ack_bytes >= $size) {
		return;
	}

	$session->set_ack_bytes($size);

	# peer misbehaving
	if ($size > $session->sent_bytes) {
		$self->handle_message_close($server, $id);
		return;
	}

	$session->cancel_disconnection;

	# send next packet (and cancel retransmission)
	if ($size < $session->sent_bytes) {
		$self->send_buffer($id);
		return;
	}

	# all well, cancel retransmission
	$session->update_retransmission(undef);
}

sub handle_message ($self, $server, $message)
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
		$self->$handle_method($server, @parts);
	}
	catch ($e) {
		die $e
			unless $e isa 'Module::Reversal::LRCP::X::IncorrectMessage';

		# ignore incorrect messages
		$self->log->debug($e);
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

	# make sure these values won't change in transmission sub
	my $log = sprintf 'transmitting data of length %s at pos %s to session %s',
		$session->sent_bytes - $session->ack_bytes, $session->ack_bytes, $id;
	my $data = $self->&make_data($id, $session->ack_bytes, $session->sent_bytes, $session->data);

	my $transmission = sub {
		$self->log->debug($log);

		$session->update_retransmission(__SUB__);
		$session->write($data);
	};

	$session->update_disconnection;
	$transmission->();
}

