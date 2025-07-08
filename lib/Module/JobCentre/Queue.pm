package Module::JobCentre::Queue;

use v5.42;

use List::BinarySearch qw(binsearch_pos);

use Mooish::Base;

has param 'watcher' => (
	isa => InstanceOf ['Module::JobCentre::Watcher'],
	weak_ref => 1,
);

has param 'name' => (
	isa => Str,
);

has field '_jobs_map' => (
	isa => HashRef [Bool],
	default => sub { {} },
);

has field 'jobs' => (
	isa => ArrayRef [HashRef],
	default => sub { [] },
);

has field 'taken_jobs' => (
	isa => HashRef [HashRef],
	default => sub { {} },
);

sub add ($self, $job)
{
	my $jobs = $self->jobs;
	my $pos = binsearch_pos { $b->{pri} <=> $a } $job->{pri}, $jobs->@*;
	splice $jobs->@*, $pos, 0, $job;

	$self->_jobs_map->{$job->{id}} = true;
	$self->watcher->notify($self);
}

sub peek ($self)
{
	return $self->jobs->[0];
}

sub take ($self)
{
	my $job = shift $self->jobs->@*;
	if ($job) {
		$self->_jobs_map->{$job->{id}} = false;
		$self->taken_jobs->{$job->{id}} = $job;
	}

	return $job;
}

sub has_job ($self, $id)
{
	return defined $self->_jobs_map->{$id};
}

sub remove ($self, $id)
{
	my $has = delete $self->_jobs_map->{$id};

	if ($has) {
		$self->jobs->@* = grep { $_->{id} ne $id } $self->jobs->@*;
	}
	elsif (defined $has) {
		delete $self->taken_jobs->{$id};
	}
}

sub restore ($self, $id)
{
	my $has = $self->_jobs_map->{$id};

	if (defined $has && !$has) {
		$self->add(delete $self->taken_jobs->{$id});
	}
}

