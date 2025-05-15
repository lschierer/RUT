package Schierer::Controller::Test1;
use Mojo::Base 'Schierer::Controller::UserHome';
use Mojo::File::Share qw(dist_dir dist_file);
use Mojo::File;
use Text::Markdown qw(markdown);
use Carp;

# Base directory for test1 content
my $test1_dir = Mojo::File::Share::dist_dir('Schierer::Base')->child('home/test1');

# Handle all requests for ~test1/*
sub handle {
  my ($self) = @_;
  
  # Get file_path from stash - this is how Mojolicious passes route parameters
  my $file_path = $self->stash('file_path') // '';
  
  $self->app->log->debug("Test1 controller handling path: '$file_path'");
  
  $self->res->headers->cache_control('max-age=1, no-cache');

  # Default to index if no path specified
  $file_path = 'index' if !$file_path || $file_path eq '';

  # Remove leading/trailing slashes
  $file_path =~ s{^/+|/+$}{}g;

  # Check for HTML file first
  my $html_file = $test1_dir->child("$file_path.html");
  if (-f $html_file) {
    return $self->reply->file($html_file);
  }

  # Check for Markdown file
  my $md_file = $test1_dir->child("$file_path.md");
  if (-f $md_file) {
    my $content = $md_file->slurp;
    my $html = markdown($content);
    return $self->render(text => $html, format => 'html');
  }

  # Check if it's a directory with index files
  if (-d $test1_dir->child($file_path)) {
    my $dir = $test1_dir->child($file_path);

    # Check for index.html
    if (-f $dir->child('index.html')) {
      return $self->reply->file($dir->child('index.html'));
    }

    # Check for index.md
    if (-f $dir->child('index.md')) {
      my $content = $dir->child('index.md')->slurp;
      my $html = markdown($content);
      return $self->render(text => $html, format => 'html');
    }
  }

  # If we get here, the file wasn't found
  return $self->reply->not_found;
}

1;

__END__

#ABSTRACT: Controller for test1 user content

=pod

=head1 DESCRIPTION

Serves content for the test1 user directory. Handles both HTML and Markdown files,
converting Markdown to HTML on the fly.

=cut
