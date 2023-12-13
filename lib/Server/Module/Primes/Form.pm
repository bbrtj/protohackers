package Server::Module::Primes::Form;

use Form::Tiny -nomoo;
use Mojo::JSON qw(from_json);
use builtin qw(created_as_number);
use Math::BigInt;

use class;

has field 'bigint' => (
	isa => Bool,
	writer => 1,
	default => !!0,
);

use constant SUPPORTED_METHODS => [
	'isPrime',
];

form_field 'method' => (
	type => SimpleStr,
	required => 1,
);

field_validator 'must be a suported method' => sub ($self, $value) {
	return any { $value eq $_ } SUPPORTED_METHODS->@*;
};

form_field sub ($self) {
	return {
		name => 'number',
		required => 1,
		$self->bigint ? () : (
			type => Num,
			adjust => sub { int(pop) },
		),
	};
};

field_validator 'must be a number type' => sub ($self, $value) {
	return $self->bigint ? !!1 : created_as_number($value);
};

form_hook reformat => sub ($self, $json) {
	my $data = from_json($json);
	if ($data->{bignumber} && $json =~ m/"number"\s*:\s*(\d+)(\.\d+)?\s*[,}]/) {
		$self->set_bigint(!!1);
		$data->{number} = Math::BigInt->new($1);
	}
	else {
		$self->set_bigint(!!0);
	}

	return $data;
};

