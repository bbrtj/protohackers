package Server::Module::Echo;

use class;

extends 'Server::Module';

sub name { 'Echo' }

sub process_message ($self, $session, $message)
{
	$session->write($message);
}

