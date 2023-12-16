package Module::Prices::Form;

use Form::Tiny -nomoo;
use Module::Prices::Util;

use class;

use constant SUPPORTED_TYPES => {
	'I' => 'insert',
	'Q' => 'query',
};

form_field 'type' => (
	type => Enum [keys SUPPORTED_TYPES->%*],
	required => 1,
	adjust => sub { SUPPORTED_TYPES->{+pop} },
);

form_field 'value1' => (
	type => PositiveOrZeroInt,
	required => 1,
	adjust => sub { Module::Prices::Util->unsigned_to_signed(pop) },
);

form_field 'value2' => (
	type => PositiveOrZeroInt,
	required => 1,
	adjust => sub { Module::Prices::Util->unsigned_to_signed(pop) },
);

form_hook reformat => sub ($self, $query) {
	my ($type, $int1, $int2) = unpack 'ANN', $query;

	return {
		type => $type,
		value1 => $int1,
		value2 => $int2,
	};
};

