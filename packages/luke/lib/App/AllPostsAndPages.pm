use v5.40.0;
use utf8;

use Object::Pad;

package App::AllPostsAndPages;
our $VERSION = '0.00.1';

class App::AllPostsAndPages {
  require Path::Tiny;
  require Path::Iterator::Rule;
  require YAML::PP;

  field $logDir : param //= Path::Tiny::path('./log');
  field $outFile : param //=
    Path::Tiny::path('../frontend/share/home/luke/log/posts.md');
  field $ypp = YAML::PP->new(
    schema       => [qw/ + Perl /],
    yaml_version => ['1.2', '1.1'],
  );

  method compile {
    my %by_dir;
    my $rule = Path::Iterator::Rule->new;
    $rule->and(sub { -r -f $_ }, $rule->new->name(qr/\.md$/));

    my $next = $rule->iter(
      $logDir->stringify,
      {
        depthfirst      => 0,
        follow_symlinks => 0,
        loop_safe       => 1,
        sorted          => 1,
      }
    );

    while (defined(my $file = $next->())) {
      my $path = Path::Tiny::path($file);
      my $dir  = $path->parent->stringify;
      push @{ $by_dir{$dir} }, $path;
    }

    my @lines;
    for my $dir (sort keys %by_dir) {
      my @files = sort {
        ($a->basename eq 'index.md' ? -1 : 0)
          <=> ($b->basename eq 'index.md' ? -1 : 0)
          || $a->basename cmp $b->basename
      } @{ $by_dir{$dir} };

      for my $file (@files) {
        my $is_index = $file->basename eq 'index.md';
        my $is_root_index =
          $is_index && $file->parent->stringify eq $logDir->stringify;

        next if $is_root_index;
        my $content   = $file->slurp_utf8();
        my $basename  = $file->basename('.md');
        my $title     = $basename;
        my $yaml_data = {};
        if ($content =~ s/^---\s*\n(.*?)\n---\s*\n//s) {
          my $yaml = $1;
          eval { $yaml_data = $ypp->load_string($yaml); };
          if ($@) {
            say "Error parsing YAML front matter: $@";
          }
          elsif (ref $yaml_data eq 'HASH') {
            # Use title from front matter if available
            $title = $yaml_data->{title}
              if exists $yaml_data->{title};
          }
        }
        my $linkDir = $file->relative($logDir->parent())->parent();
        if ($basename ne 'index') {
          push @lines,
            "  <li><a href='/~luke/$linkDir/$basename/'>$title</a></li>\n";
        }
        else {
          push @lines, "  <li><a href='/~luke/$linkDir/'>$title</a></li>\n";
        }
      }
    }

    my $posts = Path::Tiny::path($outFile);
    $posts->touch();
    my $doc = "---\n";
    $doc .= "title: All Posts and Pages\n";
    $doc .= "author: Luke Schierer\n";
    $doc .= "layout: rut\n";
    $doc .= "---\n";
    $doc .= "\n<ul>\n\n" . join('', @lines) . "\n\n</ul>";
    $posts->spew_utf8($doc);

  }

};
1;

__END__
