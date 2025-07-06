use Rex -feature => [qw(1.4 exec_autodie)];
use Mojo::File qw(path);
use Env::Dot;
use Rex::Commands::PerlSync;

desc 'Deploy just the libs';
task deploy_libs => sub {
	my $cwd = path->to_abs;
	my $build_dir = $ENV{DEPLOY_DIRECTORY} // '~/protohackers';

	say "Deploying $cwd";
	sync_up "$cwd/lib/", "$build_dir/current/lib", {
		exclude => [qw()]
	};
};

desc 'Deploy the entire thing';
task deploy => sub {
	my $cwd = path->to_abs;
	my $build_dir = $ENV{DEPLOY_DIRECTORY} // '~/protohackers';

	say 'Preparing...';
	file $build_dir, ensure => 'directory';
	file "$build_dir/.env", ensure => 'present';

	for ("$build_dir/previous") {
		if (is_dir $_) {
			file $_, ensure => 'absent';
		}
	}

	for ("$build_dir/current") {
		if (is_dir $_) {
			mv $_, "$build_dir/previous";
		}
	}

	say "Deploying $cwd";
	file "$build_dir/current", ensure => 'directory';
	sync_up $cwd, "$build_dir/current", {
		exclude => [qw(.* local logs Rexfile*)]
	};

	file "$build_dir/current/logs", ensure => 'directory';

	symlink("$build_dir/.env", "$build_dir/current/.env");

	my $perlbrew = $ENV{DEPLOY_PERLBREW} // '~/perl5/perlbrew';
	my $perl = $ENV{DEPLOY_PERL} // 'perl-5.42.0';
	my $ubic = $ENV{DEPLOY_UBIC} // 'protohackers';

	say 'Installing modules';
	run "source $perlbrew/etc/bashrc && perlbrew use $perl && cd $build_dir/current && carmel install && carmel rollout";
};

# vim: ft=perl

