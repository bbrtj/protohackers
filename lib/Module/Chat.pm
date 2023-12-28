package Module::Chat;

use builtin qw(trim);

use class;

extends 'Module';

has field 'users' => (
	isa => HashRef [InstanceOf ['Server::Session']],
	default => sub { {} },
);

use constant TERMINATOR => chr(10);
use constant MSG_SYSTEM_PREFIX => '* ';
use constant MSG_HELLO => 'Please enter your name';
use constant MSG_LIST => 'Currently chatting: %s';
use constant MSG_ENTERED => '%s has entered the chat';
use constant MSG_LEFT => '%s has left the chat';
use constant MSG_MESSAGE => '[%s] %s';
use constant MSG_INVALID_NAME => 'this name is invalid';

## no critic Subroutines::ProhibitBuiltinHomonyms
sub write ($self, $session, $message)
{
	$session->write($message . TERMINATOR);
	return;
}

sub system_write ($self, $session, $message)
{
	$self->write($session, MSG_SYSTEM_PREFIX . $message);
	return;
}

sub system_write_all ($self, $message)
{
	foreach my $session (values $self->users->%*) {
		$self->system_write($session, $message);
	}

	return;
}

sub write_all ($self, $from_session, $message, $exclude = !!1)
{
	$message = sprintf MSG_MESSAGE, $from_session->data->{name}, $message;
	foreach my $session (values $self->users->%*) {
		next if $exclude && $session->id eq $from_session->id;
		$self->write($session, $message);
	}

	return;
}

sub connected ($self, $session)
{
	$session->data->{buffer} = '';
	$session->data->{name} = undef;
	$self->write($session, MSG_HELLO);
	return;
}

sub joined ($self, $session, $name)
{
	if (length $name > 0 && $name =~ /\A \w+ \z/x) {
		$session->data->{name} = $name;
		$self->system_write_all(sprintf MSG_ENTERED, $name);
		my @users = map { $_->data->{name} } values $self->users->%*;

		$self->users->{$session->id} = $session;
		$self->system_write($session, sprintf MSG_LIST, join ', ', @users);
	}
	else {
		$self->system_write($session, MSG_INVALID_NAME);
		$session->close;
	}

	return;
}

sub process_message ($self, $session, $message)
{
	my $buffer = $session->data->{buffer} . $message;

	while ($buffer =~ s/\A(.+?)@{[TERMINATOR]}//) {
		my $message = $1;

		if (!$self->users->{$session->id}) {
			$self->joined($session, $message);
		}
		else {
			$self->write_all($session, $message);
		}
	}

	$session->data->{buffer} = $buffer;
	return;
}

sub disconnected ($self, $session)
{
	my $sid = $session->id;
	if ($self->users->{$sid}) {
		delete $self->users->{$sid};
		$self->system_write_all(sprintf MSG_LEFT, $session->data->{name});
	}

	$session->close_gracefully;
	return;
}

