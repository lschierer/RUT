#!/usr/bin/env perl

use v5.40.0;
use utf8::all;
use Carp;
use Object::Pad;
use Getopt::Long qw(
  GetOptions

);

use lib 'lib';
use App::History;
use App::Compile;

my $greenwoodRoot = '../greenwood/';

my $input_dir = './log/';

my $history = App::History->new(
  greenwoodRoot  => $greenwoodRoot,
  input_dir   => $input_dir,
);

$history->convert();

my $compiler = App::Compile->new(
  greenwoodRoot  => $greenwoodRoot,
  input_dir   => $input_dir,
);

$compiler->run();

1;
