package Module::Insecure;

use v5.42;

use Mooish::Base;

use X::ShouldDisconnect;
use Module::Insecure::CipherStack;

extends 'Module';

sub connected ($self, $session)
{
	$session->timeout(60);
	$session->data->{buffer} = '';
	$session->data->{unconsumed_buffer} = '';
	$session->data->{cipher} = Module::Insecure::CipherStack->new;
	return;
}

sub read_header ($self, $session, $buffer)
{
	my $result = index $buffer, "\x00";
	if ($result < 0) {
		$result = length $buffer;
	}

	my $header = substr $buffer, 0, $result;
	$session->data->{cipher}->add_cipher($header);

	if ($result >= 0) {
		$session->data->{cipher}->finalize;

		# remove \x00 from buffer
		++$result;
	}

	return $result;
}

sub find_most_toys ($self, $string)
{
	my @parts = split /,/, $string;
	my $max_number = -1;
	my $current_item;

	foreach my $part (@parts) {
		if ($part =~ m{^\s*(\d+)(x.+)$} && $1 > $max_number) {
			$max_number = $1;
			$current_item = $2;
		}
	}

	X::ShouldDisconnect->throw("no toy found in: $string")
		unless $current_item;

	return $max_number . $current_item;
}

sub read_line ($self, $session, $buffer)
{
	$session->data->{unconsumed_buffer} .= $buffer;

	while ((my $newline_pos = index $session->data->{unconsumed_buffer}, "\n") >= 0) {
		my $data = substr $session->data->{unconsumed_buffer}, 0, $newline_pos + 1, '';
		chop $data;

		my $out_data = $session->data->{cipher}->cipher($self->find_most_toys($data) . "\n");
		$session->write($out_data);
		$session->data->{cipher}->move_out_stream_pos(length $out_data);
	}

	return length $buffer;
}

sub process_message ($self, $session, $message)
{
	$session->data->{buffer} .= $message;
	while (my $buffer = $session->data->{buffer}) {
		try {
			my $raw_buffer = $buffer;
			$buffer = $session->data->{cipher}->decipher($buffer);

			my $offset = 0;
			if (!$session->data->{cipher}->final) {
				$offset = $self->read_header($session, $buffer);
			}
			else {
				$offset = $self->read_line($session, $buffer);
				$session->data->{cipher}->move_stream_pos($offset);
			}

			$session->data->{buffer} = substr $raw_buffer, $offset;
		}
		catch ($e) {
			$self->log->debug("Caught exception: $e");

			if ($e isa 'X::ShouldDisconnect') {
				$session->close_gracefully;
				last;
			}
		}
	}
}

