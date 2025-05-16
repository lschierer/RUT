#!/bin/bash

deps=$(cat <<-EOF
Array::Merge::Unique
Data::Printer
DateTime
DateTime::Format::ISO8601
Exporter
FindBin::Bin
File::Find
File::FindLib
File::Slurp::Tiny
File::Temp
Path::Tiny
Git::Repository
Git::Wrapper
IO::Socket::SSL
IPC::Cmd
JSON::PP
List::AllUtils
Object::Pad
Path::Tiny
Net::SSH::Perl
HTML::FormatMarkdown
HTML::Entities
Role::Tiny
Text::Markdown
Pandoc
Try::Tiny
Unicode::UTF8
YAML::PP
utf8::all
namespace::clean
EOF
)

echo "$deps" | while read -r line  ; do

  PKG_CONFIG_PATH=/opt/homebrew/lib/pkgconfig LIBRARY_PATH=/opt/homebrew/lib CPATH=/opt/homebrew/include cpanm -n "$line"

done

#LIBRARY_PATH=/opt/homebrew/lib CPATH=/opt/homebrew/include cpanm -n CommonMark
