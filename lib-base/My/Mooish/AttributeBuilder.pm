package My::Mooish::AttributeBuilder;

use v5.38;

use parent 'Mooish::AttributeBuilder';

sub attribute_types ($self)
{
	my $standard = $self->SUPER::attribute_types;

	return {
		%{$standard},
		injected => {
			is => 'ro',
		},
	};
}

Mooish::AttributeBuilder::add_shortcut(
	sub ($name, %args) {
		if ($args{_type} eq 'injected') {
			require DI;

			my $aliasing = (delete $args{aliasing}) // $name;
			%args = (
				%args,
				DI->injected($aliasing)
			);
		}

		return %args;
	}
);

