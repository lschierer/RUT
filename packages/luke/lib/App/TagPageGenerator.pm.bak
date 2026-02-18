use v5.40.0;
use utf8;

use Object::Pad;

package App::TagPageGenerator;
our $VERSION = '0.00.1';

class App::TagPageGenerator {
  use YAML::PP;
  use Path::Tiny;
  use File::Find::Rule;

  field $input : param;
  field $output : param;
  field $templateDir : param;
  field $yaml = YAML::PP->new();

  method generate_tags {
    my %tag_to_files;

    my @files = File::Find::Rule->file->name('*.md')
      ->in(path($input)->child('log')->stringify);

    my $tag_dir = path($output)->child('log', 'tags');
    $tag_dir->mkdir({ mode => 0710 });

    for my $file_path (@files) {
      my $path     = path($file_path);
      my $rel_path = $path->relative($input);
      my $url_path = '/' . $rel_path->stringify;
      $url_path =~ s{\.md$}{/};
      $url_path =~ s{^}{/~luke/};

      my $content = $path->slurp_utf8;
      next unless $content =~ /^---\n(.*?)\n---\n/s;

      my $front_matter = $1;
      my $meta         = eval { $yaml->load_string($front_matter) };
      next unless $meta && ref $meta eq 'HASH';

      my $tags = $meta->{tags};
      next unless $tags && ref $tags eq 'ARRAY';

      my $title = $meta->{title} // $url_path;

      for my $tag (@$tags) {
        push @{ $tag_to_files{$tag} }, { url => $url_path, title => $title };
      }
    }

    for my $tag (sort keys %tag_to_files) {
      my $tag_file = $tag_dir->child("$tag.md");
      my @links    = map { "* [" . $_->{title} . "]( " . $_->{url} . " )" }
        sort { $a->{title} cmp $b->{title} } @{ $tag_to_files{$tag} };
      my $content = "---\ntitle: >-\n  Tagged: $tag\nlayout: rut\n---\n\n"
        . join("\n", @links) . "\n";
      $tag_file->spew_utf8($content);
    }
    my $html = qq{<table class="tag-summary">\n};
    $html .= qq{  <thead><tr><th>Tag</th><th>Pages</th></tr></thead>\n};
    $html .= qq{  <tbody>\n};

    for my $tag (
      sort {
        my $count_cmp = @{ $tag_to_files{$b} } <=> @{ $tag_to_files{$a} };
        return $count_cmp || lc($a) cmp lc($b);
      } keys %tag_to_files
    ) {
      my $count = scalar @{ $tag_to_files{$tag} };
      my $link  = "/~luke/log/tags/$tag/";           # adjust path if needed
      $html .=
        qq{    <tr><td><a href="$link">$tag</a></td><td>$count</td></tr>\n};
    }

    $html .= qq{  </tbody>\n</table>\n};

    $templateDir->child('rut', 'tag_table.html.ep')->spew_utf8($html);

  }
}

1;
