package Module::Prices;

use Module::Prices::Form;
use List::Util qw(sum);

use class;

extends 'Module';

use constant MESSAGE_LENGTH => 9;

sub mean ($self, $range)
{
	return 0 unless $range->@*;
	return int(sum($range->@*) / $range->@*);
}

sub connected ($self, $session)
{
	my $session_data = $session->data;
	$session_data->{buffer} = '';
	$session_data->{prices} = [];
	return;
}

sub insert ($self, $session, $timestamp, $price)
{
	my $session_data = $session->data;
	push $session_data->{prices}->@*, [$timestamp, $price];
	return;
}

sub query ($self, $session, $ts_from, $ts_to)
{
	my @wanted_prices =
		map { $_->[1] }
		grep { $ts_from <= $_->[0] <= $ts_to }
		$session->data->{prices}->@*
		;

	$session->write(pack 'N!', $self->mean(\@wanted_prices));
	return;
}

sub process_query ($self, $session, $query)
{
	my $form = Module::Prices::Form->new;
	$form->set_input($query);

	if ($form->valid) {
		my $method = $form->value('type');
		$self->$method($session, $form->value('value1'), $form->value('value2'));
	}
	else {
		$session->close;
	}

	return;
}

sub process_message ($self, $session, $message)
{
	$message = $session->data->{buffer} . $message;

	while (length $message >= MESSAGE_LENGTH) {
		my $query = substr $message, 0, MESSAGE_LENGTH, '';
		$self->process_query($session, $query);
	}

	$session->data->{buffer} = $message;
	return;
}

