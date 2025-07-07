package Module::Insecure::Cipher::AddN;

use v5.42;

use Mooish::Base;

extends 'Module::Insecure::Cipher';

sub spec ($self)
{
	return {
		byte => "\x04",
		has_config => true,
	};
}

sub obfuscate ($self, $data)
{
	my $conf = unpack 'C', $self->config;
	for my $i (keys @$data) {
		$data->[$i] = chr((ord($data->[$i]) + $conf) % 256);
	}
}

sub deobfuscate ($self, $data)
{
	my $conf = unpack 'C', $self->config;
	for my $i (keys @$data) {
		$data->[$i] = chr((ord($data->[$i]) - $conf) % 256);
	}
}

