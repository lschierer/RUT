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
  $self->_register_markdown_routes();

  # Add index route for /~luke and /~luke/
  $self->router->add(
    '/~luke',
    {
      to => async sub ($c, $ctx, @args) {
        my $index_file = $self->luke_dir->child('index.html');
        if ($index_file->exists) {
          return await $ctx->res->send_file($index_file->stringify, inline => 1);
        } 
        $index_file = $self->luke_dir->child('index.md');
        if ($index_file->exists){
          my $entry = {
            route   => $ctx->req->path,
            path    => $index_file,
          };
          return await $self->_handle_markdown($ctx, $entry);
        }

        await $ctx->res->redirect('/~luke/log/', 302);  
        return;
      },
      action => 'http.*',
    }
  );
  
  $self->router->add(
    '/~luke/log',
    {
      to => async sub ($c, $ctx, @args) {
        my $index_file = $self->luke_dir->child('log/index.html');
        if ($index_file->exists) {
          return await $ctx->res->send_file($index_file->stringify, inline => 1);
        } 
        $index_file = $self->luke_dir->child('log/index.md');
        if ($index_file->exists){
          my $entry = {
            route   => $ctx->req->path,
            path    => $index_file,
          };
          return await $self->_handle_markdown($ctx, $entry);
        }

        return;
      },
      action => 'http.*',
    }
  );

  my $static_assets_rule = Path::Iterator::Rule->new;
  $static_assets_rule->nonempty->file->name( qr/\.(?:png|svg|jpg|gif)$/ );
  my $iter = $static_assets_rule->iter($self->luke_dir->child('assets'), {sorted => 1});
  $self->_register_routes_from_iterator($iter, 'assets', sub { shift->_static_handler(@_) });


  my $css_rule = Path::Iterator::Rule->new;
  $css_rule->nonempty->file->name( qr/\.css$/ );
  $iter = $css_rule->iter($self->luke_dir->child('dist/styles'), { sorted => 1});
  $self->_register_routes_from_iterator($iter, 'dist/styles', sub { shift->_static_handler(@_) });

  my $node_rule = Path::Iterator::Rule->new;
  $node_rule->nonempty->file;
  $iter = $node_rule->iter($self->luke_dir->child('node_modules'), { sorted => 1});
  $self->_register_routes_from_iterator($iter, 'node_modules', sub { shift->_static_handler(@_) });

  my $log_images = Path::Iterator::Rule->new;
  $log_images->nonempty->file->name( qr/\.(?:svg|png|gif|jpg)$/ );
  $iter = $log_images->iter($self->luke_dir->child('log'), { sorted => 1});
  $self->_register_routes_from_iterator($iter, 'log', sub { shift->_static_handler(@_) });

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

sub _register_routes_from_iterator ($self, $iterator, $base_path, $handler, $opts = {}) {
  my $count = 0;
  my $strip_md = $opts->{strip_md} // 0;
  my $add_trailing_slash = $opts->{trailing_slash} // 0;
  
  while (defined(my $file = $iterator->())) {
    $file = Path::Tiny::path($file);
    
    my $rel = $file->relative($self->luke_dir->child($base_path))->stringify;
    $rel =~ s/\.md$// if $strip_md;  # Only remove .md if requested
    my $route = "/~luke/$base_path/$rel";
    $route =~ s{//+}{/}g;
    $route =~ s{/index$}{} if $strip_md;  # Only strip index for markdown
    $route .= '/' if $add_trailing_slash && $route !~ m{/$};  # Add trailing slash if requested

    #special cases
    $route =~ s{luke/dist/}{luke/};

    $self->logger->debug(sprintf('registering route "%s" from base_path "%s"', $route, $base_path));
    
    $self->router->add(
      $route,
      {
        to => async sub ($c, $ctx, @args) {
          await $handler->($self, $ctx, $file, $route);
        },
        action => 'http.get',
      }
    );
    $count++;
  }
  
  return $count;
}

async sub _markdown_handler ($self, $ctx, $file, $route) {
  my $entry = {
    path => $file->stringify,
    route => $route,
    manifest_key => $file->relative($self->luke_dir)->stringify =~ s/\.md$//r,
  };
  return await $self->_handle_markdown($ctx, $entry);
}

async sub _static_handler ($self, $ctx, $file, $route) {
  $self->logger->debug(sprintf('serving "%s" for route "%s"', $file->exists ? $file : "no such file", $route ));
  await $ctx->res->send_file($file->stringify, inline => 1);
  return;
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

    $self->logger->debug(sprintf('registering static file route "%s"', $route));
    my $file_copy = $file;  # Capture for closure
    $self->router->add(
      $route,
      {
        to => async sub ($c, $ctx, @args) {
          await $self->_static_handler($ctx, $file_copy, $route);
        },
        action => 'http.get',
      }
    );
    $count++;
  }

  $self->logger->info("Registered $count ~luke static file routes");
}

sub _register_markdown_routes ($self) {
  my $log_dir = $self->luke_dir->child('log');
  
  my $rule = Path::Iterator::Rule->new;
  $rule->file->nonempty->name(qr/\.md$/);
  
  my $iter = $rule->iter($log_dir , {
    depthfirst => -1,
    follow_symlinks => 0,
    sorted => 1,
  });

  my $count = $self->_register_routes_from_iterator(
    $iter,
    $log_dir->relative($self->luke_dir),
    sub { shift->_markdown_handler(@_) },
    { strip_md => 1 }
  );

  $self->logger->info("Registered $count markdown routes");
}

async sub _handle_markdown ($self, $ctx, $entry) {
  # Parse frontmatter to get layout
  my $frontmatter = $self->parse_markdown_frontmatter($entry->{path});
  
  my $extra_vars = {};
  $extra_vars->{frontmatter} = $frontmatter;

  # Look up date from manifest

  my $date_str;
  $date_str = $self->date_manifest->{ $entry->{manifest_key} } if exists $entry->{manifest_key};
  if ($date_str) {
    $extra_vars->{last_edited} = $self->_format_relative_date($date_str);
  }

  # Add calendar widget
  $extra_vars->{calendar_widget} = $self->_get_current_calendar();
  
  # Add list of years with archives
  $extra_vars->{archive_years} = $self->_get_archive_years();
  
  # Add tag list
  $extra_vars->{tag_list} = $self->_get_tag_list();

  # Controller override: use luke/log_entry template for blog posts
  $extra_vars->{template_override} = 'luke/log_entry';

  # Pass layout from frontmatter (defaults to 'luke_rut' in template)
  if ($frontmatter->{layout}) {
    my $layout = $frontmatter->{layout};
    # Normalize 'rut' to 'luke_rut'
    $layout = 'luke_rut' if $layout eq 'rut';
    $extra_vars->{layout} = $layout;
  }elsif( $entry->{path} =~ /log/){
    $extra_vars->{layout} = 'luke_rut';
  } else {
    $extra_vars->{layout} = 'luke_default';
  }

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

sub _get_archive_years ($self) {
  my $archive_dir = $self->luke_dir->child("log/archive");
  return [] unless $archive_dir->exists;
  
  my @years = sort { $a <=> $b }
              map { $_->basename }
              grep { $_->is_dir && $_->basename =~ /^\d{4}$/ }
              $archive_dir->children;
  
  return \@years;
}

sub _get_tag_list ($self) {
  my $tags_file = $self->luke_dir->child("dist/tags.json");
  return [] unless $tags_file->exists;
  
  my $json = JSON::MaybeXS->new(utf8 => 1);
  my $tags = eval { $json->decode($tags_file->slurp_raw) };
  return $tags // [];
}



1;
__END__
