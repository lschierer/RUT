use v5.40.0;
use utf8::all;

use Object::Pad;

package App::ConversionManifest;
our $VERSION = '0.00.1';

class App::ConversionManifest {
  use Path::Tiny;
  use Carp;
  use Git::Repository;

  field $source_dir : param : reader //= './log';

  # Commit messages that indicate a bulk conversion (not a manual edit)
  my @CONVERSION_PATTERNS = (
    qr/\bfeat:\s*content\s+conversion\b/i,
    qr/\bfeat:\s*convert\s+content\b/i,
    qr/\bbuild:\s*format\s+conversion\b/i,
    qr/\bconvert\s+ikiwiki\b/i,
    qr/\bbulk\s+convert\b/i,
    qr/\bauto-convert\b/i,
  );

  ADJUST {
    $source_dir = Path::Tiny::path($source_dir);
    if (!$source_dir->is_dir()) {
      croak("source_dir $source_dir is not a directory");
    }
  }

  method _is_conversion_commit ($message) {
    for my $pattern (@CONVERSION_PATTERNS) {
      return 1 if $message =~ $pattern;
    }
    return 0;
  }

  method analyze_all () {
    my %manifest;

    my $repo     = Git::Repository->new(work_tree => '.');
    my $git_root = path($repo->work_tree);

    # Find all .md files under source_dir
    my $iter = $source_dir->iterator({ recurse => 1, follow_symlinks => 0 });
    my @md_files;
    while (my $file = $iter->()) {
      next unless $file->stringify =~ /\.md$/;
      push @md_files, $file;
    }

    for my $file (sort @md_files) {
      my $rel = $file->relative($git_root)->stringify;

      # Get all commits touching this file
      my $output = eval {
        $repo->run('log', '--format=%H %s', '--follow', '--', $rel);
      };
      next unless $output;

      my @lines = split /\n/, $output;
      next unless @lines;

      # First line is most recent commit, last line is creation commit
      my $has_manual_edit = 0;

      # Skip the creation commit (last line), check if any non-creation
      # commit is NOT a conversion commit
      for my $i (0 .. $#lines) {
        my ($hash, $message) = $lines[$i] =~ /^(\S+)\s+(.*)/;
        next unless $hash;

        # If this commit is not a conversion commit, it's a manual edit
        unless ($self->_is_conversion_commit($message)) {
          # But skip if it's the only commit (initial creation)
          if (@lines == 1) {
            # Single commit — likely the conversion itself or initial creation
            # Mark as reconvert (it was never manually edited)
            last;
          }
          $has_manual_edit = 1;
          last;
        }
      }

      my $rel_to_source = $file->relative($source_dir)->stringify;
      $manifest{$rel_to_source} = $has_manual_edit ? 'keep' : 'reconvert';
    }

    return \%manifest;
  }
}

1;
__END__

=head1 NAME

App::ConversionManifest - Analyze git history to classify .md files for selective re-conversion

=head1 SYNOPSIS

  my $cm = App::ConversionManifest->new(source_dir => './log');
  my $manifest = $cm->analyze_all();
  # { 'path/to/file.md' => 'keep', 'path/to/other.md' => 'reconvert' }

=head1 DESCRIPTION

Examines git commit history for each .md file to determine whether it has
been manually edited after conversion. Files with only conversion-related
commits are marked C<reconvert>; files with manual edits are marked C<keep>.

=cut
