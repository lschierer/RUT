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
        to => async sub ($c, $ctx) {
          return await $self->_handle_markdown($ctx, $entry);
        },
        action => 'http.*',
      }
    );
  }

  $self->logger->info("Registered " . scalar(@routes) . " ~luke content routes");

  # Catch-all for static assets (images etc under staticAssets/)
  $self->router->add(
    '/~luke/*path',
    {
      to => async sub ($c, $ctx) {
        return await $self->_handle_static_asset($ctx);
      },
      action => 'http.*',
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
        to => async sub ($c, $ctx) {
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
        to => async sub ($c, $ctx) {
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
  my $extra_vars = {};

  # Look up date from manifest
  my $date_str = $self->date_manifest->{ $entry->{manifest_key} };
  if ($date_str) {
    $extra_vars->{last_edited} = $self->_format_relative_date($date_str);
  }

  $extra_vars->{template} = 'luke/log_entry';

  my $html = $self->render_markdown_page(
    $entry->{path},
    $entry->{route},
    $extra_vars,
  );

  if ($html) {
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
  (my $rel = $path) =~ s{^/~luke/}{};

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

1;
__END__
