package Component::Role::HasEnv;

use class -role;

has param 'env' => (
	isa => InstanceOf ['Component::Env'],
);

