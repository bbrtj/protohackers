package Module::Reversal::LRCP::ReversalLayer;

use v5.42;

use Module::Reversal::LRCP::ReversalLayer::Session;

use Mooish::Base;

extends 'Module::Reversal::LRCP';

sub handle_message_connect ($self, $server, $id)
{
	$self->sessions->{$id} //= Module::Reversal::LRCP::ReversalLayer::Session->new(
		server => $server,
		disconnection_sub => sub { $self->handle_message_close($id) }
	);

	$self->SUPER::handle_message_connect($server, $id);
}

sub handle_message_data ($self, $server, $id, $pos, $data)
{
	my $session = $self->sessions->{$id};
	if (!$session) {

		# let parent version handle this
		return $self->SUPER::handle_message_data($server, $id, $pos, $data);
	}

	my $eol_previous = $session->last_eol;
	$self->SUPER::handle_message_data($server, $id, $pos, $data);
	my $eol_current = $session->last_eol;

	if ($eol_previous < $eol_current) {
		$self->mark_session_send($id, $eol_current + 1);
		$self->send_buffer($id);
	}
}

