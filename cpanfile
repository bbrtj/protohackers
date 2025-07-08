requires 'Mojolicious';
requires 'Env::Dot';

on runtime => sub {

	# for resource-intensive tasks
	requires 'UV';
	requires 'Mojo::Reactor::UV';

	requires 'Mooish::Base';

	requires 'Log::Dispatch';
	requires 'Beam::Wire';
	requires 'Data::ULID::XS';
	requires 'Cpanel::JSON::XS';
	requires 'all';

	requires 'Form::Tiny';
	requires 'Math::Prime::Util';
	requires 'List::BinarySearch';
};

# vim: ft=perl

