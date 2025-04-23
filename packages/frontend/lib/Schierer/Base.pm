use v5.40.0;
use experimental qw(class);
use utf8::all;
use File::FindLib 'lib';
use YAML::PP;
use namespace::clean;
use Mojolicious::Plugin::DefaultHelpers;

package Schierer::Base {
  use Mojo::Base 'Mojolicious', -role, -signatures;
  use Mojo::File::Share qw(dist_dir dist_file);
  use Carp;
  our $VERSION = 'v0.01.0';

  sub startup ($self) {
    my $distDir = Mojo::File::Share::dist_dir('Schierer::Base');
    my $home    = Mojo::Home->new;
    $home->detect;

    # Load configuration from config file
    my $config = $self->plugin(
      'NotYAMLConfig' => {
        module => 'YAML::PP',
      }
    );

    # Configure the application
    $self->secrets($config->{secrets});
    $self->plugin('DefaultHelpers');

    my $r = $self->routes;
    push @{$self->routes->namespaces}, 'Schierer::Controller';
    $r->any("/")->to('Root#index');

    $self->start(@ARGV);

  }
};
1;

__END__

#ABSTRACT: The main Mojolicious configuration, command, and control module

=pod

=head1 DESCRIPTION

this module contains the primary Mojolicious command, control and configuration.

=cut
