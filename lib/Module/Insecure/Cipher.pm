package Module::Insecure::Cipher;

use v5.42;

use Mooish::Base;

has param 'cipher' => (
	isa => InstanceOf ['Module::Insecure::CipherStack'],
	handles => {
		stream_pos => 'stream_pos',
		out_stream_pos => 'out_stream_pos',
	},
	weak_ref => 1,
);

has option 'config' => (
	isa => StrLength [1, 1],
);

sub spec ($self)
{
	...;
}

sub obfuscate ($self, $data)
{
	...;
}

sub deobfuscate ($self, $data)
{
	...;
}

