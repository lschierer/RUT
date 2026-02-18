package Schierer::Org::Controller::Luke;
# cspell: disable

use v5.42.0;
use utf8::all;
use Mooish::Base -standard;
extends 'WebFramework::Controller::Base';

use Future::AsyncAwait;
require Path::Tiny;
require Path::Iterator::Rule;
require JSON::MaybeXS;
require POSIX;
require DateTime;

has luke_dir => (
  is      => 'ro',
  default => sub {
    my $self = shift;
    my $dir  = $self->app_config->{config}->{luke_content_dir} // 'packages/luke';
    return Path::Tiny::path($dir);
  },
);

has redirect_map => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;
    my $file = $self->luke_dir->child('dist/redirects.json');
    return {} unless $file->exists;
    my $json = JSON::MaybeXS->new(utf8 => 1);
    return $json->decode($file->slurp_raw);
  },
);

has date_manifest => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;
    my $file = $self->luke_dir->child('dist/dates.json');
    return {} unless $file->exists;
    my $json = JSON::MaybeXS->new(utf8 => 1);
    return $json->decode($file->slurp_raw);
  },
);

has recent_changes => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;
    my $file = $self->luke_dir->child('dist/commitHistory.json');
    return [] unless $file->exists;
    my $json = JSON::MaybeXS->new(utf8 => 1);
    return $json->decode($file->slurp_raw);
  },
);

sub build ($self) {
  $self->logger->info(sprintf('build method for "%s"', __PACKAGE__));

  $self->_register_redirects();
  $self->_register_static_files();

  my $tree = $self->_build_content_tree();
  my @routes = sort keys %$tree;

  for my $route (@routes) {
    my $entry = $tree->{$route};

    $self->router->add(
      $route,
      {
        to => async sub ($c, $ctx, @args) {
          return await $self->_handle_markdown($ctx, $entry);
        },
        action => 'http.*',
      }
    );
  }

  $self->logger->info("Registered " . scalar(@routes) . " ~luke content routes");

  # Add index route for /~luke and /~luke/
  $self->router->add(
    '/~luke',
    {
      to => async sub ($c, $ctx, @args) {
        my $index_file = $self->luke_dir->child('index.html');
        if ($index_file->exists) {
          await $ctx->res->send_file($index_file->stringify, inline => 1);
        } else {
          await $ctx->res->redirect('/~luke/log/', 302);
        }
        return;
      },
      action => 'http.*',
    }
  );

  
  $self->router->add(
    '/~luke/log/',
    {
      to => async sub ($c, $ctx, @args) {
        my $index_file = $self->luke_dir->child('log/index.html');
        if ($index_file->exists) {
          await $ctx->res->send_file($index_file->stringify, inline => 1);
        } elsif ($self->luke_dir->child('log/index.md')->exists) {
          my $entry = {
            path => $self->luke_dir->child('log/index.md')->stringify,
            route => '/~luke/log/',
            manifest_key => 'log/index',
          };
          return await $self->_handle_markdown($ctx, $entry);
        } else {
          $ctx->res->status(404);
          await $ctx->res->html('<h1>404 - Not Found</h1>');
        }
        return;
      },
      action => 'http.*',
    }
  );

 

  # Catch-all for static assets (images etc under staticAssets/)
  $self->router->add(
    '/~luke/assets/*path',
    {
      to => async sub ($c, $ctx, @args) {
        return await $self->_handle_static_asset($ctx);
      },
      action => 'http.*',
    }
  );

  $self->router->add(
    '/~luke/styles/*path',
    {
      to => async sub ($c, $ctx, @args) {
        return await $self->_handle_styles($ctx);
      },
      action => 'http.*',
    }
  );

  $self->router->add(
    '/~luke/node_modules/*path',
    {
      to => async sub ($c, $ctx, @args) {
        return await $self->_handle_node($ctx);
      },
      action => 'http.get',
    }
  );
}

sub _register_redirects ($self) {
  my $map   = $self->redirect_map;
  my $count = 0;

  for my $source (keys %$map) {
    my $target = $map->{$source};

    $self->router->add(
      $source,
      {
        to => async sub ($c, $ctx, @args) {
          await $ctx->res->redirect($target, 308);
          return;
        },
        action => 'http.*',
      }
    );
    $count++;
  }

  $self->logger->info("Registered $count ~luke redirect routes");
}

sub _register_static_files ($self) {
  my $luke_dir = $self->luke_dir;
  my $count    = 0;

  # Register routes for static files at the luke root (*.html, *.pdf, *.txt)
  my $rule = Path::Iterator::Rule->new;
  my $next = $rule->file->nonempty->name(qr/\.(html|pdf|txt)$/)->iter(
    $luke_dir->stringify,
    {
      depthfirst      => -1,
      follow_symlinks =>  0,
      sorted          =>  1,
    }
  );

  while (defined(my $file = $next->())) {
    $file = Path::Tiny::path($file);

    # Only root-level files, not files under log/
    next if $file->relative($luke_dir) =~ m{^log/};
    next if $file->relative($luke_dir) =~ m{^dist/};
    next if $file->relative($luke_dir) =~ m{^node_modules/};

    my $rel   = $file->relative($luke_dir)->stringify;
    my $route = "/~luke/$rel";

    $self->router->add(
      $route,
      {
        to => async sub ($c, $ctx, @args) {
          await $ctx->res->send_file($file->stringify, inline => 1);
          return;
        },
        action => 'http.*',
      }
    );
    $count++;
  }

  $self->logger->info("Registered $count ~luke static file routes");
}

sub _build_content_tree ($self) {
  my %tree;
  my $log_dir = $self->luke_dir->child('log');

  unless ($log_dir->is_dir) {
    $self->logger->warn("Luke log directory not found: $log_dir");
    return \%tree;
  }

  $self->logger->debug(sprintf('scanning content under "%s"', $log_dir));

  my $rule = Path::Iterator::Rule->new;
  my $next = $rule->file->nonempty->name(qr/\.md$/)->iter(
    $log_dir->stringify,
    {
      depthfirst      => -1,
      follow_symlinks =>  0,
      sorted          =>  1,
    }
  );

  while (defined(my $file = $next->())) {
    $file = Path::Tiny::path($file);

    my $rel = $file->relative($self->luke_dir)->stringify;
    # e.g. log/20050131/20050131-0745.md -> /~luke/log/20050131/20050131-0745/
    (my $route = $rel) =~ s/\.md$//;
    $route = "/~luke/$route/";
    # Normalize double slashes
    $route =~ s{//+}{/}g;

    # manifest key is path without extension
    (my $manifest_key = $rel) =~ s/\.md$//;

    $tree{$route} = {
      path         => $file->stringify,
      route        => $route,
      manifest_key => $manifest_key,
    };
  }

  return \%tree;
}

async sub _handle_markdown ($self, $ctx, $entry) {
  # Parse frontmatter to get layout
  my $frontmatter = $self->parse_markdown_frontmatter($entry->{path});
  
  my $extra_vars = {};
  $extra_vars->{frontmatter} = $frontmatter;

  # Look up date from manifest
  my $date_str = $self->date_manifest->{ $entry->{manifest_key} };
  if ($date_str) {
    $extra_vars->{last_edited} = $self->_format_relative_date($date_str);
  }

  # Add calendar widget
  $extra_vars->{calendar_widget} = $self->_get_current_calendar();

  # Set template - override frontmatter
  $extra_vars->{frontmatter} = {
    %$frontmatter,
    template => 'luke/log_entry',
  };

  my $html = $self->render_markdown_page(
    $entry->{path},
    $entry->{route},
    $extra_vars,
  );

  if ($html) {
    if($html =~ /<recent-changes>/){
      my $changes = $self->recent_changes;
      foreach my $change (@$changes) {
        my $dt = DateTime->from_epoch(epoch => $change->{date});
        $change->{date_formatted} = $dt->ymd . ' ' . $dt->hms;
      }
      $extra_vars->{recent_changes} = $changes;
      my $rchtml = $self->template('luke/recent_changes', $extra_vars);
      $html =~ s{<recent-changes>.*?</recent-changes>}{$rchtml};
    }
    await $ctx->res->html($html);
  }
  else {
    $ctx->res->status(404);
    await $ctx->res->html('<h1>404 - Page Not Found</h1>');
  }
  return;
}

async sub _handle_static_asset ($self, $ctx) {
  my $path = $ctx->req->path;

  # Strip /~luke/ prefix
  (my $rel = $path) =~ s{^/~luke/assets}{};

  # Try staticAssets/ directory first
  my $file = $self->luke_dir->child('staticAssets', $rel);

  unless ($file->exists && $file->is_file) {
    # Also try the direct path under luke_dir
    $file = $self->luke_dir->child($rel);
  }

  if ($file->exists && $file->is_file) {
    await $ctx->res->send_file($file->stringify, inline => 1);
  }
  else {
    $ctx->res->status(404);
    await $ctx->res->html('<h1>404 - Not Found</h1>');
  }
  return;
}

async sub _handle_styles ($self, $ctx) {
  my $path = $ctx->req->path;

  # Strip /~luke/ prefix
  (my $rel = $path) =~ s{^/~luke/styles}{};

  # Try staticAssets/ directory first
  my $file = $self->luke_dir->child('dist/styles', $rel);

  if ($file->exists && $file->is_file) {
    await $ctx->res->send_file($file->stringify, inline => 1);
  }
  else {
    $ctx->res->status(404);
    await $ctx->res->html('<h1>404 - Not Found</h1>');
  }
  return;
}

async sub _handle_node ($self, $ctx) {
  my $path = $ctx->req->path;

  # Strip /~luke/ prefix
  (my $rel = $path) =~ s{^/~luke/node_modules}{};

  # Try staticAssets/ directory first
  my $file = $self->luke_dir->child('node_modules', $rel);

  if ($file->exists && $file->is_file) {
    await $ctx->res->send_file($file->stringify, inline => 1);
  }
  else {
    $ctx->res->status(404);
    await $ctx->res->html('<h1>404 - Not Found</h1>');
  }
  return;
}

sub _format_relative_date ($self, $iso_str) {
  # Parse ISO 8601 date string
  # Handle formats like "2005-01-31T11:45:00" or "2005-01-31 11:45:00 -0500"
  my ($year, $month, $day) = $iso_str =~ /^(\d{4})-(\d{2})-(\d{2})/;
  return '' unless $year;

  my $then = POSIX::mktime(0, 0, 12, $day, $month - 1, $year - 1900);
  my $now  = time();
  my $delta_days = int(($now - $then) / 86400);

  if ($delta_days < 1) {
    return 'earlier today';
  }
  elsif ($delta_days == 1) {
    return 'yesterday';
  }
  elsif ($delta_days < 7) {
    return "$delta_days days ago";
  }
  elsif ($delta_days < 14) {
    return 'last week';
  }
  elsif ($delta_days < 30) {
    my $weeks = int($delta_days / 7);
    return "about $weeks weeks ago";
  }
  elsif ($delta_days < 60) {
    return 'about a month ago';
  }
  elsif ($delta_days < 365) {
    my $months = int($delta_days / 30);
    return "about $months months ago";
  }
  elsif ($delta_days < 730) {
    return 'about a year ago';
  }
  else {
    my $years = int($delta_days / 365);
    return "about $years years ago";
  }
}

sub _get_current_calendar ($self) {
  my ($year, $month) = (localtime)[5, 4];
  $year += 1900;
  $month = sprintf("%02d", $month + 1);

  my $cal_file = $self->luke_dir->child("log/archive/$year/$month/calendar.html");
  
  if ($cal_file->exists) {
    return $cal_file->slurp_utf8;
  }
  
  # Fall back to most recent calendar
  my $archive_dir = $self->luke_dir->child("log/archive");
  if ($archive_dir->exists) {
    my @years = sort { $b cmp $a } 
                grep { $_->is_dir && $_->basename =~ /^\d{4}$/ } 
                $archive_dir->children;
    
    for my $year_dir (@years) {
      my @months = sort { $b <=> $a }
                   grep { $_->is_dir && $_->basename =~ /^\d{2}$/ }
                   $year_dir->children;
      
      for my $month_dir (@months) {
        my $cal = $month_dir->child('calendar.html');
        return $cal->slurp_utf8 if $cal->exists;
      }
    }
  }
  
  return '<p>No calendar available</p>';
}



1;
__END__
