package Schierer::Org::Controller::Archives;
# cspell: disable

use v5.42.0;
use utf8::all;
use Mooish::Base -standard;
extends 'WebFramework::Controller::Base';

use Future::AsyncAwait;
require Path::Tiny;
require Path::Iterator::Rule;

has archives_dir => (
  is      => 'ro',
  default => sub {
    my $self = shift;
    my $dir  = $self->app_config->{config}->{archives_dir} // 'packages/archives';
    return Path::Tiny::path($dir);
  },
);

has extracted_dir => (
  is      => 'ro',
  default => sub {
    my $self = shift;
    my $dir  = $self->app_config->{config}->{archives_extracted_dir} // 'packages/archives/extracted';
    return Path::Tiny::path($dir);
  },
);

sub build ($self) {
  $self->logger->info(sprintf('build method for "%s"', __PACKAGE__));

  my $extracted = $self->extracted_dir;
  unless ($extracted->exists) {
    $self->logger->warn("Archives extracted directory does not exist: $extracted");
    $self->logger->warn("Run build-for-deploy.sh to extract archives");
    return;
  }

  # Each subdirectory under extracted/ is a username
  for my $user_dir (sort $extracted->children) {
    next unless $user_dir->is_dir;
    my $username = $user_dir->basename;

    $self->_register_user_routes($username, $user_dir);
  }
}

sub _register_user_routes ($self, $username, $user_dir) {
  my $rule = Path::Iterator::Rule->new;
  $rule->file->nonempty;

  my $iter = $rule->iter($user_dir->stringify, { sorted => 1 });
  my $count = 0;

  while (defined(my $file = $iter->())) {
    my $path  = Path::Tiny::path($file);
    my $rel   = $path->relative($user_dir)->stringify;
    my $route = "/~$username/$rel";

    # Also register without .html extension for cleaner URLs
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

  # Add index route for /~username and /~username/
  my $index_file = $user_dir->child('index.html');
  if ($index_file->exists) {
    $self->router->add(
      "/~$username",
      {
        to => async sub ($c, $ctx, @args) {
          await $ctx->res->send_file($index_file->stringify, inline => 1);
          return;
        },
        action => 'http.*',
      }
    );
  }

  $self->logger->info("Registered $count ~$username archive routes");
}

1;
__END__
