package Module::Prices::Form;

use Form::Tiny -nomoo;

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
	type => Int,
	required => 1,
);

form_field 'value2' => (
	type => Int,
	required => 1,
);

form_hook reformat => sub ($self, $query) {
	my ($type, $int1, $int2) = unpack 'AN!N!', $query;

	return {
		type => $type,
		value1 => $int1,
		value2 => $int2,
	};
};

