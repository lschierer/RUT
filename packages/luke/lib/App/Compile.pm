use v5.40.0;
use utf8;

use Object::Pad;

package App::Compile;
our $VERSION = '0.00.1';

class App::Compile {
  require App::RecentChanges;
  require App::TagPageGenerator;
  require App::AllPostsAndPages;
  require App::CalendarGenerator;
  require File::Temp;
  use Array::Merge::Unique qw/unique_array/;
  use HTML::FormatMarkdown;
  use List::AllUtils qw( any none apply extract_by  uniqstr );
  use Path::Tiny;
  use Data::Printer;
  use Git::Wrapper;
  use Try::Tiny;
  use Cwd;
  use Carp;

  field $input_dir : accessor : param //= './input';

  field $targetRoot : accessor : param //= './frontend';

  field $output_dir : accessor =
    path($targetRoot)->child('share', 'home', 'luke');

  field $log_dir : accessor = path($output_dir)->child('log');

  field $assets : accessor = path($output_dir, 'assets');

  field $tags : accessor = ();

  ADJUST {
    if (!rindex $input_dir, "./", 0 and !rindex $input_dir, "../", 0) {
      croak(
        "input_dir '$input_dir' is not a valid value, must start with ./ or ../"
      );
    }

    if (!-d -r -x $input_dir) {
      croak(
"input_dir '$input_dir' has incompatible permissions or is not a directory."
      );
    }

    $input_dir = path($input_dir);
    if (!-d -r -x $targetRoot) {
      croak(
"targetRoot '$targetRoot' has incompatible permissions or is not a directory."
      );
    }

    if (!rindex $targetRoot, "./", 0 and !rindex $targetRoot, "../", 0) {
      croak(
"targetRoot '$targetRoot' is not a valid value, must start with ./ or ../"
      );
    }

    $targetRoot = path($targetRoot)->absolute();

    if (!rindex $output_dir, "./", 0 and !rindex $output_dir, "../", 0) {
      croak(
"output_dir '$output_dir' is not a valid value, must start with ./ or ../"
      );
    }

    if (!-d -r -x -w $output_dir) {
      $output_dir->mkdir({
        mode => 0711,
      });
    }

  }

  method check_for_images ($path) {
    my $strings = [];
    my @lines   = $path->lines_utf8();
    foreach my $line (@lines) {
      if ($line =~ /!\[.+?\]/) {
        say("potential image in $path");
        if ($line =~ /!\[.+?\]\((.+?)\)/) {
          my $file = $path->sibling($1);
          say("found file $file in $path");
          my $newPath =
            path(join('/', $assets, $file->relative($input_dir)));
          my $parent = $newPath->parent();
          $parent->mkdir({ mode => 0751 });
          $file->copy("$newPath");
        }
      }
    }
  }

  method getTags {
    my $tpg = App::TagPageGenerator->new(
      input  => $input_dir->stringify(),
      output => $output_dir->stringify(),
    );
    $tpg->generate_tags();
  }

  method getCalendars ($gitdir) {
    my $calendarOut = $output_dir->child('log', 'archive');
    $calendarOut->mkdir({ mode => 0711 }) unless $calendarOut->is_dir();
    my $cg = App::CalendarGenerator->new(
      source_dir => $input_dir->child('log'),
      git_repo   => $gitdir,
      output_dir => $calendarOut->stringify(),
    );
    $cg->all_calendars();
  }

  method _process_file ($path, $state) {
    if ($path->is_file && "$path" =~ /\.md$/ && -r $path) {

      my $relative_path = $path->relative($input_dir);
      my $obase = $output_dir->basename();
      my $newPath;
      if ($relative_path =~ m{^$obase/}) {
          # Path already starts with 'log', don't add it again
          $newPath = path(join('/', $output_dir->parent(), $relative_path));
      } else {
          # Path doesn't start with 'log', add it
          $newPath = path(join('/', $output_dir , $relative_path));
      }

      my $parent = $newPath->parent();
      $newPath->touchpath();
      $path->copy("$newPath");
      my @lines         = $path->lines_utf8();
      my $in_fontmatter = 0;
      my $in_tags       = 0;
      foreach my $line (@lines) {
        if ($line =~ /^---+$/) {
          if ($in_fontmatter == 0) {
            $in_fontmatter = 1;
          }
          else {
            $in_fontmatter = 0;
          }
          next;
        }
        if ($in_fontmatter == 1) {
          if ($line =~ /^tags:\h*$/) {
            $in_tags = 1;
            next;
          }
          if ($in_tags == 1) {
            if ($line =~ /^\h+-\h+(.+?)\h*$/) {
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
          if ($line =~ /!\[.+?\]/) {
            $self->check_for_images($path);
          }
        }
      }
      if ($path->absolute()->stringify eq
        Path::Tiny::path('./log/index.md')->absolute()->stringify) {
        my $rc    = App::RecentChanges->new();
        my $posts = App::AllPostsAndPages->new();
        $posts->compile();
        my $temp = File::Temp->new(
          UNLINK => 1,
          SUFFIX => '.dat',
          PERMS  => 0640,
        );

        my $limit = 100;

        my $commits_processed = $rc->generate_git_history($temp);
        my $dl_entries = $rc->update_recent_changes($temp, $newPath, $limit);

      }
    }
  }

  method run {

    my $git = Git::Wrapper->new('.');

    say("processing .md files in $input_dir");
    my $process_file_ref = sub {
      my ($path, $state) = @_;
      $self->_process_file($path, $state);
    };
    my $result = $input_dir->visit($process_file_ref, { recurse => 1 });

    $self->getTags();
    $self->getCalendars($git->dir());

  }

}

1;

__END__
