package Module::Database;

use class;

extends 'Module';

has field 'storage' => (
	isa => HashRef [Str],
	default => sub { {} },
);

use constant VERSION => "Ken's Key-Value Store 0.99";

sub constant_storage ($self)
{
	state $data = {
		version => VERSION,
	};

	return $data;
}

sub protocol ($class)
{
	return 'udp';
}

sub store ($self, $key, $value)
{
	$self->storage->{$key} = $value;
}

sub retrieve ($self, $key)
{
	return "$key=" . ($self->constant_storage->{$key} // $self->storage->{$key} // '');
}

sub process_message ($self, $server, $message)
{
	my @parts = split /=/, $message, 2;
	if (@parts == 2) {
		$self->store(@parts);
	}
	else {
		$server->write($self->retrieve($message));
	}

	return;
}

