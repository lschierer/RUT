#!/usr/bin/env bash

deps=$(cat <<-EOF
Carp
Data::Printer
File::FindLib
List::Util
Mojo::Base
Mojo::File
Mojo::File::Share
Mojo::Log
Mojo::Server::Morbo
Mojolicious::Command::Author::generate::dockerfile
Mojolicious::Command::Author::generate::lite_app
Mojolicious::Command::Author::generate::makefile
Mojolicious::Command::Author::inflate
Mojolicious::Commands
Mojolicious::Plugin::DefaultHelpers
Mojolicious::Plugin::TagHelpers
Mojolicious::Routes
Mojolicious::Routes::Route
Mojolicious::Types
namespace::clean
Role::Tiny
Text::Markdown
Text::MultiMarkdown
utf8::all
YAML::PP
YAML::XS
EOF
)

echo "$deps" | while read -r line  ; do

  cpanm -n "$line"

done
