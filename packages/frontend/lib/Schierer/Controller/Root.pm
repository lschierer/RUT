use v5.40.0;
use experimental qw(class);
use utf8::all;
use File::FindLib 'lib';
use YAML::PP;
use Mojolicious::Plugin::DefaultHelpers;
use namespace::clean;

package Schierer::Controller::Root {
  use List::Util qw( any );
  use Mojo::Base 'Mojolicious::Controller', -role, -strict, -signatures;
  use Mojo::File::Share qw(dist_dir dist_file);
  use Carp;
  our $VERSION = 'v0.01.0';

  my $distDir = Mojo::File::Share::dist_dir('Schierer::Base');

  my $homes = $distDir->child('home')->list({dir => 1});

  sub index($self) {
    $self->helpers->title('Welcome to the Schierer Web Server');
    $self->accepts('html');
    $self->res->headers->cache_control('max-age=1, no-cache');

    my $result = '';
    $homes->map(sub { ucfirst } )->each(sub($path, $num) {
      if( -d $path ){
        my $entry = Mojo::File->new($path);
        if( any {$_ =~ /$path\/index\.(md|html)/ } $entry->list({dir => 1})->each()){
          my $name = ucfirst($entry->basename());
          my $target = $entry->basename();
          $result .= "<li><a href='./~$target/'>$name</a></li>"
        }
      }

    });
    my $homeCount = $homes->size();
    $self->stash(content => "<div>The following users have homes here: <br/><ul>$result</ul></div>");
    $self->render(template => 'index');
  }

};
1;

__END__

#ABSTRACT: Dynamic root page for Schierer Site

=pod

=head1 DESCRIPTION

Dynamically generate the root site based on what home directories we are creating.

=cut
