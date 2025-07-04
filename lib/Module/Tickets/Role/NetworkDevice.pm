package Module::Tickets::Role::NetworkDevice;

use v5.42;

use Mooish::Base -role;

has param 'system' => (
	isa => InstanceOf ['Module::Tickets::System'],
	weak_ref => 1,
);

