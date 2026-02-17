#!/usr/bin/env perl
# cspell: disable
use v5.42.0;
use utf8::all;
use lib 'lib';
use lib '../PAGI-WebServer/lib';
require Schierer::Org;
require PAGI::Server;
use Future::AsyncAwait;
use Getopt::Long;
use Carp;

my $mode = 'development';

GetOptions('mode=s' => \$mode,)
  or die "Error in command line arguments\n";

unless ($mode =~ /(development|test|production)/) {
  croak("mode must be one of development|test|production, not '$mode'.");
}

warn "About to create Schierer::Org with env=$mode\n";
Schierer::Org->new(env => $mode)->run;