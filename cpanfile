requires 'Mojolicious';
requires 'Env::Dot';

on runtime => sub {
	requires 'Moo';
	requires 'Mooish::AttributeBuilder';
	requires 'Type::Tiny';
	requires 'namespace::autoclean';

	requires 'Import::Into';
	requires 'Ref::Util';
	requires 'Log::Dispatch';
	requires 'Beam::Wire';
	requires 'Data::ULID::XS';
	requires 'all';

	requires 'Form::Tiny';
	requires 'Math::Prime::Util';
};

# vim: ft=perl

