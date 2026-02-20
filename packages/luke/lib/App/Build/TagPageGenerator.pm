use v5.40.0;
use utf8;

use Object::Pad;

package App::Build::TagPageGenerator;
our $VERSION = '0.00.1';

class App::Build::TagPageGenerator {
  use YAML::XS;
  use Path::Tiny;
  use JSON::MaybeXS;

  field $source_dir : param;
  field $output_dir : param;
  field $date_manifest_file : param = undef;

  method generate_all() {
    my %tag_to_posts;
    my %post_titles;

    # Scan markdown files for tags
    my $log_dir = path($source_dir)->child('log');
    my $iter = $log_dir->iterator({ recurse => 1 });

    while (my $file = $iter->()) {
      next unless $file->is_file && $file->basename =~ /\.md$/;
      next if $file->basename =~ /^index\.md$/;

      my $content = $file->slurp_utf8;
      next unless $content =~ /^---\s*\n(.*?)\n---/sm;

      my $frontmatter = eval { YAML::XS::Load($1) };
      next unless $frontmatter && ref $frontmatter eq 'HASH';

      my $tags = $frontmatter->{tags};
      next unless $tags && ref $tags eq 'ARRAY';

      my $rel_path = $file->relative($log_dir)->stringify;
      $rel_path =~ s/\.md$//;
      my $post_key = "log/$rel_path";

      my $title = $frontmatter->{title} // $rel_path;
      $post_titles{$post_key} = $title;

      for my $tag (@$tags) {
        push @{ $tag_to_posts{$tag} }, $post_key;
      }
    }

    # Generate individual tag pages
    $self->generate_tag_pages(\%tag_to_posts, \%post_titles);

    # Generate tag index/summary
    $self->generate_tag_index(\%tag_to_posts);

    # Return tag list for sidebar
    return [sort keys %tag_to_posts];
  }

  method generate_tag_pages($tag_to_posts, $post_titles) {
    my $tag_dir = path($output_dir)->child('log', 'tags');
    $tag_dir->mkpath;

    for my $tag (sort keys %$tag_to_posts) {
      my $tag_file = $tag_dir->child("$tag.md");

      my $content = "---\n";
      $content .= "title: \"Tagged: $tag\"\n";
      $content .= "layout: rut\n";
      $content .= "template: luke/log_entry\n";
      $content .= "tag: \"$tag\"\n";
      $content .= "---\n\n";
      $content .= "## Posts tagged with '$tag'\n\n";

      for my $post_key (sort {
        ($post_titles->{$a} // $a) cmp ($post_titles->{$b} // $b)
      } @{ $tag_to_posts->{$tag} }) {
        my $title = $post_titles->{$post_key} // $post_key;
        my $url = "/~luke/$post_key";
        $content .= "- [$title]($url)\n";
      }

      $tag_file->spew_utf8($content);
      say "  Generated tag page: $tag";
    }
  }

  method generate_tag_index($tag_to_posts) {
    my $index_file = path($output_dir)->child('log', 'tags', 'index.md');

    my $content = "---\n";
    $content .= "title: \"Tags\"\n";
    $content .= "layout: rut\n";
    $content .= "template: luke/log_entry\n";
    $content .= "---\n\n";
    $content .= "## All Tags\n\n";
    $content .= "| Tag | Posts |\n";
    $content .= "|-----|-------|\n";

    for my $tag (
      sort {
        my $count_cmp = @{ $tag_to_posts->{$b} } <=> @{ $tag_to_posts->{$a} };
        return $count_cmp || lc($a) cmp lc($b);
      } keys %$tag_to_posts
    ) {
      my $count = scalar @{ $tag_to_posts->{$tag} };
      my $link = "/~luke/log/tags/$tag";
      $content .= "| [$tag]($link) | $count |\n";
    }

    $index_file->spew_utf8($content);
    say "  Generated tag index";
  }
}

1;
