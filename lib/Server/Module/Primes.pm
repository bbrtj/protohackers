package Server::Module::Primes;

use builtin qw(is_bool);
use Server::Module::Primes::Form;
use Math::Prime::Util qw(is_prime);
use Mojo::JSON qw(to_json);

use class;

extends 'Server::Module';

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
	state $form = Server::Module::Primes::Form->new;
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

sub send ($self, $session, $message)
{
	$session->write($message . TERMINATOR);
}

sub connected ($self, $session)
{
	$session->session_data->{buffer} = '';
}

sub process_message ($self, $session, $message)
{
	$message = $session->session_data->{buffer} . $message;

	while ($message =~ s/\A(.+?)@{[TERMINATOR]}//) {
		my $response = $self->generate_response($session, $1);
		if (!defined $response) {
			$self->send($session, $self->generate_error($session));
			$session->close_gracefully;
			last;
		}

		$self->send($session, $response);
	}

	$session->session_data->{buffer} .= $message;
}

sub handle_eof ($self, $session)
{
	$self->send($session, $self->generate_error($session))
		if length $session->session_data->{buffer};

	$session->close_gracefully;
}

