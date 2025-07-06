package Module::Reversal;

use v5.42;

use Module::Reversal::LRCP::ReversalLayer;

use Mooish::Base;

extends 'Module';

has field 'lrcp' => (
	isa => InstanceOf ['Module::Reversal::LRCP::ReversalLayer'],
	default => sub { Module::Reversal::LRCP::ReversalLayer->new },
);

sub protocol ($class)
{
	return 'udp';
}

sub process_message ($self, $server, $message)
{
	$self->lrcp->handle_message($server, $message);
}

