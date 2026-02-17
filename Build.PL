#!/usr/bin/env perl
# cspell: disable
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name       => 'Schierer::Org',
    license           => 'restrictive',
    dist_author       => 'Luke Schierer <luke@schierer.org>',
    dist_version      => '0.01',
    requires          => {
        'perl'                => '5.42.0',
        'PAGI'                => '0.001018',
        'Thunderhorse'        => '0.102',
        'DateTime::Format::Natural' => 0,
        'Text::Markdown::Discount'      => 0,
        'YAML::XS'            => 0,
        'Path::Tiny'          => 0,
    },
    configure_requires => {
        'Module::Build' => '0.42',
    },
);

$builder->create_build_script();
