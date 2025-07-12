package Module::Pest::Protocol;

use v5.42;

use Types::Common -types;
use List::Util qw(sum0);
use Carp qw(croak);
use X::BadData;
use X::PartialData;

use Exporter qw(import);

our @EXPORT_OK = qw(
	encode_message
	decode_message
);

my sub encode_u8 ($number)
{
	state $check = IntRange [0, 2**8 - 1];
	$check->assert_valid($number);

	return pack 'C', $number;
}

my sub decode_u8 ($string, $pos)
{
	X::PartialData->throw('out of string bounds (u8)', required_length => 1)
		if $$pos + 1 > length $string;

	$$pos += 1;
	return unpack 'C', substr $string, $$pos - 1, 1;
}

my sub encode_u32 ($number)
{
	state $check = IntRange [0, 2**32 - 1];
	$check->assert_valid($number);

	return pack 'N', $number;
}

my sub decode_u32 ($string, $pos)
{
	X::PartialData->throw('out of string bounds (u32)', required_length => 4)
		if $$pos + 4 > length $string;

	$$pos += 4;
	return unpack 'N', substr $string, $$pos - 4, 4;
}

my sub encode_str ($string)
{
	state $check = Str;
	$check->assert_valid($string);

	return encode_u32(length $string) . $string;
}

my sub decode_str ($string, $pos)
{
	my $length = decode_u32($string, $pos);

	X::PartialData->throw('out of string bounds (str)', required_length => $length)
		if $$pos + $length > length $string;

	my $data = substr $string, $$pos, $length;
	$$pos += $length;
	return $data;
}

my sub encode_array($items, $item_encoder)
{
	return encode_u32(scalar $items->@*)
		. join '', map { $item_encoder->($_) } $items->@*;
}

my sub decode_array ($string, $pos, $item_decoder)
{
	my $len = decode_u32($string, $pos);

	my @result;
	for (1 .. $len) {
		push @result, $item_decoder->($string, $pos);
	}

	return \@result;
}

# assumes that start+len is within string bounds
my sub calculate_checksum ($string, $start, $len)
{
	my $data = substr $string, $start, $len;

	my $sum = sum0 map { ord } split //, $data;
	return $sum % 256;
}

my sub get_checksum_byte ($string, $start, $len)
{
	return (256 - calculate_checksum($string, $start, $len)) % 256;
}

my sub valid_checksum ($string, $start, $len)
{
	return calculate_checksum($string, $start, $len) == 0;
}

my sub encode_hello ($message)
{
	return encode_str('pestcontrol') . encode_u32(1);
}

my sub decode_hello ($string, $pos)
{
	my $protocol = decode_str($string, $pos);
	my $version = decode_u32($string, $pos);

	X::BadData->throw('invalid hello message')
		if $protocol ne 'pestcontrol' || $version != 1;

	return {};
}

my sub encode_error ($message)
{
	return encode_str($message->{message});
}

my sub decode_error ($string, $pos)
{
	return {
		message => decode_str($string, $pos),
	};
}

my sub encode_ok ($message)
{
	return '';
}

my sub decode_ok ($string, $pos)
{
	return {};
}

my sub encode_dial_authority ($message)
{
	return encode_u32($message->{site});
}

my sub decode_dial_authority ($string, $pos)
{
	return {
		site => decode_u32($string, $pos),
	};
}

my sub encode_target_populations ($message)
{
	return encode_u32($message->{site}) . encode_array(
		$message->{populations},
		sub ($item) {
			return encode_str($item->{species}) . encode_u32($item->{min}) . encode_u32($item->{max});
		}
	);
}

my sub decode_target_populations ($string, $pos)
{
	my $site = decode_u32($string, $pos);
	my $populations = decode_array(
		$string, $pos,
		sub ($string, $pos) {
			return {
				species => decode_str($string, $pos),
				min => decode_u32($string, $pos),
				max => decode_u32($string, $pos),
			};
		}
	);

	return {
		site => $site,
		populations => $populations,
	};
}

my sub encode_create_policy ($message)
{
	my $action_value =
		$message->{action} eq 'cull' ? 0x90 :
		$message->{action} eq 'conserve' ? 0xa0 :
		croak "bad action $message->{action}";

	return encode_str($message->{species}) . encode_u8($action_value);
}

my sub decode_create_policy ($string, $pos)
{
	my $species = decode_str($string, $pos);
	my $action_value = decode_u8($string, $pos);

	my $action =
		$action_value == 0x90 ? 'cull' :
		$action_value == 0xa0 ? 'conserve' :
		X::BadData->throw(sprintf 'invalid action value 0x%x', $action_value);

	return {
		species => $species,
		action => $action,
	};
}

my sub encode_delete_policy ($message)
{
	return encode_u32($message->{policy});
}

my sub decode_delete_policy ($string, $pos)
{
	return {
		policy => decode_u32($string, $pos),
	};
}

my sub encode_policy_result ($message)
{
	return encode_delete_policy($message);
}

my sub decode_policy_result ($string, $pos)
{
	return decode_delete_policy($string, $pos);
}

my sub encode_site_visit ($message)
{
	return encode_u32($message->{site}) . encode_array(
		$message->{populations},
		sub ($item) {
			return encode_str($item->{species}) . encode_u32($item->{count});
		}
	);
}

my sub decode_site_visit ($string, $pos)
{
	my $site = decode_u32($string, $pos);
	my $populations = decode_array(
		$string, $pos,
		sub ($string, $pos) {
			return {
				species => decode_str($string, $pos),
				count => decode_u32($string, $pos),
			};
		}
	);

	return {
		site => $site,
		populations => $populations,
	};
}

my @type_list = (
	{
		byte => 0x50,
		name => 'hello',
		encoder => \&encode_hello,
		decoder => \&decode_hello,
	},
	{
		byte => 0x51,
		name => 'error',
		decoder => \&decode_error,
		encoder => \&encode_error,
	},
	{
		byte => 0x52,
		name => 'ok',
		decoder => \&decode_ok,
		encoder => \&encode_ok,
	},
	{
		byte => 0x53,
		name => 'dial_authority',
		decoder => \&decode_dial_authority,
		encoder => \&encode_dial_authority,
	},
	{
		byte => 0x54,
		name => 'target_populations',
		decoder => \&decode_target_populations,
		encoder => \&encode_target_populations,
	},
	{
		byte => 0x55,
		name => 'create_policy',
		decoder => \&decode_create_policy,
		encoder => \&encode_create_policy,
	},
	{
		byte => 0x56,
		name => 'delete_policy',
		decoder => \&decode_delete_policy,
		encoder => \&encode_delete_policy,
	},
	{
		byte => 0x57,
		name => 'policy_result',
		decoder => \&decode_policy_result,
		encoder => \&encode_policy_result,
	},
	{
		byte => 0x58,
		name => 'site_visit',
		decoder => \&decode_site_visit,
		encoder => \&encode_site_visit,
	},
);

sub decode_message ($string, $pos)
{
	state %type_map = map { $type_list[$_]->{byte} => $_ } keys @type_list;

	my $start_pos = $$pos;
	my $type = decode_u8($string, $pos);

	my $id = $type_map{$type}
		// X::BadData->throw(sprintf 'invalid message type 0x%x', $type);
	my $type_data = $type_list[$id];

	my $len = decode_u32($string, $pos);
	my $message;
	try {
		$message = $type_data->{decoder}->($string, $pos);
		$message->{name} = $type_data->{name};

		# decode and ignore checksum byte
		decode_u8($string, $pos);
	}
	catch ($e)
	{
		if ($e isa 'X::PartialData') {
			X::BadData->throw('message content out of message bounds')
				if $$pos + $e->required_length > $start_pos + $len;

			die $e;
		}
	}

	X::BadData->throw('invalid message length')
		if $start_pos + $len != $$pos;

	X::BadData->throw('invalid checksum')
		unless valid_checksum($string, $start_pos, $len);

	return $message;
}

sub encode_message ($message)
{
	state %type_map = map { $type_list[$_]->{name} => $_ } keys @type_list;

	my $id = $type_map{delete $message->{name}}
		// croak "can't create message of type $message->{name}";
	my $type_data = $type_list[$id];

	my $message_content = $type_data->{encoder}->($message);
	my $result = '';
	$result .= encode_u8($type_data->{byte});

	# length - message content, length, type and checksum
	$result .= encode_u32(length($message_content) + 4 + 1 + 1);
	$result .= $message_content;
	$result .= encode_u8(get_checksum_byte($result, 0, length $result));

	return $result;
}

