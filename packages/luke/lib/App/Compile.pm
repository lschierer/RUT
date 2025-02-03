use v5.40.0;
use utf8;

use Object::Pad;

package App::Compile;
our $VERSION = '0.00.1';

class App::Compile {

  use Array::Merge::Unique qw/unique_array/;
  use HTML::FormatMarkdown;
  use List::AllUtils qw( any none apply extract_by  uniqstr );
  use Path::Tiny;
  use Data::Printer;
  use Git::Wrapper;
  use Try::Tiny;
  use Cwd;
  use Carp;

  field $input_dir :accessor :param //= './input';

  field $greenwoodRoot :accessor :param //= './greenwood';

  field $output_dir :accessor = path($greenwoodRoot)->child('src', 'pages','luke','log');

  field $tag_file :accessor = path($greenwoodRoot, 'src', 'lib', "tags.ts");

  field $assets :accessor = path($greenwoodRoot, 'src', 'assets');

  field $tags :accessor = ();



  ADJUST {
    if(!rindex $input_dir, "./", 0 and !rindex $input_dir, "../", 0) {
      croak("input_dir '$input_dir' is not a valid value, must start with ./ or ../");
    }

    if (! -d -r -x $input_dir ) {
      croak("input_dir '$input_dir' has incompatible permissions or is not a directory.");
    }

    $input_dir = path($input_dir);
    if (! -d -r -x $greenwoodRoot ) {
      croak("greenwoodRoot '$greenwoodRoot' has incompatible permissions or is not a directory.");
    }

    if(!rindex $greenwoodRoot, "./", 0 and !rindex $greenwoodRoot, "../", 0) {
      croak("greenwoodRoot '$greenwoodRoot' is not a valid value, must start with ./ or ../");
    }

    $greenwoodRoot = path($greenwoodRoot)->absolute();



    if(!rindex $output_dir, "./", 0 and !rindex $output_dir, "../", 0) {
      croak("output_dir '$output_dir' is not a valid value, must start with ./ or ../");
    }

    if (! -d -r -x -w $output_dir ) {
      croak("output_dir '$output_dir' has incompatible permissions or is not a directory.");
    }

    if(!rindex $tag_file, "./", 0 and !rindex $tag_file, "../", 0) {
      croak("tag_file '$tag_file' is not a valid value, must start with ./ or ../");
    }

    if (! -f -r -w $tag_file ) {
      croak("tag_file '$tag_file' has incompatible permissions or is not a file.");
    }
  }

  method check_for_images ($path) {
    my $strings = [];
    my @lines = $path->lines_utf8();
    foreach my $line (@lines) {
      if( $line =~ /!\[.+?\]/ ) {
        say ("potential image in $path");
        if( $line =~ /!\[.+?\]\((.+?)\)/ ) {
          my $file = $path->sibling($1);
          say ("found file $file in $path");
          my $newPath = path(join('/', $assets, 'log', $file->relative($input_dir)));
          my $parent = $newPath->parent();
          $parent->mkdir({ mode => 0751 });
          $file->copy("$newPath");
        }
      }
    }
  }

  method read_tags {
    my @originalTags = path($tag_file)->lines_utf8();
    say("original tags were " . p @originalTags);
    my @newTags = ();
    push(@newTags, $originalTags[0]);

    for my $tl (@originalTags) {
      if( $tl =~ /\{ "(.+?)": (\d+) \},/ ) {
        my $tag_name = $1;
        my $tag_count = $2;
        say ("found tag $tag_name with count $tag_count");
        if ( exists $tags->{$tag_name} ) {
          $tags->{$tag_name} = $tags->{$tag_name} + $tag_count;
        } else {
          $tags->{$tag_name} = $tag_count;
        }
        my $newLine = sprintf('{ "%s": %d },', $tag_name, $tags->{$tag_name});
        push(@newTags, $newLine);
      }
    }
    my $tagLength = scalar @originalTags;
    push(@newTags, $originalTags[$tagLength - 2]);
    push(@newTags, $originalTags[$tagLength - 1]);
    path($tag_file)->spew_utf8(@newTags);
  }

  method run {

    my $git = Git::Wrapper->new('.');

    say("processing .md files in $input_dir");

    my $result = $input_dir->visit(
      sub {
        my ($path, $state) = @_;
        if ($path->is_file && "$path" =~ /\.md$/ && -r $path ) {

          my $newPath = path(join('/', $output_dir, $path->relative($input_dir)));

          my $parent = $newPath->parent();
          $parent->touchpath();
          $path->copy("$newPath");
          my @lines = $path->lines_utf8();
          my $in_fontmatter = 0;
          my $in_tags = 0;
          foreach my $line (@lines) {
            if($line =~ /^---+$/ ) {
              if($in_fontmatter == 0)
              {
                $in_fontmatter = 1;
              }
              else {
                $in_fontmatter = 0;
              }
              next;
            }
            if($in_fontmatter == 1) {
              if( $line =~ /^tags:\h*$/ ) {
                $in_tags = 1;
                next;
              }
              if($in_tags == 1) {
                if( $line =~ /^\h+-\h+(.+?)\h*$/ ) {
                  my $tag = $1;
                  $tags->{$1}++;
                  next;
                }
                else {
                  $in_tags = 0;
                  #however keep processing; do NOT next;
                }
              }
            }
            else {
              if($line =~ /!\[.+?\]/) {
                $self->check_for_images($path);
              }
            }
          }
        }
      }, {recurse => 1}
    );

    $self->read_tags();
  }


}


1;

__END__
