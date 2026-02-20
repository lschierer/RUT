use v5.42.0;
use utf8::all;
# cspell: disable

package Schierer::Org::Controller::Root;
use Mooish::Base -standard;
extends 'WebFramework::Controller::Base';
use Future::AsyncAwait;

sub build ($self) {
  my $root_index = $self->pages_dir->child('index.md');
  $self->logger->debug("root index is at $root_index");
  $self->router->add(
    '/',
    {
      to => async sub ($c, $ctx, @args) {
        say "I see root req";
        unless($root_index->is_file){
          warn("root index at '$root_index' is not a file", {
          });
        }
        return $self->render_markdown_page($root_index, $ctx->req->path);
      },
      action => 'http.get',
    }
  );
}

1;
