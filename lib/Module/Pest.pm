package Module::Pest;

use v5.42;

use Module::Pest::Protocol qw(encode_message decode_message);
use Module::Pest::Authority;
use Mojo::IOLoop::Client;
use List::Util qw(first);
use Data::Dumper;

use Mooish::Base;

extends 'Module';

has param 'client_connector' => (
	isa => CodeRef,
	default => sub {
		return sub ($client) {
			$client->connect(address => 'pestcontrol.protohackers.com', port => 20547);
		};
	},
);

has field 'authorities' => (
	isa => HashRef,
	default => sub { {} },
);

sub get_authority ($self, $site)
{
	my $auth = $self->authorities->{$site} //= do {
		my $client = Mojo::IOLoop::Client->new;
		my $auth = Module::Pest::Authority->new(
			site => $site,
			client => $client,
		);

		$self->client_connector->($client);
		$auth;
	};

	return $auth if $auth->alive;
	return $self->get_authority($site);
}

my sub find_conflicts ($self, $populations)
{
	my %seen;
	foreach my $pop ($populations->@*) {
		return true
			if exists $seen{$pop->{species}} && $seen{$pop->{species}} != $pop->{count};
		$seen{$pop->{species}} = $pop->{count};
	}

	return false;
}

sub handle_site_visit ($self, $message)
{
	X::BadData->throw('conflict in observations')
		if $self->&find_conflicts($message->{populations});

	$self->get_authority($message->{site})->run(
		sub ($auth) {
			my $targets = $auth->target_populations;

			foreach my $species (keys $targets->%*) {
				my $target = $targets->{$species};
				my $observation = first { $_->{species} eq $species } $message->{populations}->@*;
				my $action;

				if (defined $observation) {
					my $current = $observation->{count};
					$action =
						$current < $target->{min} ? 'conserve' :
						$current > $target->{max} ? 'cull' :
						undef;
				}
				else {
					$action = 'conserve';
				}

				$auth->set_policy(
					{
						species => $species,
						action => $action,
					}
				);
			}
		}
	);
}

sub send ($self, $session, $message)
{
	if (!$session->data->{hello_sent}) {
		$session->data->{hello_sent} = true;
		$self->send(
			$session, {
				name => 'hello',
			}
		) unless $message->{name} eq 'hello';
	}

	$self->log->debug('client ' . $session->id . ' <--  ' . Dumper($message));
	$session->write(encode_message($message));
}

sub received ($self, $session, $message)
{
	$self->log->debug('client ' . $session->id . ' --> ' . Dumper($message));

	if ($message->{name} eq 'hello') {
		$self->send(
			$session, {
				name => 'hello',
			}
		);
	}
	elsif ($message->{name} eq 'site_visit') {
		$self->handle_site_visit($message);
	}
	else {
		X::BadData->throw("unsupported client message $message->{name}");
	}
}

sub connected ($self, $session)
{
	$session->timeout(60);
	$session->data->{buffer} = '';
	$session->data->{hello_sent} = false;
}

sub process_message ($self, $session, $message)
{
	$session->data->{buffer} .= $message;

	while (length $session->data->{buffer}) {
		try {
			my $pos = 0;
			my $data = decode_message($session->data->{buffer}, \$pos);
			$session->data->{buffer} = substr $session->data->{buffer}, $pos;

			$self->received($session, $data);
		}
		catch ($e) {
			if ($e isa 'X::PartialData') {
				last;
			}

			if ($e isa 'X::BadData') {
				$self->send(
					$session, {
						name => 'error',
						message => $e->msg,
					}
				);
			}

			$self->log->debug("$e");
			$session->close_gracefully;
			last;
		}
	}
}

