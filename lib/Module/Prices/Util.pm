package Module::Prices::Util;

use header;

# two's complement decoder
sub unsigned_to_signed ($self, $int)
{
	if ($int >= 0x80000000) {
		return -0xffffffff + $int;
	}

	return $int;
}

# two's complement encoder
sub signed_to_unsigned ($self, $int)
{
	if ($int < 0) {
		return 0xffffffff + $int;
	}

	return $int;
}

