package Schierer::Org::Controller::Ann;
# cspell: disable

use v5.42.0;
use utf8::all;
use Mooish::Base -standard;
extends 'WebFramework::Controller::Base';

use Future::AsyncAwait;
require Path::Tiny;
require Path::Iterator::Rule;

has ann_dir => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self = shift;
    my $dir  = $self->app_config->{config}->{ann_content_dir} // 'packages/ann';
    return Path::Tiny::path($dir);
  },
);

has poems => (
  is      => 'ro',
  lazy    => 1,
  default => sub {
    my $self     = shift;
    my $poem_dir = $self->ann_dir->child('poems');
    return [] unless $poem_dir->exists;

    my @poems;
    my $rule = Path::Iterator::Rule->new;
    $rule->file->nonempty->name(qr/\.html$/);

    my $iter = $rule->iter($poem_dir->stringify, { sorted => 1 });
    while (defined(my $file = $iter->())) {
      my $path     = Path::Tiny::path($file);
      my $basename = $path->basename('.html');

      # Convert filename to display name: underscores to spaces
      my $name = $basename;
      $name =~ s/_/ /g;

      push @poems,
        {
        name     => $name,
        basename => $basename,
        url      => "/~ann/poems/$basename.html",
        path     => $path,
        };
    }

    return \@poems;
  },
);

sub build ($self) {
  $self->logger->info(sprintf('build method for "%s"', __PACKAGE__));

  # Index route: /~ann and /~ann/
  $self->router->add(
    '/~ann',
    {
      to => async sub ($c, $ctx, @args) {
        return await $self->_serve_index($ctx, '/~ann/');
      },
      action => 'http.*',
    }
  );

  # Poems index: /~ann/poems and /~ann/poems/
  $self->router->add(
    '/~ann/poems',
    {
      to => async sub ($c, $ctx, @args) {
        return await $self->_serve_index($ctx, '/~ann/poems/');
      },
      action => 'http.*',
    }
  );

  # Individual poem routes
  $self->_register_poem_routes();
}

async sub _serve_index ($self, $ctx, $base_url) {
  # Build poem list with URLs relative to this base
  my @poems =
    map { { name => $_->{name}, url => $_->{url}, } } @{ $self->poems };

  my $html = $self->template(
    'ann/poem_index',
    {
      title => "Ann's Poetry",
      poems => \@poems,
    }
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

sub _register_poem_routes ($self) {
  my $poem_dir = $self->ann_dir->child('poems');
  return unless $poem_dir->exists;

  my $rule = Path::Iterator::Rule->new;
  $rule->file->nonempty->name(qr/\.html$/);

  my $iter  = $rule->iter($poem_dir->stringify, { sorted => 1 });
  my $count = 0;

  while (defined(my $file = $iter->())) {
    my $path  = Path::Tiny::path($file);
    my $rel   = $path->relative($self->ann_dir)->stringify;
    my $route = "/~ann/$rel";

    my $file_copy = $path;
    $self->router->add(
      $route,
      {
        to => async sub ($c, $ctx, @args) {
          await $ctx->res->send_file($file_copy->stringify, inline => 1);
          return;
        },
        action => 'http.get',
      }
    );
    $count++;
  }

  # Also serve any non-html files (images, etc.) in the ann directory
  my $asset_rule = Path::Iterator::Rule->new;
  $asset_rule->file->nonempty->name(qr/\.(?:png|jpg|gif|svg|css|js)$/);
  my $asset_iter =
    $asset_rule->iter($self->ann_dir->stringify, { sorted => 1 });

  while (defined(my $file = $asset_iter->())) {
    my $path  = Path::Tiny::path($file);
    my $rel   = $path->relative($self->ann_dir)->stringify;
    my $route = "/~ann/$rel";

    my $file_copy = $path;
    $self->router->add(
      $route,
      {
        to => async sub ($c, $ctx, @args) {
          await $ctx->res->send_file($file_copy->stringify, inline => 1);
          return;
        },
        action => 'http.get',
      }
    );
    $count++;
  }

  $self->logger->info("Registered $count ~ann routes");
}

1;
__END__
