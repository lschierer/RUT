#!/usr/bin/env perl
use v5.42;
use utf8::all;
use Path::Tiny;

my $log_dir = path('packages/luke/log');
my $count = 0;

# Find and remove all map-only index files
$log_dir->visit(
    sub {
        my ($path, $state) = @_;
        return unless $path->is_file;
        return unless $path->basename =~ /^index\.md(wn)?$/;
        
        my $content = $path->slurp_utf8;
        return unless $content =~ /\[\[!map pages="([^"]+)"\]\]/;
        
        my $without_fm = $content;
        $without_fm =~ s/^---\s*\n.*?\n---\s*\n//s;
        $without_fm =~ s/\[\[!map[^\]]+\]\]//g;
        $without_fm =~ s/\s+//g;
        
        if (length($without_fm) == 0) {
            say "Removing: $path";
            $path->remove;
            $count++;
        }
    },
    { recurse => 1 }
);

say "Removed $count files";
