package Module::Insecure::Cipher::XorPos;

use v5.42;

use Mooish::Base;

extends 'Module::Insecure::Cipher';

sub spec ($self)
{
	return {
		byte => "\x03",
		has_config => false,
	};
}

sub obfuscate ($self, $data, $base = $self->cipher->out_stream_pos)
{
	for my $i (keys @$data) {
		$data->[$i] = chr(ord($data->[$i]) ^ (($base + $i) % 256));
	}
}

sub deobfuscate ($self, $data)
{
	$self->obfuscate($data, $self->cipher->stream_pos);
}

