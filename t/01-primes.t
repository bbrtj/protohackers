use v5.38;

use Test2::V0;
use SessionMock;
use Server::Module::Primes;
use Mojo::JSON qw(to_json);

my $session = SessionMock->new;
my $module = Server::Module::Primes->new;

my %m = (method => 'isPrime');

$module->connected($session);
$module->process_message($session, to_json({%m, number => 13}) . "\n");
$module->process_message($session, to_json({%m, number => 153}) . "\n");
$module->process_message($session, 'hi?' . "\n");
$module->process_message($session, '{{{');

ok $session->_closed, 'session is closed';
$module->disconnected($session);

is $session->_written, [
	to_json({%m, prime => \1}) . "\n",
	to_json({%m, prime => \0}) . "\n",
	to_json({error => \1}) . "\n",
	to_json({error => \1}) . "\n",
], 'data is ok';

done_testing;

