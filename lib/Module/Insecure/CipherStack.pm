package Module::Insecure::CipherStack;

use v5.42;

use Mooish::Base;

use DI;
use X::ShouldDisconnect;
use all 'Module::Insecure::Cipher';

use constant KNOWN_CIPHERS => [
	qw(
		AddN
		AddPos
		ReverseBits
		XorN
		XorPos
	)
];

has field 'log' => (
	DI->injected('log')
);

has field 'final' => (
	isa => Bool,
	writer => -hidden,
	default => sub { false },
);

has field 'cipher_code' => (
	isa => Str,
	writer => -hidden,
	default => sub { '' },
);

has field 'ciphers' => (
	isa => ArrayRef [InstanceOf ['Module::Insecure::Cipher']],
	default => sub { [] },
);

has field 'stream_pos' => (
	isa => PositiveOrZeroInt,
	writer => -hidden,
	default => sub { 0 },
);

has field 'out_stream_pos' => (
	isa => PositiveOrZeroInt,
	writer => -hidden,
	default => sub { 0 },
);

sub add_cipher ($self, $cipher_code)
{
	$self->_set_cipher_code($self->cipher_code . $cipher_code);
}

sub _analyze ($self)
{
	# check by trial
	my $any_string = "\x25" x 100;
	my @data_split = split //, $any_string;
	foreach my $cipher ($self->ciphers->@*) {
		$cipher->obfuscate(\@data_split);
	}

	X::ShouldDisconnect->throw('not modifying the string')
		if $any_string eq join '', @data_split;
}

sub finalize ($self)
{
	my %specs;
	foreach my $cipher_name (KNOWN_CIPHERS->@*) {
		my $cipher_class = "Module::Insecure::Cipher::$cipher_name";
		my $cipher_spec = $cipher_class->spec;
		$cipher_spec->{class} = $cipher_class;
		$specs{$cipher_spec->{byte}} = $cipher_spec;
	}

	my @spec_by_byte = split //, $self->cipher_code;
	for (my $i = 0 ; $i < @spec_by_byte ; ++$i) {
		my $this_spec = $specs{$spec_by_byte[$i]};
		X::ShouldDisconnect->throw('bad spec, unknown')
			unless $this_spec;

		my %params = (cipher => $self);
		if ($this_spec->{has_config}) {
			X::ShouldDisconnect->throw('bad spec, no arg')
				unless $i < $#spec_by_byte;
			$params{config} = $spec_by_byte[++$i];
		}

		push $self->ciphers->@*, $this_spec->{class}->new(%params);
	}

	$self->_analyze;
	$self->_set_final(true);
}

sub move_stream_pos ($self, $offset)
{
	$self->_set_stream_pos($self->stream_pos + $offset);
}

sub move_out_stream_pos ($self, $offset)
{
	$self->_set_out_stream_pos($self->out_stream_pos + $offset);
}

sub cipher ($self, $data)
{
	return $data unless $self->final;

	my @data_split = split //, $data;
	$self->log->debug(sprintf 'attempting to cipher data: [%s]', join ', ', map { ord } @data_split);
	foreach my $cipher ($self->ciphers->@*) {
		$cipher->obfuscate(\@data_split);
	}

	return join '', @data_split;
}

sub decipher ($self, $data)
{
	return $data unless $self->final;

	my @data_split = split //, $data;
	$self->log->debug(sprintf 'attempting to decipher data: [%s]', join ', ', map { ord } @data_split);
	foreach my $cipher (reverse $self->ciphers->@*) {
		$cipher->deobfuscate(\@data_split);
	}

	return join '', @data_split;
}

