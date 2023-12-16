use v5.38;

use Test2::V0;
use TestUtil;
use Module::Prices;
use Module::Prices::Util;

subtest 'should handle empty requests' => sub {
	my @to_send = (
		pack('ANN', 'Q', 100, 200),
	);

	my @to_receive = (
		pack('N', 0),
	);

	TestUtil->test_module_io(
		'Module::Prices',
		\@to_send,
		\@to_receive,
		binary => 1,
	);
};

subtest 'should handle example' => sub {
	my @to_send = (
		pack('H*', '490000303900000065'),
		pack('H*', '490000303a00000066'),
		pack('H*', '490000303b00000064'),
		pack('H*', '490000a00000000005'),
		pack('H*', '510000300000004000'),
	);

	my @to_receive = (
		pack('H*', '00000065'),
	);

	TestUtil->test_module_io(
		'Module::Prices',
		\@to_send,
		\@to_receive,
		binary => 1,
	);
};

subtest 'should handle negative integers' => sub {
	my @to_send = (
		pack('ANN', 'I', 100, Module::Prices::Util->signed_to_unsigned(-50)),
		pack('ANN', 'I', 200, Module::Prices::Util->signed_to_unsigned(-80)),
		pack('ANN', 'I', 300, Module::Prices::Util->signed_to_unsigned(100)),
		pack('ANN', 'I', 400, Module::Prices::Util->signed_to_unsigned(-2)),
		pack('ANN', 'Q', 0, 1000),
	);

	my @to_receive = (
		pack('N', Module::Prices::Util->signed_to_unsigned(-8)),
	);

	TestUtil->test_module_io(
		'Module::Prices',
		\@to_send,
		\@to_receive,
		binary => 1,
	);
};

subtest 'should handle big integers' => sub {
	my @to_send = (
		pack('ANN', 'I', 100, 2050000000),
		pack('ANN', 'I', 200, 2050000000),
		pack('ANN', 'I', Module::Prices::Util->signed_to_unsigned(-2099999999), 2050000000),
		pack('ANN', 'Q', Module::Prices::Util->signed_to_unsigned(-2100000000), 2100000000),
	);

	my @to_receive = (
		pack('N', 2050000000),
	);

	TestUtil->test_module_io(
		'Module::Prices',
		\@to_send,
		\@to_receive,
		binary => 1,
	);
};

done_testing;

