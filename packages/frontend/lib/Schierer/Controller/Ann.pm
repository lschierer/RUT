package Schierer::Controller::Ann;

use Mojo::Base 'Schierer::Controller::UserHome';
use Mojo::File 'path';
use Mojo::File::Share qw(dist_dir dist_file);
use strict;
use warnings;

sub serve {
  my ($c) = @_;

  # Derive username from package name
  my $class = ref $c;
  my ($user) = $class =~ /::([^:]+)$/;
  $user = lc $user;

  # Determine file path to user's home
  my $dist_home = dist_dir('Schierer::Base')->child('home', $user)->to_abs;
  $c->app->log->debug("$user\'s home is '$dist_home'.");
  my $rel_path = $c->stash('file_path') || '';
  $c->app->log->debug("'$rel_path' was requested.");
  # Check if this is a request for the root of Ann's home
  if (!$c->stash('file_path') || $c->stash('file_path') eq '') {
    # Get the path to Ann's poems directory

    my $poems_dir = $dist_home->child('poems');

    # Check if poems directory exists
    if (-d $poems_dir) {
      # Get list of poem files
      my @poem_files = grep { -f $_ && $_->basename !~ /^\./ } $poems_dir->list->each;
      $c->app->log()->debug('found ' . scalar @poem_files . ' poem files');

      # Sort poem files by name
      my @sorted_poems = sort { $a->basename cmp $b->basename } @poem_files;

      # Create links for each poem
      my @poem_links = map {
        my $name = $_->basename;
        $name =~ s/\.\w+$//; # Remove file extension
        {
          name => $name,
          url => $c->url_for("/~ann/poems/" . $_->basename)
        }
      } @sorted_poems;

      # Render the poem list
      return $c->render(
        template => 'layouts/Schierer/Ann/index',
        poems => \@poem_links,
        layout => 'default'
      );
    }
  }

  # Fall back to default behavior for all other requests
  return $c->SUPER::serve(@_);
}

1;
