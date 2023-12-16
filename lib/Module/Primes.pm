package Module::Primes;

use builtin qw(is_bool);
use Module::Primes::Form;
use Math::Prime::Util qw(is_prime);
use Mojo::JSON qw(to_json);

use class;

extends 'Module';

use constant TERMINATOR => chr(10);

# remote method
sub isPrime ($self, $number)
{
	return !!is_prime($number);
}

sub generate_error ($self, $session)
{
	return to_json({error => \1});
}

sub generate_response ($self, $session, $message)
{
	state $form = Module::Primes::Form->new;
	$form->set_input($message);

	if ($form->valid) {
		my $method = $form->value('method');
		my $result = $self->$method($form->value('number'));
		$result = $result ? \1 : \0
			if is_bool $result;

		return to_json(
			{
				method => $method,
				prime => $result,
			}
		);
	}

	return undef;
}

## no critic Subroutines::ProhibitBuiltinHomonyms
sub write ($self, $session, $message)
{
	$session->write($message . TERMINATOR);
	return;
}

sub connected ($self, $session)
{
	$session->data->{buffer} = '';
	return;
}

sub process_message ($self, $session, $message)
{
	$message = $session->data->{buffer} . $message;

	while ($message =~ s/\A(.+?)@{[TERMINATOR]}//) {
		my $response = $self->generate_response($session, $1);
		if (!defined $response) {
			$self->write($session, $self->generate_error($session));
			$session->close_gracefully;
			last;
		}

		$self->write($session, $response);
	}

	$session->data->{buffer} .= $message;
	return;
}

sub disconnected ($self, $session)
{
	$self->write($session, $self->generate_error($session))
		if length $session->data->{buffer};

	$session->close_gracefully;
	return;
}

