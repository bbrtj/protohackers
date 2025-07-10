package Module::VCS;

use v5.42;

use List::Util qw(any);
use X::BadData;
use Mooish::Base;

extends 'Module';

# nested hashes with { order => N, revisions => [...], structure => {...} }
has field 'vcs_structure' => (
	isa => HashRef,
	default => sub { {} },
);

my sub write ($self, $session, $data)
{
	# that's how the working instance does it, but I think it's optional
	# my @char_by_char = split //, $data;
	# $session->write($_) for @char_by_char, "\n";

	$session->write($data . "\n");
}

my sub split_path ($self, $path, $trailing = false)
{
	my @parts = split /\//, $path, $trailing ? -1 : 0;
	$parts[0] //= '';
	X::BadData->throw('illegal file name')
		if length $parts[0];

	X::BadData->throw('illegal file name')
		if any {
			length == 0
		} @parts[1 .. $#parts - 1];

	X::BadData->throw('illegal file name')
		if any {
			/[^a-zA-Z0-9._-]/
		} @parts;

	my $file = pop @parts;

	return (@parts, $file);
}

my sub split_file ($self, $path)
{
	my @parts = $self->&split_path($path, true);
	X::BadData->throw('illegal file name')
		unless @parts > 1 && length $parts[-1] > 0;

	return @parts;
}

my sub fix_dir ($self, $path)
{
	$path =~ s{/$}{};
	return $path;
}

my sub find_structure_element ($self, $pathdata, $create = true)
{
	my $current = $self->vcs_structure;
	foreach my $path_part ($pathdata->@*) {
		return undef
			if !$create
			&& !exists $current->{structure} && !exists $current->{structure}{$path_part};

		$current = $current->{structure}{$path_part} //= {
			order => $current->{max_order}++,
			max_order => 0,
		};
	}

	return $current;
}

my sub enter_command_mode ($self, $session)
{
	if (defined $session->data->{file}) {
		my @pathdata = $session->data->{file}->@*;
		$session->data->{file} = undef;
		my $file = pop @pathdata;

		my $content = $session->data->{file_data_buffer};

		X::BadData->throw('text files only')
			if $content =~ /[\x00-\x08\x0b\x0c\x0e-\x1f\x7f-\x9f]/;

		my $dir = $self->&find_structure_element(\@pathdata);
		my $filestruct = $dir->{structure}{$file} //= {
			max_order => 0,
			order => $dir->{max_order}++,
			revisions => [],
		};

		my $revisions = $filestruct->{revisions};
		push $revisions->@*, $content
			unless $revisions->@* > 0 && $revisions->[-1] eq $session->data->{file_data_buffer};

		$self->&write($session, 'OK r' . ($revisions->$#* + 1));
	}

	$self->&write($session, 'READY');
}

my sub enter_file_data_mode ($self, $session, $dir_file, $size)
{
	$session->data->{file} = $dir_file;
	$session->data->{file_data_chars} = $size;
	$session->data->{file_data_buffer} = '';
}

sub connected ($self, $session)
{
	$session->timeout(60);

	$self->&enter_file_data_mode($session, undef, 0);
	$self->&enter_command_mode($session);
}

sub handle_command_help ($self, $session, @)
{
	$self->&write($session, 'OK USAGE: HELP|GET|PUT|LIST');
}

my sub validate_command_get ($self, @args)
{
	X::BadData->throw("USAGE: GET file [revision]")
		unless @args == 1 || @args == 2;
}

my sub execute_command_get ($self, $session, $path, $revision = undef)
{
	my @pathdata = $self->&split_file($path);
	my $file = pop @pathdata;

	my $dir = $self->&find_structure_element(\@pathdata, false);
	X::BadData->throw('no such file')
		unless $dir && $dir->{structure};

	my $file_data = $dir->{structure}{$file};
	X::BadData->throw('no such file')
		unless $file_data && $file_data->{revisions};

	if (defined $revision) {
		X::BadData->throw('no such revision')
			unless $revision =~ /^r([0-9]+)$/;
		$revision = $1 - 1;

		X::BadData->throw('no such revision')
			unless $revision >= 0 && $revision < $file_data->{revisions}->@*;
	}
	else {
		$revision = $file_data->{revisions}->$#*;
	}

	my $content = $file_data->{revisions}[$revision];

	$self->&write($session, 'OK ' . length $content);
	$session->write($content);
	$self->&enter_command_mode($session);
}

sub handle_command_get ($self, $session, @args)
{
	$self->&validate_command_get(@args);
	$self->&execute_command_get($session, @args);
}

my sub validate_command_put ($self, @args)
{
	X::BadData->throw("USAGE: PUT file length newline data")
		unless @args == 2;
}

my sub execute_command_put ($self, $session, $path, $size)
{
	my @pathdata = $self->&split_file($path);

	$size = 0
		unless $size =~ m{^\d+$} && $size > 0;

	$self->&enter_file_data_mode($session, [@pathdata], $size);
	$self->&enter_command_mode($session) if $size == 0;
}

sub handle_command_put ($self, $session, @args)
{
	$self->&validate_command_put(@args);
	$self->&execute_command_put($session, @args);
}

my sub validate_command_list ($self, @args)
{
	X::BadData->throw("USAGE: LIST dir")
		unless @args == 1;
}

my sub execute_command_list ($self, $session, $path)
{
	my @pathdata = $self->&split_path($self->&fix_dir($path));

	my $dir = $self->&find_structure_element(\@pathdata, false);
	my %structure = defined $dir ? $dir->{structure}->%* : ();
	my @order =
		sort {
			defined $structure{$b}->{structure} <=> defined $structure{$a}->{structure}
			|| $structure{$a}->{order} <=> $structure{$b}->{order}
		}
		keys %structure;

	$self->&write($session, 'OK ' . scalar @order);
	foreach my $file (@order) {
		my $revision = $dir->{structure}{$file}{revisions}
			? ' r' . ($dir->{structure}{$file}->{revisions}->$#* + 1)
			: '/ DIR'
			;
		$self->&write($session, "$file$revision");
	}

	$self->&enter_command_mode($session);
}

sub handle_command_list ($self, $session, @args)
{
	$self->&validate_command_list(@args);
	$self->&execute_command_list($session, @args);
}

sub handle_command ($self, $session, $command)
{
	my @parts = split /\s+/, $command;
	my $type = lc shift @parts;

	my $method = $self->can("handle_command_$type")
		// X::BadData->throw("illegal method: $type");

	$self->$method($session, @parts);
}

sub process_message ($self, $session, $message)
{
	my sub handle_exception ($e)
	{
		$self->log->debug("Caught exception: $e");

		if ($e isa 'X::ShouldDisconnect') {
			$session->close_gracefully;
			last;
		}
		elsif ($e isa 'X::BadData') {
			$self->&write($session, 'ERR ' . $e->msg);
		}
	}

	try {
		if ($session->data->{file_data_chars} > 0) {
			my $file_data = substr $message, 0, $session->data->{file_data_chars}, '';
			$session->data->{file_data_buffer} .= $file_data;
			$session->data->{file_data_chars} -= length $file_data;

			if ($session->data->{file_data_chars} == 0) {
				$self->&enter_command_mode($session);
			}
			else {
				return;
			}
		}
	}
	catch ($e) {
		handle_exception($e);
	}

	$session->data->{buffer} .= $message;
	while (!$session->data->{file} && $session->data->{buffer} =~ s/^(.*?)\n//) {
		try {
			my $data = $1;
			$self->log->debug("new packet: $data");
			$self->handle_command($session, $data);
		}
		catch ($e) {
			handle_exception($e);
		}
	}

	# back to data mode
	if ($session->data->{file}) {
		my $data = $session->data->{buffer};
		$session->data->{buffer} = '';
		$self->process_message($session, $data);
	}
}

