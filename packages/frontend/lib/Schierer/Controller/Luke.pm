package Schierer::Controller::Luke;
use Mojo::Base 'Schierer::Controller::UserHome';

use Mojo::File::Share qw(dist_dir dist_file);
use Mojo::File;
use Mojolicious::Types;
use Text::Markdown qw(markdown);
use YAML::PP;
use Carp;

# Base directory for luke content
my $luke_dir = Mojo::File::Share::dist_dir('Schierer::Base')->child('home/luke');
my $assets_dir = $luke_dir->child('assets');
my $css_dir = $luke_dir->child('css');
my $types = Mojolicious::Types->new;

my $redirects = {};

# Handle all requests for ~luke/*
sub serve {
  my ($self) = @_;

  # Get file_path from stash - this is how Mojolicious passes route parameters
  my $file_path = $self->stash('file_path') // '';

  $self->app->log->debug("Luke controller handling path: '$file_path'");

  $self->res->headers->cache_control('max-age=1, no-cache');

  # Check if this is an asset or CSS request
  if ($file_path =~ m{^assets/}) {
    return $self->handle_asset($file_path);
  }

  if ($file_path =~ m{\.css$}) {
    return $self->handle_css($file_path);
  }

  if ($file_path =~ m{\.js$}) {
    return $self->handle_js($file_path);
  }

  # Default to index if no path specified
  $file_path = 'index' if !$file_path || $file_path eq '';

  # Remove leading/trailing slashes
  $file_path =~ s{^/+|/+$}{}g;

  # Try different file extensions in order of preference
  my @extensions = qw(html md pdf txt);

  foreach my $ext (@extensions) {
    my $full_path = $luke_dir->child("$file_path.$ext");
    $self->app->log->debug("Checking for file: $full_path");

    if (-f $full_path) {
      if ($ext eq 'html') {
        $self->app->log->debug("Serving HTML file: $full_path");
        return $self->reply->file($full_path);
      }
      elsif ($ext eq 'md') {
        $self->app->log->debug("Rendering Markdown file: $full_path");
        return $self->_render_markdown($full_path, $file_path);
      }
      elsif ($ext eq 'txt') {
        $self->app->log->debug("Serving TxT file: $full_path");
        return $self->reply->file($full_path);
      }
      elsif ($ext eq 'pdf') {
        $self->app->log->debug("Serving PDF file: $full_path");
        return $self->reply->file($full_path);
      }
    }
  }

  # Check if it's a directory with index files
  my $dir_path = $luke_dir->child($file_path);
  $self->app->log->debug("Checking directory: $dir_path");

  if (-d $dir_path) {
    # Try index with different extensions
    foreach my $ext (@extensions) {
      my $index_file = $dir_path->child("index.$ext");
      $self->app->log->debug("Checking for index file: $index_file");

      if (-f $index_file) {
        if ($ext eq 'html') {
          $self->app->log->debug("Serving HTML index: $index_file");
          return $self->reply->file($index_file);
        }
        elsif ($ext eq 'md') {
          $self->app->log->debug("Rendering Markdown index: $index_file");
          return $self->_render_markdown($index_file, "$file_path/index");
        }
        elsif ($ext eq 'pdf') {
          $self->app->log->debug("Serving PDF index: $index_file");
          return $self->reply->file($index_file);
        }
      }
    }
  }

  # If we get here, the file wasn't found
  $self->app->log->debug("No matching file found for: $file_path");
  return $self->reply->not_found;
}

# Handle asset requests (images, etc.)
sub handle_asset {
  my ($self, $path) = @_;

  # Remove the 'assets/' prefix
  $path =~ s{^assets/}{};

  $self->app->log->debug("Looking for asset: $path");

  # Look for the asset in the assets directory
  my $asset_path = $assets_dir->child($path);

  if (-f $asset_path) {
    $self->app->log->debug("Serving asset: $asset_path");
    return $self->reply->file($asset_path);
  }

  # Asset not found
  $self->app->log->debug("Asset not found: $path");
  return $self->reply->not_found;
}

# Handle CSS requests
sub handle_css {
  my ($self, $path) = @_;


  $self->app->log->debug("Looking for CSS: $path");

  # Look for the CSS file in the css directory
  my $css_path = $luke_dir->child($path);

  if (-f $css_path) {
    $self->app->log->debug("Serving CSS: $css_path");
    # Set the content type to CSS
    my $type = $types->type('css');
    $self->res->headers->content_type($type);
    return $self->reply->file($css_path);
  }

  # CSS file not found
  $self->app->log->debug("CSS file not found: $path");
  return $self->reply->not_found;
}

# Handle JS requests
sub handle_js {
  my ($self, $path) = @_;


  $self->app->log->debug("Looking for JS: $path");

  my $js_path = $luke_dir->child($path);

  if (-f $js_path) {
    $self->app->log->debug("Serving JS: $js_path");
    my $type = $types->type('js');
    $self->res->headers->content_type($type);
    return $self->reply->file($js_path);
  }

  # JS file not found
  $self->app->log->debug("JS file not found: $path");
  return $self->reply->not_found;
}

# Helper method to render markdown with YAML front matter
sub _render_markdown {
  my $ypp = YAML::PP->new(
    schema => [qw/ + Perl /],
    yaml_version => ['1.2', '1.1'],
  );
  my ($self, $file_path, $page_path) = @_;

  my $content = $file_path->slurp;

  my $layout = 'default';

  # Default title
  my $title = $page_path;
  $title =~ s{/}{::}g;  # Convert slashes to double colons for title

  # Extract YAML front matter if present
  my $yaml_data = {};
  if ($content =~ s/^---\s*\n(.*?)\n---\s*\n//s) {
    my $yaml = $1;
    eval {
      $yaml_data = $ypp->load_string($yaml);
    };
    if ($@) {
      $self->app->log->warn("Error parsing YAML front matter: $@");
    }
    elsif (ref $yaml_data eq 'HASH') {
      # Use title from front matter if available
      $title = $yaml_data->{title} if exists $yaml_data->{title};
      $layout = $yaml_data->{layout} if exists $yaml_data->{layout};
    }
  }

  # Convert markdown to HTML
  my $html = markdown($content);

  # Choose template based on path
    my $template = "layouts/Schierer/Luke/$layout";



  # Render with layout and title
  return $self->render(
    template => $template,
    content => $html,
    title => $title,
    format => 'html',
    yaml_data => $yaml_data
  );
}

sub _hashMap {
  $redirects->{/~luke/log/20050208/20050208-1101/} = {
    target  => '/~luke/log/science/prolife_science/',
    date    => '2005-02-08 16:01:00'
  };

  $redirects->{/~luke/log/20050603/20050603-1424/} = {
    target  => '/~luke/log/Society/homosexuality/',
    date    => '2005-06-03 19:24:00'
  };


}

1;

__END__

#ABSTRACT: Controller for luke user content

=pod

=head1 DESCRIPTION

Serves content for the luke user directory. Handles HTML, Markdown, and PDF files.
For Markdown files, extracts YAML front matter to set page title and other metadata.
All URLs are served without file extensions.

=cut
