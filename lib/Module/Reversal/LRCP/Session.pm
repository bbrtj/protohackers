package Module::Reversal::LRCP::Session;

use v5.42;

use Mooish::Base;

has field 'data' => (
	isa => Str,
	writer => -hidden,
	default => sub { '' },
);

has field 'awaiting_data' => (
	isa => ArrayRef [Tuple [PositiveInt, Str]],
	default => sub { [] },
);

has field 'sent_bytes' => (
	writer => 1,
	isa => PositiveOrZeroInt,
	default => sub { 0 },
);

has field 'ack_bytes' => (
	writer => 1,
	isa => PositiveOrZeroInt,
	default => sub { 0 },
);

my sub push_data ($self, $position, $more_data)
{
	push $self->awaiting_data->@*, [$position, $more_data];
}

my sub join_data ($self, $position, $more_data)
{
	return false
		if $self->data_len != $position;

	$self->_set_data($self->data . $more_data);
	return true;
}

my sub pop_data ($self)
{
	POPPING: {
		my $i = 0;
		for my $data ($self->awaiting_data->@*) {
			if ($self->&join_data($data->@*)) {
				splice $self->awaiting_data->@*, $i, 1;
				redo POPPING;
			}

			++$i;
		}
	}
}

sub data_len ($self)
{
	return length $self->data;
}

sub add_data ($self, $position, $more_data)
{
	my $joined = $self->&join_data($position, $more_data);

	if ($joined) {
		$self->&pop_data;
		return true;
	}
	else {
		$self->&push_data($position, $more_data);
		return false;
	}
}

sub check_integrity ($self)
{
	return $self->awaiting_data->@* == 0;
}

