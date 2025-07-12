use v5.42;

use Test2::V0;
use Module::Pest;
use Module::Pest::Protocol qw(encode_message decode_message);
use SessionMock;

my @messages = (
	{
		content => {
			name => 'hello',
		},
		expected => '50000000190000000b70657374636f6e74726f6c00000001ce',
	},
	{
		content => {
			name => 'error',
			message => 'bad',
		},
		expected => '510000000d0000000362616478',
	},
	{
		content => {
			name => 'ok',
		},
		expected => '5200000006a8',
	},
	{
		content => {
			name => 'dial_authority',
			site => 12345,
		},
		expected => '530000000a000030393a',
	},
	{
		content => {
			name => 'target_populations',
			site => 12345,
			populations => [
				{
					species => 'dog',
					min => 1,
					max => 3,
				},
				{
					species => 'rat',
					min => 0,
					max => 10,
				},
			],
		},
		expected => '540000002c000030390000000200000003646f67000000010000000300000003726174000000000000000a80',
	},
	{
		content => {
			name => 'create_policy',
			species => 'dog',
			action => 'conserve',
		},
		expected => '550000000e00000003646f67a0c0',
	},
	{
		content => {
			name => 'delete_policy',
			policy => '123',
		},
		expected => '560000000a0000007b25',
	},
	{
		content => {
			name => 'policy_result',
			policy => '123',
		},
		expected => '570000000a0000007b24',
	},
	{
		content => {
			name => 'site_visit',
			site => 12345,
			populations => [
				{
					species => 'dog',
					count => 1,
				},
				{
					species => 'rat',
					count => 5,
				},
			],
		},
		expected => '5800000024000030390000000200000003646f670000000100000003726174000000058c',
	},
);

foreach my $message_data (@messages) {
	my %content = $message_data->{content}->%*;
	my $name = $content{name};
	my $expected = $message_data->{expected};

	subtest "should encode and decode $name messages" => sub {
		my $encoded = encode_message({%content});
		my $pos = 0;

		is unpack('H*', $encoded), $expected, 'encoded ok';
		is decode_message(pack('H*', $expected), \$pos), \%content, 'decoded ok';
		is $pos, length $encoded, 'pos ok';
	};
}

subtest 'should serve connections' => sub {
	my $client = SessionMock->new;
	my $module = Module::Pest->new;
	my $hello = encode_message({name => 'hello'});

	$module->connected($client);
	$module->process_message($client, substr $hello, 0, 5);
	$module->process_message($client, substr $hello, 5);

	is $client->_written, [
		encode_message({name => 'hello'})
		],
		'data received ok';
};

done_testing;

