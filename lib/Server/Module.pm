package Server::Module;

use class;

has injected 'log';

sub problem_module ($wanted)
{
	my $base = __PACKAGE__;
	my %map = (
		0 => 'Echo',
		1 => 'Primes',
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

sub connected ($self, $session)
{
	# to be overriden in children
}

sub process_message
{
	...;
}

sub disconnected ($self, $session)
{
	$session->close_gracefully;
}

