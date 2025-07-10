use v5.42;

use Test2::V0;
use Module::VCS;
use SessionMock;

subtest 'should serve connections' => sub {
	my $client = SessionMock->new;
	my $module = Module::VCS->new;

	$module->connected($client);
	$module->process_message($client, "PUT /test 2\na\x09");
	$module->process_message($client, "PUT /abc 2\ncd");
	$module->process_message($client, "PUT /test 2\na\x09");
	$module->process_message($client, "PUT /test 1\n\x08");
	$module->process_message($client, "PUT /testd/test2 2\nab");
	$module->process_message($client, "LIST /\n");
	$module->process_message($client, "LIST /testd\n");
	$module->process_message($client, "GET /test\n");
	$module->process_message($client, "GET /abc r1\n");
	$module->process_message($client, "GET /[abc!\n");

	is $client->_written, [
		"READY\n",
		"OK r1\n",
		"READY\n",
		"OK r1\n",
		"READY\n",
		"OK r1\n",
		"READY\n",
		"ERR text files only\n",
		"OK r1\n",
		"READY\n",
		"OK 3\n",
		"testd/ DIR\n",
		"test r1\n",
		"abc r1\n",
		"READY\n",
		"OK 1\n",
		"test2 r1\n",
		"READY\n",
		"OK 2\n",
		"a\x09",
		"READY\n",
		"OK 2\n",
		"cd",
		"READY\n",
		"ERR illegal file name\n",
		],
		'data received ok';
};

done_testing;

