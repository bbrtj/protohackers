package TestUtil;

use SessionMock;
use Test2::V0;

use header;

sub test_module_io ($class, $module_class, $to_send, $to_receive, %options)
{
	my $session = SessionMock->new;
	my $module = $module_class->new;

	$module->connected($session);
	$options{after_connected}->($module, $session)
		if $options{after_connected};

	$module->process_message($session, $_)
		for $to_send->@*;

	$options{before_disconnected}->($module, $session)
		if $options{before_disconnected};
	$module->disconnected($session);

	my @written = $session->_written->@*;
	my @expected = $to_receive->@*;
	if ($options{binary}) {
		@written = map { unpack 'H*' } @written;
		@expected = map { unpack 'H*' } @expected;
	}

	is \@written, \@expected, 'data is ok';
	ok $session->_closed, 'session is closed';
	return $session;
}

