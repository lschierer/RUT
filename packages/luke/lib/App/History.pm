use v5.40.0;
use utf8;
use Carp;

use Object::Pad;

package App::History;
our $VERSION = '0.00.1';

class App::History {

  use Array::Merge::Unique qw/unique_array/;
  use HTML::FormatMarkdown;
  use List::AllUtils qw( any none apply extract_by  uniqstr );
  use Path::Tiny;
  use Data::Printer;
  use Git::Wrapper;
  use Try::Tiny;
  use Cwd;

  field $input_dir :accessor :param //= './input';

  field $output_dir :accessor :param //= './output';

  field $tag_dir :accessor :param //= './tagdir';

  field $globalTags :accessor = [];

  ADJUST {
    if(!rindex $input_dir, "./", 0 and !rindex $input_dir, "../", 0) {
      croak("input_dir '$input_dir' is not a valid value, must start with ./ or ../");
    }

    if (! -d -r -x $input_dir ) {
      croak("input_dir '$input_dir' has incompatible permissions or is not a directory.");
    }

    if(!rindex $output_dir, "./", 0 and !rindex $output_dir, "../", 0) {
      croak("output_dir '$output_dir' is not a valid value, must start with ./ or ../");
    }

    if (! -d -r -x -w $output_dir ) {
      croak("output_dir '$output_dir' has incompatible permissions or is not a directory.");
    }

    if(!rindex $tag_dir, "./", 0 and !rindex $tag_dir, "../", 0) {
      croak("tag_dir '$tag_dir' is not a valid value, must start with ./ or ../");
    }

    if (! -d -r -x -w $tag_dir ) {
      croak("tag_dir '$tag_dir' has incompatible permissions or is not a directory.");
    }
  }

  method convert {

    my $git = Git::Wrapper->new('.');
    my $input = path($input_dir);
    #my $input = path("./log/science/");
    my $output = path($output_dir);
    my %tagHash = ();

    say "converting files in $input";
    my $result = $input->visit(
      sub {
        my ($path, $state) = @_;
        if( $path->is_file && "$path" =~ /\.mdwn$/ && -r $path) {
          print("\r\n\r\n\r\n");
          say "current path is $path";
          my $newPath = join('/', $output, $path->relative($input));
          $newPath =~ s/\.mdwn$/.md/;
          $newPath = path($newPath);
          say "new path is $newPath";
          my @frontmatter = ();
          push(@frontmatter, '---');

          my @data = $path->lines_utf8({chomp => 0});
          say("read ", scalar @data, " lines of data");

          my $title = "";
          my $author = "";
          my $date = "";
          my @tags = ();

          my @meta = ();
          foreach my $datum (@data) {
            $datum =~ s/\v//g;

            say("datum is |$datum|");
            my $loopindex = 0;
            while ($datum =~ /^\[\[!meta\h+?((date|updated|author|title|sortas){1}="(.+?)"(\h*?))+(\]\])?$/g) {
              my $directive = $2;
              my $value = $3;
              my $posVal = pos($datum);
              $loopindex++;
              push(@meta, ($directive, $value));
              if($directive eq 'title') {
                $title = $value;
              }
              if($directive eq 'author') {
                $author = $value;
              }
              if($directive eq 'updated') {
                $date = $value;
              }
              if($directive eq 'date' && length($date) == 0) {
                $date = $value;
              }
            }
            while( $datum =~ /\[\[!tag\h+([-a-zA-Z0-9]+)\]\]/g ) {
              my $t = $1;
              if(defined $t and length($t) > 0) {
                $loopindex++;
                say("found potential tag $t");
                if( ! any { $_ =~ /$t/ } @tags ) {
                  push(@tags, $t);
                }
              }
            }
            if($loopindex) {
              $datum = "";
            }
          }

          say( "meta is ");
          Data::Printer::p(@meta);

          if(length($date) == 0) {
            say "third date else, trust git's mod time";
            my @logs = $git->RUN("log",
              '--diff-filter=A',
              '--follow',
              '--format=%cd',
              '--date=iso8601',
              "$path"
            );
            $date = pop(@logs);
            say "git found date '$date'";

          }

          if($title =~ m/:/) {
            push(@frontmatter, "title: > ");
            push(@frontmatter, "$title");
            push(@frontmatter, "");
          } else {
            push(@frontmatter, "title: $title ");
          }

          push(@frontmatter, "date: $date");

          if(length($author) > 0) {
            push(@frontmatter, "author: $author");
          }

          if(scalar @tags > 0) {
            push(@frontmatter, "tags: ");
            foreach my $t (@tags) {
              push(@frontmatter, "  - $t");
            }
          }

          push(@frontmatter, "layout: rut");
          push(@frontmatter, '---');

          foreach my $datum (@data) {

            #a meta tag I don't actually care about
            $datum =~ s/\[\[!meta\h+guid(.*?)\h*?\]\]//gm;

            #fix images
            $datum =~s/\[\[\!img\s+?(\S*?)\h+?alt="(.*?)"]]/![$2]($1)/g;

            #ikiwiki links to markdown links
            $datum =~ s/\[\[(.+?)\|(\S+)\]\]/[$1]($2)/gm;
            #ikiwiki does a lot of "I will find the page for you."
            #I am not sure there *is* a reasonable match for raw wiki links with no path.
            $datum =~ s/\[\[(\S+?)\]\]/[$1](.\/$1\/)/gm;

          }


          my $parent = $newPath->parent();
          $parent->mkdir({ mode => 0751 });
          $newPath->touch();
          my $newFH = $newPath->openw_utf8() or die "Could not open file '$newPath' $!";
          for (@frontmatter) {
            print $newFH "$_\n";
          }
          print $newFH "\n";

          foreach my $line (@data) {
            print $newFH "$line\n";
          }
          close $newFH;

          for my $tk (@{tags}) {
            if($tk ne 'uncategorized') {
              say "key '$tk'";
              if(defined $tagHash{$tk}) {
                $tagHash{$tk}++;
              } else {
                $tagHash{$tk} = 1;
              }
            }
          }

          $globalTags = unique_array($globalTags, @tags);

        }
      },
      {recurse => 1}
    );

    p(%tagHash, max_depth => 3);


    if(scalar @$globalTags > 0) {

      my $libTag = path($tag_dir)->child('tags.ts');
      say "libTag is $libTag";
      $libTag->touch();
      my $tagFH = $libTag->openw_utf8() or die "Could not open file $libTag";

      print $tagFH "const tagNames = [\n";

      for my $tk (@{$globalTags}) {
        say "key '$tk'";
        if(defined $tagHash{$tk}) {
          if(substr($tk, 0, 1) ne '"') {
            print $tagFH sprintf(" { \"%s\": %d },\n", $tk, $tagHash{$tk});
          }
          else {
            print $tagFH sprintf(" { %s: %d },\n", $tk, $tagHash{$tk});
          }
        }
      }
      print $tagFH "];\n";
      print $tagFH "export default tagNames;\n";

      $tagFH->close();
    }
  }

}

1;

__END__
