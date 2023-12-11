package header;

use v5.38;
use utf8;
use Import::Into;

require feature;
require Scalar::Util;
require Ref::Util;
require List::Util;

sub import ($me, @args)
{
	my $pkg = caller;

	strict->import::into($pkg);
	warnings->import::into($pkg);
	feature->unimport::out_of($pkg, ':all');
	feature->import::into($pkg, qw(:5.38 try defer));
	utf8->import::into($pkg);
	Scalar::Util->import::into($pkg, qw(blessed));
	Ref::Util->import::into($pkg, qw(is_ref is_arrayref is_hashref is_coderef));
	List::Util->import::into($pkg, qw(first any all mesh));

	warnings->unimport::out_of($pkg, 'experimental::try');
	warnings->unimport::out_of($pkg, 'experimental::defer');
	warnings->unimport::out_of($pkg, 'experimental::for_list');

	# not exported, but don't warn about builtin
	warnings->unimport::out_of($pkg, 'experimental::builtin');

	return;
}

