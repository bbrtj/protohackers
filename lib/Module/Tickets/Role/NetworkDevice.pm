package Module::Tickets::Role::NetworkDevice;

use class -role;

has param 'system' => (
	isa => InstanceOf ['Module::Tickets::System'],
	weak_ref => 1,
);

