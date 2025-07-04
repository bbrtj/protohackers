package Role::HasId;

use v5.42;

use Data::ULID::XS qw(ulid);

use Mooish::Base -role;

has field 'id' => (
	default => sub { ulid },
);

