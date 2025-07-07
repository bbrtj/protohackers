package Module::Insecure::Cipher::ReverseBits;

use v5.42;

use Mooish::Base;

extends 'Module::Insecure::Cipher';

sub spec ($self)
{
	return {
		byte => "\x01",
		has_config => false,
	};
}

sub obfuscate ($self, $data)
{
	for my $i (keys @$data) {
		$data->[$i] = pack 'B*', unpack 'b*', $data->[$i];
	}
}

sub deobfuscate ($self, $data)
{
	$self->obfuscate($data);
}

