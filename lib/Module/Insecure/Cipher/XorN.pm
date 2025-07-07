package Module::Insecure::Cipher::XorN;

use v5.42;

use Mooish::Base;

extends 'Module::Insecure::Cipher';

sub spec ($self)
{
	return {
		byte => "\x02",
		has_config => true,
	};
}

sub obfuscate ($self, $data)
{
	my $conf = unpack 'C', $self->config;
	for my $i (keys @$data) {
		$data->[$i] = chr(ord($data->[$i]) ^ $conf);
	}
}

sub deobfuscate ($self, $data)
{
	$self->obfuscate($data);
}

