package Role::HasId;

use Data::ULID::XS qw(ulid);

use class -role;

has field 'id' => (
	default => sub { ulid },
);

