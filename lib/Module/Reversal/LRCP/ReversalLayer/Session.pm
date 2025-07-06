package Module::Reversal::LRCP::ReversalLayer::Session;

use v5.42;

use Mooish::Base;

extends 'Module::Reversal::LRCP::Session';

use constant END_OF_LINE => "\n";

has field 'last_eol' => (
	isa => Int,
	writer => -hidden,
	default => sub { -1 },
);

sub add_data ($self, $position, $more_data)
{
	return false unless $self->SUPER::add_data($position, $more_data);

	my $data = $self->data;
	my $last_eol = $self->last_eol;
	while ((my $ind = index $data, END_OF_LINE, $last_eol + 1) >= 0) {
		substr($data, $last_eol + 1, $ind - $last_eol - 1) = reverse substr($data, $last_eol + 1, $ind - $last_eol - 1);
		$last_eol = $ind;
	}

	$self->_set_last_eol($last_eol);
	$self->_set_data($data);

	return true;
}

