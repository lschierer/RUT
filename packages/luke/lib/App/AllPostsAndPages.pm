use v5.40.0;
use utf8;

use Object::Pad;

package App::AllPostsAndPages;
our $VERSION = '0.00.1';

class App::AllPostsAndPages {
  require Path::Tiny;
  require Path::Iterator::Rule;
  require YAML::PP;

  field $logDir :param //= Path::Tiny::path('./log');
  field $outFile :param //= Path::Tiny::path('../frontend/share/home/luke/log/posts.md');
  field $ypp = YAML::PP->new(
    schema       => [qw/ + Perl /],
    yaml_version => ['1.2', '1.1'],
  );

  method compile {
    my @lines = ();
    my $rule = Path::Iterator::Rule->new();
    $rule->and( sub { -r -f $_ }, $rule->new->name(qr/\.md/));
    my $next = $rule->iter( $logDir->stringify(), {
      depthfirst      => 0, #"0" (breadth-first search)
      follow_symlinks => 0,
      loop_safe       => 1,
      sorted          => 1,
    });
    while ( defined( my $file = $next->() ) ) {
      $file = Path::Tiny::path($file);
      my $content = $file->slurp_utf8();
      my $basename = $file->basename('.md');
      my $title = $basename;
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
      my $linkDir = $file->relative($logDir->parent());
      push @lines, "  <li><a href='/~luke/$linkDir/$basename/'>$title</a></li>\n";
    }

    my $posts = Path::Tiny::path($outFile);
    $posts->touch();
    my $doc ="---\n";
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
