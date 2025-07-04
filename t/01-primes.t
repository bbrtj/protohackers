use v5.42;

use Test2::V0;
use TestUtil;
use Module::Primes;
use Mojo::JSON qw(to_json);

my $session = SessionMock->new;
my $module = Module::Primes->new;

my %m = (method => 'isPrime');

my @to_send = (
	to_json({%m, number => 13}) . "\n",
	to_json({%m, number => 153}) . "\n",
	'hi?' . "\n",
	'{{{',
);

my @to_receive = (
	to_json({%m, prime => \1}) . "\n",
	to_json({%m, prime => \0}) . "\n",
	to_json({error => \1}) . "\n",
	to_json({error => \1}) . "\n",
);

TestUtil->test_module_io(
	'Module::Primes',
	\@to_send,
	\@to_receive,
	before_disconnected => sub ($module, $session) {
		ok $session->_closed, 'session is closed before client disconnects';
	},
);

done_testing;

