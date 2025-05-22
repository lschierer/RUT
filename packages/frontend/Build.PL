use v5.40.0;
use utf8::all;
use Module::Build;

my $builder = Module::Build->new(
  module_name   => 'Schierer',
  dist_author   => 'Luke Schierer <luke.schierer@gmail.com>',
  dist_abstract => 'Mojolicios Server for Schierer.org & user home pages',

  license           => 'ISC',
  dist_version_from => 'lib/Schierer/Base.pm',
  requires          => {
    'Mojo::Base'              => 0,
    'File::ShareDir'          => 1.0,
    'File::ShareDir::Install' => 0.13,
  },
  share_dir          => 'share',               # this is the key line
  create_makefile_pl => 0,                     #'traditional',
  script_files       => './schierer.org.pl',
  create_readme      => 0,
  configure_requires => {
    'Module::Build' => '0.42'
  },
  requires => {
    'Carp'                                => '0',
    'Data::Dumper'                        => '0',
    'Data::Printer'                       => '0',
    'DateTime'                            => '0',
    'Date::Manip'                         => '0',
    'DBI'                                 => '0',
    'Digest::MD5'                         => '0',
    'Digest::MD5::File'                   => '0',
    'Encode'                              => '0',
    'File::Basename'                      => '0',
    'File::Find'                          => '0',
    'File::FindLib'                       => '0',
    'File::ShareDir::Install'             => '0',
    'File::Slurp'                         => '0',
    'Getopt::Long'                        => '0',
    'JSON'                                => '0',
    'List::Util'                          => '0',
    'LWP::UserAgent'                      => '0',
    'MIME::Base64'                        => '0',
    'Mojo::Asset'                         => '0',
    'Mojo::Asset::File'                   => '0',
    'Mojo::Base'                          => '0',
    'Mojo::File'                          => '0',
    'Mojo::File::Share'                   => '0',
    'Mojo::Loader'                        => '0',
    'Mojo::Log'                           => '0',
    'Mojo::Util'                          => '0',
    'Mojo::Server::Morbo'                 => '0',
    'Mojolicious::Commands'               => '0',
    'Mojolicious::Plugin::DefaultHelpers' => '0',
    'Mojolicious::Plugin::TagHelpers'     => '0',
    'Mojolicious::Routes'                 => '0',
    'Mojolicious::Routes::Route'          => '0',
    'Mojolicious::Types'                  => '0',
    'POSIX'                               => '0',
    'namespace::clean'                    => '0',
    'Readonly'                            => '0',
    'Role::Tiny'                          => '0',
    'Text::Markdown'                      => '0',
    'Text::MultiMarkdown'                 => '0',
    'Text::Markdown::Discount'            => '0',
    'Time::Local'                         => '0',
    'utf8::all'                           => '0',
    'YAML::PP'                            => '0',
    'YAML::XS'                            => '0',
  },
  build_requires => {
    'Mojolicious::Command::Author::generate::dockerfile' => '0',
    'Mojolicious::Command::Author::generate::lite_app'   => '0',
    'Mojolicious::Command::Author::generate::makefile'   => '0',
    'Mojolicious::Command::Author::inflate'              => '0',
    'Module::Build'                                      => '0',
    'App::podweaver'                                     => '0',
    'Pod::Weaver'                                        => '0',
    'Pod::Weaver::Section::Leftovers'                    => '0',
    'Perl::Version'                                      => '0',
  },
  test_requires => {
    'Test::More' => '0',
  },
  meta_merge => {
    resources => {
      repository => 'https://github.com/lschierer/RUT',
      bugtracker => 'https://github.com/lschierer/RUT/issues'
    }
  },

);

$builder->create_build_script();
