package Module::Echo;

use class;

extends 'Module';

sub process_message ($self, $session, $message)
{
	$session->write($message);
	return;
}

