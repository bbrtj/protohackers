use v5.38;

use Test2::V0;
use Module::Database;
use UDPServerMock;

my $server = UDPServerMock->new;
my $module = Module::Database->new;

$module->process_message($server, 'test=5');
$module->process_message($server, 'test');

is scalar $server->_written->@*, 1, 'got a single message back';
is $server->_written->[0], 'test=5', 'got proper message';

done_testing;

