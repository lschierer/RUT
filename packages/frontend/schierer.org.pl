#!/usr/bin/env perl
use v5.40.0;
use experimental qw(class);
use utf8::all;
use Carp;

use Mojo::Base -strict;
use Mojo::File qw(curfile);
use lib curfile->sibling('lib')->to_string;
use Mojolicious::Commands;

# Start command line interface for application
Mojolicious::Commands->start_app('Schierer::Base');
