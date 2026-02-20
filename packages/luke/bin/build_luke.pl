#!/usr/bin/env perl
# cspell: disable
use v5.40.0;
use utf8::all;
use lib 'lib';
use Getopt::Long;

use App::Build::Pipeline;

my $skip_pandoc  = 0;
my $skip_convert = 0;
GetOptions(
  'skip-pandoc'  => \$skip_pandoc,
  'skip-convert' => \$skip_convert,
) or die "Usage: $0 [--skip-pandoc] [--skip-convert]\n";

my $pipeline = App::Build::Pipeline->new(
  skip_pandoc  => $skip_pandoc,
  skip_convert => $skip_convert,
);
$pipeline->run();
