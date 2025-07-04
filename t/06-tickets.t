use v5.42;

use Test2::V0;
use ServerMock;
use SessionMock;
use Module::Tickets;

my $module = Module::Tickets->new;
$module->_set_server(ServerMock->new());

my $cam1 = SessionMock->new;
my $cam2 = SessionMock->new;
my $cam3 = SessionMock->new;
my $dispatcher = SessionMock->new;

$module->connected($cam1);
$module->connected($cam2);
$module->connected($cam3);
$module->connected($dispatcher);

$module->process_message($cam1, pack 'Cnnn', 0x80, 1, 5, 40);
$module->process_message($cam2, pack 'Cnnn', 0x80, 1, 10, 60);
$module->process_message($cam3, pack 'Cnnn', 0x80, 1, 12, 50);
$module->process_message($dispatcher, pack 'CCn', 0x81, 1, 1);

$module->process_message($cam1, pack 'CCA*N', 0x20, 3, 'XXX', 10);
$module->process_message($cam2, pack 'CCA*N', 0x20, 3, 'XXX', 30);
$module->process_message($cam3, pack 'CCA*N', 0x20, 3, 'XXX', 40);
$module->process_message($cam1, pack 'CCA*N', 0x20, 3, 'XXX', 500);

$module->disconnected($cam1);
$module->disconnected($cam2);
$module->disconnected($dispatcher);

is scalar $dispatcher->_written->@*, 1, 'got ticket';
like $dispatcher->_written->[0], qr/\x21/, 'got proper ticket type';

done_testing;

