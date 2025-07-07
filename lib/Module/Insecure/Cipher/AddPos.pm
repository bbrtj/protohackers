package Module::Insecure::Cipher::AddPos;

use v5.42;

use Mooish::Base;

extends 'Module::Insecure::Cipher';

sub spec ($self)
{
	return {
		byte => "\x05",
		has_config => false,
	};
}

sub obfuscate ($self, $data)
{
	my $base = $self->cipher->out_stream_pos;
	for my $i (keys @$data) {
		$data->[$i] = chr((ord($data->[$i]) + ($base + $i)) % 256);
	}
}

sub deobfuscate ($self, $data)
{
	my $base = $self->cipher->stream_pos;
	for my $i (keys @$data) {
		$data->[$i] = chr((ord($data->[$i]) - ($base + $i)) % 256);
	}
}

