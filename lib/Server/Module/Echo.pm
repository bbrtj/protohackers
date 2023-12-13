package Server::Module::Echo;

use class;

extends 'Server::Module';

sub process_message ($self, $session, $message)
{
	$session->write($message);
}

