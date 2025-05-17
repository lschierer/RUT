#!/bin/bash

deps=$(cat <<-EOF
Array::Merge::Unique
Data::Printer
DateTime
DateTime::Format::ISO8601
Encode
Exporter
File::Basename
File::Copy
File::Find
File::Find::Rule
File::Path
File::Temp
FindBin
Path::Tiny
Getopt::Long
Git::Repository
Git::Wrapper
IO::Socket::SSL
JSON::PP
List::AllUtils
Object::Pad
Path::Tiny
Net::SSH::Perl
HTML::Entities
HTML::FormatMarkdown
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
