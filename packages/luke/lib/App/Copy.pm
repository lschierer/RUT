use v5.40.0;
use utf8;

use Object::Pad;

package App::Copy;
our $VERSION = '0.00.1';

class App::Copy {

  use Array::Merge::Unique qw/unique_array/;
  use List::AllUtils       qw( any none apply extract_by uniqstr );
  use Path::Tiny;
  use File::Basename qw(fileparse);
  use Data::Printer;
  use Try::Tiny;
  use Cwd;
  use Carp;
  use File::Copy;
  use File::Path qw(make_path);

  field $input_dir : accessor : param //= './input';

  field $targetRoot : accessor : param //= './frontend';

  field $output_dir : accessor =
    path($targetRoot)->child('share', 'home', 'luke');

  field $assets : accessor = path($output_dir, 'assets');

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

    # Ensure assets directory exists
    if (!-d $assets) {
      $assets->mkdir({
        mode => 0711,
      });
    }
  }

  # Copy files from input directory to output directory
  method copy_files() {
    my $input_dir_abs = $input_dir->absolute;
    say "start of copy_files\n\n";

    # Process all files recursively
    $input_dir->visit(
      sub {
        my ($path, $state) = @_;
        return if $path->is_dir;    # Skip directories

        # Get relative path from input directory
        my $rel_path = $path->relative($input_dir_abs)->stringify;
        $rel_path =~ s/staticAssets\///;
        $rel_path = Path::Tiny::path($rel_path);

        # Determine file type and destination
        my ($filename, $dirs, $suffix) =
          fileparse($path->stringify(), qr"\..[^.]*$");
        my $ext = lc($suffix || '');
        say "processing $path with extension $ext";

        if ( $ext eq '.html'
          || $ext eq '.txt'
          || $ext eq '.pdf'
          || $ext eq '.css') {

          # Copy HTML and PDF files to output_dir preserving path
          my $dest = path($output_dir, $rel_path);
          $self->_copy_file($path, $dest);
        }
        elsif ($ext eq '.png'
          || $ext eq '.jpg'
          || $ext eq '.svg'
          || $ext eq '.gif') {
          # Copy graphics files to assets directory preserving path
          my $dest = path($assets, $rel_path);
          $self->_copy_file($path, $dest);
        }

        # Ignore other file types
      },
      {
        recurse         => 1,
        follow_symlinks => 1,
      }    # Enable recursive directory traversal
    );

    return 1;
  }

  # Helper method to copy a file ensuring the destination directory exists
  method _copy_file($src, $dest) {

    # Create parent directories if they don't exist
    my $parent = $dest->parent;
    if (!-d $parent) {
      $parent->mkdir({ mode => 0711 })
        ;    # mkdir in Path::Tiny is recursive by default
    }

    # Copy the file
    croak("Failed to copy $src to $dest") unless $src->copy($dest);
    say "Copied: $src -> $dest";

  }

};
1;
