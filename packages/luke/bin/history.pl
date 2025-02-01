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

my $output_dir = 'output';

my $input_dir = 'input';

GetOptions ("output-dir|o=s"       => \$output_dir,
            "input-dir|i=s"   => \$input_dir)
  or die("Error in command line arguments\n");

my $history = App::History->new(
  output_dir  => $output_dir,
  input_dir   => $input_dir,
);

$history->convert();

1;
