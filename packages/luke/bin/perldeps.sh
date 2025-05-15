#!/bin/bash -x

deps=$(cat <<-EOF
Array::Merge::Unique
Data::Printer
DateTime
DateTime::Format::ISO8601
Exporter
FindBin::Bin
File::FindLib
File::Temp
Git::Wrapper
IPC::Cmd
JSON::PP
List::AllUtils
Object::Pad
Path::Tiny
HTML::FormatMarkdown
Role::Tiny
Text::Markdown
Try::Tiny
Unicode::UTF8
YAML::PP
utf8::all
namespace::clean
EOF
)

echo "$deps" | while read -r line  ; do

  cpanm -n "$line"

done
