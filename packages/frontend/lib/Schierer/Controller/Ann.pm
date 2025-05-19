package Schierer::Controller::Ann;

use Mojo::Base 'Mojolicious::Controller';
use Mojo::File 'path';
use Mojo::Util 'mime_type';
use Mojo::Loader 'data_section';
use Mojo::File::Share::dist_dir;
use Mojo::Asset::File;
use strict;
use warnings;

sub serve {
  my ($c) = @_;

  # Derive username from package name
  my $class = ref $c;
  my ($user) = $class =~ /::([^:]+)$/;
  $user = lc $user;

  # Determine file path to user's home
  my $dist_home = dist_dir('Schierer::Base')->child('home', $user)->to_abs->resolve;
  my $rel_path = $c->stash('path') || '';

  # Deny access to hidden files or directories
  return $c->reply->not_found if grep { /^\./ } split '/', $rel_path;

  # Normalize and secure path
  my $requested = $dist_home->child(split '/', $rel_path)->to_abs->resolve;
  return $c->reply->not_found unless $requested->to_string =~ /^\Q$dist_home\E/;

  # Check if path is a template (.ep) in the home dir
  if (-f $requested && $requested->basename =~ /\.ep$/) {
    my $template_name = $requested->relative($dist_home)->to_string;
    $template_name =~ s{\\}{/}g;  # normalize for Mojo
    $template_name =~ s/\.ep$//;
    return $c->render(template => "home/$user/$template_name");
  }

  # File not found or not regular file
  return $c->reply->not_found unless -f $requested;

  # Guess MIME type based on file extension
  my $mime = mime_type($requested->basename) || 'application/octet-stream';

  # Serve the file
  $c->res->headers->content_type($mime);
  $c->reply->asset(Mojo::Asset::File->new(path => "$requested"));
}

1;
