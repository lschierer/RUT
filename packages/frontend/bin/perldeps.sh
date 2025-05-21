#!/usr/bin/env bash

deps=$(cat <<-EOF
Carp
Data::Printer
File::FindLib
File::ShareDir::Install
List::Util
Mojo::Base
Mojo::File
Mojo::File::Share
Mojo::Log
Mojo::Server::Morbo
Mojolicious::Commands
Mojolicious::Plugin::DefaultHelpers
Mojolicious::Plugin::TagHelpers
Mojolicious::Routes
Mojolicious::Routes::Route
Mojolicious::Types
namespace::clean
Readonly
Role::Tiny
Text::Markdown
Text::MultiMarkdown
Text::Markdown::Discount
utf8::all
YAML::PP
YAML::XS
EOF
)

echo "$deps" | while read -r line  ; do

echo  "'$line' => '0',"

done
