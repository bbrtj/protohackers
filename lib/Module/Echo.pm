package Module::Echo;

use v5.42;

use Mooish::Base;

extends 'Module';

sub process_message ($self, $session, $message)
{
	$session->write($message);
	return;
}

