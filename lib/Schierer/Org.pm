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
}

1;
__END__
