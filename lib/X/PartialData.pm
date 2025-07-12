package X::PartialData;

use v5.42;

use Mooish::Base;

extends 'X';

has param 'required_length' => (
	isa => Int,
);

