use v5.38;

use Test2::V0;
use Module::Chat;
use SessionMock;

my $alice = SessionMock->new;
my $bob = SessionMock->new;
my $module = Module::Chat->new;

$module->connected($alice);
is scalar $alice->_written->@*, 1, 'got first message to alice';
like $alice->_written->[0], qr/Please .+ your name/, 'got proper hello message';
$alice->_clear_written;

$module->connected($bob);
is scalar $bob->_written->@*, 1, 'got first message to bob';
is scalar $alice->_written->@*, 0, 'alice got no message';
like $bob->_written->[0], qr/Please .+ your name/, 'got proper hello message';
$bob->_clear_written;

$module->process_message($alice, "alice\n");
is scalar $alice->_written->@*, 1, 'got message to alice';
like $alice->_written->[0], qr/^[*].+:\s+$/, 'got room list (empty)';
$alice->_clear_written;

is scalar $bob->_written->@*, 0, 'bob got no message (not yet connected)';
$module->process_message($bob, "bob\n");
is scalar $bob->_written->@*, 1, 'got message to bob';
like $bob->_written->[0], qr/^[*].+: alice\s+$/, 'got room list (alice)';
is scalar $alice->_written->@*, 1, 'got message to alice';
like $alice->_written->[0], qr/^[*].+bob has entered/, 'alice got bob announcement';
$alice->_clear_written;
$bob->_clear_written;

$module->process_message($alice, "hello\n");
is scalar $bob->_written->@*, 1, 'got message to bob';
like $bob->_written->[0], qr/\[alice\] hello/, 'got proper message';
$bob->_clear_written;

$module->disconnected($alice);
is scalar $bob->_written->@*, 1, 'got message to bob';
like $bob->_written->[0], qr/^[*].+alice has left/, 'got alice leaving announcement';

$module->disconnected($bob);

ok $alice->_closed, 'session is closed';
ok $bob->_closed, 'session is closed';

done_testing;

