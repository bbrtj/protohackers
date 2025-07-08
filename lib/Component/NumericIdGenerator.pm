package Component::NumericIdGenerator;

use v5.42;

use Mooish::Base;

has param 'last_id' => (
	isa => PositiveOrZeroInt,
	writer => -hidden,
	default => sub { 0 },
);

sub next_id ($self)
{
	my $id = $self->last_id;
	$self->_set_last_id(++$id);

	return $id;
}

