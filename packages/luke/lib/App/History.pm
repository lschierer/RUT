use v5.40.0;
use utf8;
use Carp;

use Object::Pad;

package App::History;
our $VERSION = '0.00.1';

use Path::Tiny;

class App::History {

  use Path::Tiny;
  use Git::Repository;

  field $input_dir :accessor :param //= './input';

  field $output_dir :accessor :param //= './output';

  ADJUST {
    if(!rindex $input_dir, "./", 0 and !rindex $input_dir, "../", 0) {
      croak("input_dir '$input_dir' is not a valid value, must start with ./ or ../");
    }
    if (! -d -r -x $input_dir ) {
      croak(`input_dir '$input_dir' has incompatible permissions or is not a directory.`);
    }
    if(!rindex $output_dir, "./", 0 and !rindex $output_dir, "../", 0) {
      croak("output_dir '$output_dir' is not a valid value, must start with ./ or ../");
    }

    if (! -d -r -x -w $output_dir ) {
      croak(`output_dir '$output_dir' has incompatible permissions or is not a directory.`);
    }
  }

  method convert {
    say "converting files in $input_dir";
    my $r = Git::Repository->new(
      work_tree => '.',
      { cwd => undef }
    );
    my $input = path($input_dir);
    my $output = path($output_dir);

    my $result = $input->visit(
      sub {
        my ($path, $state) = @_;
        if( $path->is_file && "$path" =~ /\.mdwn$/ && -r $path) {
          my $data = $path->slurp_utf8;
          say "current path is $path";
          my $newPath = join('/', $output, $path->relative($input));
          $newPath =~ s/\.mdwn$/.md/;
          say "new path is $newPath";
        }
      },
      {recurse => 1}
    );
  }

}

1;

__END__
