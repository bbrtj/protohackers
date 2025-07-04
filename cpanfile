requires 'Mojolicious';
requires 'Env::Dot';

on runtime => sub {
	requires 'Mooish::Base';

	requires 'Log::Dispatch';
	requires 'Beam::Wire';
	requires 'Data::ULID::XS';
	requires 'all';

	requires 'Form::Tiny';
	requires 'Math::Prime::Util';
	requires 'List::BinarySearch';
};

# vim: ft=perl

