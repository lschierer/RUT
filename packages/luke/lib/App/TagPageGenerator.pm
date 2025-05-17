package App::TagPageGenerator;

use v5.40.0;
use utf8;
use feature 'class';

use YAML::PP;
use Path::Tiny;
use File::Find::Rule;

class App::TagPageGenerator 0.01 {
    field $input :param;
    field $output :param;
    field $yaml = YAML::PP->new();

    method generate_tags {
        my %tag_to_files;

        my @files = File::Find::Rule
            ->file
            ->name('*.md')
            ->in(path($input)->child('log')->stringify);

        for my $file_path (@files) {
            my $path = path($file_path);
            my $rel_path = $path->relative($input);
            my $url_path = '/' . $rel_path->stringify;
            $url_path =~ s{\.md$}{/};
            $url_path =~ s{^}{/~luke/};

            my $content = $path->slurp_utf8;
            next unless $content =~ /^---\n(.*?)\n---\n/s;

            my $front_matter = $1;
            my $meta = eval { $yaml->load_string($front_matter) };
            next unless $meta && ref $meta eq 'HASH';

            my $tags = $meta->{tags};
            next unless $tags && ref $tags eq 'ARRAY';

            my $title = $meta->{title} // $url_path;

            for my $tag (@$tags) {
                push @{ $tag_to_files{$tag} }, { url => $url_path, title => $title };
            }
        }

        my $tag_dir = path($output)->child('log', 'tags');
        $tag_dir->mkpath;

        for my $tag (sort keys %tag_to_files) {
            my $tag_file = $tag_dir->child("$tag.md");
            my @links = map { "* [" . $_->{title} . "]( " . $_->{url} . " )" } sort { $a->{title} cmp $b->{title} } @{ $tag_to_files{$tag} };
            my $content = "---\ntitle: Tagged: $tag\n---\n\n" . join("\n", @links) . "\n";
            $tag_file->spew_utf8($content);
        }
    }
}

1;
