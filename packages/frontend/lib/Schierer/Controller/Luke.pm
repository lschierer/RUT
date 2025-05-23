use v5.40.0;
use utf8::all;

package Schierer::Controller::Luke {
  use Mojo::Base 'Schierer::Controller::UserHome';

  use Mojo::File::Share qw(dist_dir dist_file);
  use Mojo::File;
  use Mojolicious::Types;
  require DateTime;
  require Text::MultiMarkdown;
  require Data::Printer;
  require Mojo::Home;
  use YAML::PP;
  use Readonly;
  use Carp;

# Base directory for luke content
  my $luke_dir =
    Mojo::File::Share::dist_dir('Schierer::Base')->child('home/luke');
  my $assets_dir = $luke_dir->child('assets');
  my $css_dir    = $luke_dir->child('css');
  my $types      = Mojolicious::Types->new;
  my $home       = Mojo::Home->new;

  my $luke_templates;

  # Create a closure that holds the redirects
  Readonly::Hash my %REDIRECTS => (
    'log/20050208/20050208-1101/' => '/~luke/log/science/prolife_science/',
    'log/20050603/20050603-1424/' => '/~luke/log/Society/homosexuality/',
  );

  sub initialize ($self, $app) {

    $home->detect;
    $luke_templates = $home->child('templates', 'Schierer', 'Luke');
    # Capture the controller instance in a lexical variable
    my $controller = $self;

    $self->app->helper(
      luke_render => sub {
        my ($c, %args) = @_;
        $args{format} //= 'html';
        my $original_template_paths = [@{ $c->app->renderer->paths() }];
        if (-d $luke_templates) {
          $c->app->renderer->paths(["$luke_templates"]);
        }
        # Render with custom paths
        my $output;
        eval { $output = $c->render(%args); };
        my $error = $@;

        # Restore original paths
        $c->app->renderer->paths($original_template_paths);

        # Re-throw any error
        croak $error if $error;

        return $output;

      }
    );

    $self->app->helper(
      getCurrentCalendar => sub {
        # Use the captured controller instance, not $self
        return $controller->getCurrentCalendar();
      }
    );
  }

  # Method to access the redirects
  sub get_redirects {
    return \%REDIRECTS;
  }

# Handle all requests for ~luke/*
  sub serve ($self) {
    if (!defined $luke_dir) {
      $luke_dir =
        Mojo::File::Share::dist_dir('Schierer::Base')->child('home/luke');
    }
    # Get file_path from stash - this is how Mojolicious passes route parameters
    my $file_path = $self->stash('file_path') // '';

    $self->app->log->debug("Luke controller handling path: '$file_path'");

    $self->res->headers->cache_control('max-age=1, no-cache');

    my $redirects = get_redirects();
    if (exists $redirects->{"$file_path"}) {
      return $self->redirect_to($redirects->{"$file_path"});
    }
    if ($file_path =~ m{log/([0-9]{8})/(.+)$}) {
      my $match = $1;
      my $rest  = $2;
      $self->app->log->trace(
"matched a request for $match/$rest checking for old style date based URLs"
      );
      if (!-e $luke_dir->child('log', $file_path)) {
        my $year  = substr($match, 0, 4);
        my $month = substr($match, 4, 2);
        my $day   = substr($match, 6, 2);
        if (-e $luke_dir->child('log', $year, $month, $day)) {
          $self->app->log->trace(
            "$year/$month/$day is a valid directory structure replacing $match"
          );
          my $target = "/~luke/log/$year/$month/$day/$rest";
          $target .= '/' unless $target =~ m{/$};
          $self->app->log->trace("redirecting to $target");
          $self->res->code(301);
          return $self->redirect_to($target);
        }
        else {
          $self->app->log->trace(
            "log/$year/$month/$day does not exist to replace $match");
        }
      }
    }

    # Check if this is an archive request
    if ($file_path =~ m{^log/archive/(\d{4})(?:/(\d{2})?(?:/(\d{2})?)?)?$}) {
      my ($year, $month, $day) = ($1, $2, $3);

      # If we have a specific day, let the normal file handling work
      return if defined $day;

      # Get the archive base directory
      my $archive_dir = $luke_dir->child('log', 'archive');
      my $now = DateTime->now();

      if (defined $month) {
        # Month index requested - use the existing calendar fragment
        my $calendar_path = $archive_dir->child($year, $month, 'calendar.html');
        if (-f $calendar_path) {
          my $calendar_content = $calendar_path->slurp;

          return $self->luke_render(
            template   => 'rut/archive/monthIndex',
            layout     => 'rut',
            current_year  => $now->year(),
            current_month => $now->month(),
            year       => $year,
            month      => $month,
            month_name =>
              DateTime->new(year => $year, month => $month)->month_name,
            calendar_content => $calendar_content
          );
        }
        else {
          # Calendar fragment doesn't exist
          return $self->reply->not_found;
        }

      }
      else {
        # Year index requested
        my %months = $self->_get_months_for_year($archive_dir, $year);
        return $self->luke_render(
          template => 'rut/archive/yearIndex',
          layout   => 'rut',
          current_year  => $now->year(),
          current_month => $now->month(),
          year     => $year,
          months   => \%months
        );
      }
    }

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
  sub handle_asset ($self, $path) {

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
  sub handle_css ($self, $path) {

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
  sub handle_js ($self, $path) {

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
  sub _render_markdown ($self, $file_path, $page_path) {

    my $ypp = YAML::PP->new(
      schema       => [qw/ + Perl /],
      yaml_version => ['1.2', '1.1'],
    );

    my $content = $file_path->slurp;

    my $layout = 'default';

    # Default title
    my $title = $page_path;
    $title =~ s{/}{::}g;    # Convert slashes to double colons for title

    # Extract YAML front matter if present
    my $yaml_data = {};
    if ($content =~ s/^---\s*\n(.*?)\n---\s*\n//s) {
      my $yaml = $1;
      eval { $yaml_data = $ypp->load_string($yaml); };
      if ($@) {
        $self->app->log->warn("Error parsing YAML front matter: $@");
      }
      elsif (ref $yaml_data eq 'HASH') {
        # Use title from front matter if available
        $title  = $yaml_data->{title}  if exists $yaml_data->{title};
        $layout = $yaml_data->{layout} if exists $yaml_data->{layout};
      }
    }

    my $converter = Text::MultiMarkdown->new(
      bibliography_title => 'Footnotes',
      tab_width          => 2,
    );
    # Convert markdown to HTML
    my $html = $converter->markdown($content);

    my $now = DateTime->now();
    # Render with layout and title
    $self->app->log->trace("layout is $layout");
    return $self->luke_render(
      format        => 'html',
      layout        => $layout,
      template      => 'default',
      content       => $html,
      title         => $title,
      format        => 'html',
      yaml_data     => $yaml_data,
      current_year  => $now->year(),
      current_month => $now->month(),
    );
  }

  sub getCurrentCalendar ($self) {
    my $now = DateTime->now();
    my $calendar_path =
      $luke_dir->child('log', 'archive', $now->year(),
      sprintf("%02d", $now->month()),
      'calendar.html');
    $self->app->log()->debug("calendar_path is $calendar_path");
    my $calendar =
      -e -f $calendar_path
      ? $calendar_path->slurp
      : '<span>Calendar Not Found</span>';
    return $calendar;
  }

  sub _get_months_for_year {
    my ($self, $archive_dir, $year) = @_;

    my %months;
    my $year_dir = $archive_dir->child($year);
    return () unless -d $year_dir;

    # Look for month directories (01-12)
    for my $month (1 .. 12) {
      my $month_str = sprintf("%02d", $month);
      my $month_dir = $year_dir->child($month_str);
      if (-d $month_dir) {
        # Check if this month has any day entries
        my @days = glob($month_dir->child('*.md'));
        $months{$month_str} = scalar @days if @days;
      }
    }

    return %months;
  }

  sub _get_days_for_month {
    my ($self, $archive_dir, $year, $month) = @_;

    my @days;
    my $month_dir = $archive_dir->child($year, $month);
    return () unless -d $month_dir;

    # Look for day files (01-31.md)
    for my $day (1 .. 31) {
      my $day_str  = sprintf("%02d", $day);
      my $day_file = $month_dir->child("$day_str.md");
      push @days, $day_str if -f $day_file;
    }

    return @days;
  }

};

1;

__END__

#ABSTRACT: Controller for luke user content

=pod

=head1 DESCRIPTION

Serves content for the luke user directory. Handles HTML, Markdown, and PDF files.
For Markdown files, extracts YAML front matter to set page title and other metadata.
All URLs are served without file extensions.

=cut
