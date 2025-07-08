use v5.42;

use Test2::V0;
use Module::JobCentre;
use SessionMock;
use Mojo::JSON qw(decode_json);
use Data::Dumper;

subtest 'should serve connections' => sub {
	my $client = SessionMock->new;
	my $module = Module::JobCentre->new;

	$module->connected($client);
	$module->process_message(
		$client,
		'{"request":"put","queue":"queue1","job":{"title":"example-job"},"pri":123}' . "\n"
	);
	$module->process_message(
		$client,
		'{"request":"put","queue":"queue2","job":{"title":"example-job"},"pri":122}' . "\n"
	);
	$module->process_message($client, '{"request":"get","queues":["queue1", "queue2"]}' . "\n");
	$module->process_message($client, '{"request":"get","queues":["queue1", "queue2"]}' . "\n");
	$module->process_message($client, '{"request":"abort","id":1}' . "\n");
	$module->process_message($client, '{"request":"get","queues":["queue1"]}' . "\n");
	$module->process_message($client, '{"request":"delete","id":1}' . "\n");
	$module->process_message($client, '{"request":"get","queues":["queue1"]}' . "\n");
	$module->process_message($client, '{"request":"get","queues":["queue1"],"wait":true}' . "\n");
	$module->process_message(
		$client,
		'{"request":"put","queue":"queue1","job":{"title":"example-job-2"},"pri":124}' . "\n"
	);

	note Dumper($client->_written);
	my @written = map { decode_json $_ } $client->_written->@*;

	is \@written, [
		{status => 'ok', id => 1},
		{status => 'ok', id => 2},
		{status => 'ok', id => 1, job => {title => 'example-job'}, pri => 123, queue => 'queue1'},
		{status => 'ok', id => 2, job => {title => 'example-job'}, pri => 122, queue => 'queue2'},
		{status => 'ok'},
		{status => 'ok', id => 1, job => {title => 'example-job'}, pri => 123, queue => 'queue1'},
		{status => 'ok'},
		{status => 'no-job'},
		{status => 'ok', id => 3},
		{status => 'ok', id => 3, job => {title => 'example-job-2'}, pri => 124, queue => 'queue1'},
		],
		'data received ok';
};

subtest 'should serve more than one packet per message' => sub {
	my $client = SessionMock->new;
	my $module = Module::JobCentre->new;

	$module->connected($client);
	$module->process_message($client, '{}' . "\n" . '{"request":"get","queues":["queue1"]}' . "\n");

	my @written = map { decode_json $_ } $client->_written->@*;

	is \@written, [
		{status => 'error', error => L()},
		{status => 'no-job'},
		],
		'data received ok';
};

subtest 'should return jobs to queue after disconnection' => sub {
	my $client1 = SessionMock->new;
	my $client2 = SessionMock->new;
	my $module = Module::JobCentre->new;

	$module->connected($client1);
	$module->connected($client2);
	$module->process_message(
		$client2,
		'{"request":"put","queue":"queue1","job":{"title":"example-job"},"pri":123}' . "\n"
	);
	$module->process_message($client1, '{"request":"get","queues":["queue1"]}' . "\n");
	$module->process_message($client2, '{"request":"get","queues":["queue1"],"wait":true}' . "\n");

	is scalar $client1->_written->@*, 1, 'written count 1 ok';
	is scalar $client2->_written->@*, 1, 'written count 2 ok';

	$module->disconnected($client1);

	my @written = map { decode_json $_ } $client1->_written->@*, $client2->_written->@*;
	is \@written, [
		{status => 'ok', id => 4, job => {title => 'example-job'}, pri => 123, queue => 'queue1'},
		{status => 'ok', id => 4},
		{status => 'ok', id => 4, job => {title => 'example-job'}, pri => 123, queue => 'queue1'},
		],
		'data received ok';
};

done_testing;

