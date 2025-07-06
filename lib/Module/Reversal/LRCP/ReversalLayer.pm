package Module::Reversal::LRCP::ReversalLayer;

use v5.42;

use Module::Reversal::LRCP::ReversalLayer::Session;

use Mooish::Base;

extends 'Module::Reversal::LRCP';

sub handle_message_connect ($self, $id)
{
	$self->sessions->{$id} //= Module::Reversal::LRCP::ReversalLayer::Session->new;
	return $self->SUPER::handle_message_connect($id);
}

sub handle_message_data ($self, $id, $pos, $data)
{
	my $session = $self->sessions->{$id};
	my $eol_previous = $session->last_eol;
	my @messages = $self->SUPER::handle_message_data($id, $pos, $data);
	my $eol_current = $session->last_eol;

	if ($eol_previous < $eol_current) {
		$self->mark_session_send($id, $eol_current + 1);
		push @messages, $self->send_buffer($id);
	}

	return @messages;
}

