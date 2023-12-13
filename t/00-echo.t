use v5.38;

use Test2::V0;
use SessionMock;
use Server::Module::Echo;

my $session = SessionMock->new;
my $module = Server::Module::Echo->new;

$module->connected($session);
$module->process_message($session, 'hello');
$module->process_message($session, 'world');
$module->disconnected($session);

is $session->_written, ['hello', 'world'], 'data is ok';
ok $session->_closed, 'session is closed';

done_testing;

