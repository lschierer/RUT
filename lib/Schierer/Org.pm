# cspell: disable
use v5.42.0;
use utf8::all;
use lib 'lib';
use lib '../PAGI-WebServer/lib';

package Schierer::Org;
use Mooish::Base -standard;
with 'WebFramework::Role::Logger';
extends 'WebFramework::App';

our $VERSION = 'v0.04.0';

sub build ($self) {
  $self->SUPER::build();

  $self->load_controller('Luke');
  $self->load_controller('Ann');
  $self->load_controller('Archives');
  $self->load_module(
    'Middleware' => {
      Static => { root => 'public', pass_through => 1 },
    }
  );
}

1;
__END__
