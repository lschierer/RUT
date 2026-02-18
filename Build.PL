#!/usr/bin/env perl
# cspell: disable
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
  module_name   => 'Schierer::Org',
  license       => 'restrictive',
  dist_author   => 'Luke Schierer <luke@schierer.org>',
  dist_abstract => 'Website command and control for Schierer.org',
  dist_version  => '0.02',
  requires      => {
    'perl'                      => '5.42.0',
    'PAGI'                      => '0.001018',
    'Thunderhorse'              => '0.102',
    'DateTime::Format::Natural' => 0,
    'Text::Markdown::Discount'  => 0,
    'YAML::XS'                  => 0,
    'Path::Tiny'                => 0,
  },
  build_requires => {
    'Array::Merge::Unique'      => 0,
    'Data::Printer'             => 0,
    'DateTime'                  => 0,
    'DateTime::Format::ISO8601' => 0,
    'Encode'                    => 0,
    'Exporter'                  => 0,
    'File::Basename'            => 0,
    'File::Copy'                => 0,
    'File::Find'                => 0,
    'File::Find::Rule'          => 0,
    'File::Path'                => 0,
    'File::Temp'                => 0,
    'FindBin'                   => 0,
    'Getopt::Long'              => 0,
    'Git::Repository'           => 0,
    'Git::Wrapper'              => 0,
    'HTML::Entities'            => 0,
    'HTML::FormatMarkdown'      => 0,
    'IO::Socket::SSL'           => 0,
    'JSON::MaybeXS'             => 0,
    'JSON::PP'                  => 0,
    'List::AllUtils'            => 0,
    'Net::SSH::Perl'            => 0,
    'Object::Pad'               => 0,
    'Pandoc'                    => 0,
    'Path::Iterator::Rule'      => 0,
    'Path::Tiny'                => 0,
    'Role::Tiny'                => 0,
    'Text::Markdown'            => 0,
    'Try::Tiny'                 => 0,
    'Unicode::UTF8'             => 0,
    'YAML::PP'                  => 0,
  },
  configure_requires => {
    'Module::Build' => '0.42',
  },
);

$builder->create_build_script();
