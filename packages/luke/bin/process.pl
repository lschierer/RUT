#!/usr/bin/env perl

use v5.40.0;
use utf8::all;
use Carp;
use Object::Pad;
use Getopt::Long qw(
  GetOptions

);

use lib 'lib';
use App::Compile;
use App::Copy;

my $targetRoot = '../frontend/';

my $input_dir = './';



my $compiler = App::Compile->new(
  targetRoot  => $targetRoot,
  input_dir   => $input_dir,
);

say"starting compiler";
$compiler->run();


my $final_copy = App::Copy->new(
  targetRoot  => $targetRoot,
  input_dir   => $input_dir,
);

#say "starting final copy -> copy_files";
#$final_copy->copy_files();

1;
