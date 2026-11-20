#!/usr/bin/env perl
use v5.42;
use utf8::all;
use Path::Tiny;

my $log_dir = path('packages/luke/log');
my %dirs;

# Use visit instead of iterator
$log_dir->visit(
    sub {
        my ($path, $state) = @_;
        return unless $path->is_file;
        return unless $path->basename =~ /^index\.md(wn)?$/;
        
        my $content = $path->slurp_utf8;
        
        # Check if it contains a map statement
        return unless $content =~ /\[\[!map pages="([^"]+)"\]\]/;
        
        # Check if there's any substantial content besides frontmatter and map
        my $without_fm = $content;
        $without_fm =~ s/^---\s*\n.*?\n---\s*\n//s;
        $without_fm =~ s/\[\[!map[^\]]+\]\]//g;
        $without_fm =~ s/\s+//g;
        
        if (length($without_fm) == 0) {
            my $rel_path = $path->parent->relative($log_dir)->stringify;
            
            # Extract title from frontmatter
            my $title = '';
            if ($content =~ /^title:\s*"?([^"\n]+)"?/m) {
                $title = $1;
                $title =~ s/_/ /g;
            }
            
            $dirs{$rel_path} = $title;
        }
    },
    { recurse => 1 }
);

# Output as Perl hash
say "has autoindex_dirs => (";
say "  is      => 'ro',";
say "  default => sub {";
say "    return {";
for my $path (sort keys %dirs) {
    my $title = $dirs{$path};
    printf("      %-30s => '%s',\n", "'$path'", $title);
}
say "    };";
say "  },";
say ");";

