use v5.42;

use Test2::V0;
use Module::Reversal;
use UDPServerMock;
use Data::Dumper;

my $server = UDPServerMock->new;
my $module = Module::Reversal->new;

$module->process_message($server, '/connect/123/');
$module->process_message($server, '/data/123/0/hello/');
$module->process_message($server, "/data/123/14/\n/");
$module->process_message($server, "/data/123/15/abc/");
$module->process_message($server, '/data/123/5/\\/\\\\ world!/');
$module->process_message($server, '/ack/123/15/');
$module->process_message($server, '/close/123/');

is $server->_written, [
	'/ack/123/0/',
	'/ack/123/5/',
	'/ack/123/5/',
	'/ack/123/5/',
	'/ack/123/18/',
	"/data/123/0/!dlrow \\\\\\/olleh\n/",
	'/close/123/',
], 'messages ok';

note Dumper($server->_written);

done_testing;

