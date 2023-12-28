package Module;

use class;

has injected 'log';

sub problem_module ($wanted)
{
	my $base = __PACKAGE__;
	my %map = (
		0 => 'Echo',
		1 => 'Primes',
		2 => 'Prices',
		3 => 'Chat',
	);

	my $module = $map{$wanted} // ucfirst lc $wanted;

	return "${base}::${module}";
}

sub name ($self)
{
	$self = ref $self || $self;
	$self =~ m/([^:]+)$/;
	return $1;
}

sub session_class ($class)
{
	return 'Server::Session';
}

sub connected ($self, $session)
{
	# to be overriden in children
	return;
}

sub process_message
{
	...;
}

sub disconnected ($self, $session)
{
	$session->close_gracefully;
	return;
}

