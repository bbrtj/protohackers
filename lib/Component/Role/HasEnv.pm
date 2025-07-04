package Component::Role::HasEnv;

use v5.42;

use Mooish::Base -role;

has param 'env' => (
	isa => InstanceOf ['Component::Env'],
);

