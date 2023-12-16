use v5.38;

use Test2::V0;
use TestUtil;
use Module::Echo;

my @to_send = qw(hello world);
my @to_receive = @to_send;
TestUtil->test_module_io('Module::Echo', \@to_send, \@to_receive);

done_testing;

