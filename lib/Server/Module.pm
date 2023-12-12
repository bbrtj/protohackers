package Server::Module;

use class;

has injected 'log';

sub problem_module ($wanted)
{
	my $base = __PACKAGE__;
	my %map = (
		0 => 'Echo',
	);

	my $module = $map{$wanted} // ucfirst lc $wanted;

	return "${base}::${module}";
}

sub name
{
	...;
}

sub timeout
{
	10;
}

sub process_message
{
	...;
}

sub handle_eof ($self, $session)
{
	$session->close_gracefully;
}

