package Module;

use class;

has injected 'log';

has field 'server' => (
	writer => -hidden,
	weak_ref => 1,
);

sub problem_module ($wanted)
{
	my $base = __PACKAGE__;
	my %map = (
		0 => 'Echo',
		1 => 'Primes',
		2 => 'Prices',
		3 => 'Chat',
		4 => 'Database',
		5 => 'ChatProxy',
		6 => 'Tickets',
	);

	my $module = $map{$wanted} // ucfirst $wanted;

	return "${base}::${module}";
}

sub name ($self)
{
	$self = ref $self || $self;
	$self =~ m/([^:]+)$/;
	return $1;
}

sub protocol ($class)
{
	return 'tcp';
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

