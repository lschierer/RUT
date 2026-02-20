use v5.40.0;
use utf8::all;

use Object::Pad;

package App::Build::DateManifest;
our $VERSION = '0.00.1';

class App::Build::DateManifest {
  use Path::Tiny;
  use Carp;
  use Git::Repository;
  use JSON::MaybeXS;

  field $source_dir  : param : reader //= '.';
  field $output_file : param : reader //= './build-output/dates.json';

  ADJUST {
    $source_dir = Path::Tiny::path($source_dir);
    if (!$source_dir->is_dir()) {
      croak("source_dir $source_dir is not a directory");
    }
  }

  method _extract_frontmatter_date ($file) {
    my $content = $file->slurp_utf8;

    # Quick check for YAML frontmatter
    return undef unless $content =~ /^---\s*\n/;

    my ($yaml_text) = $content =~ /^---\s*\n(.*?)\n---/s;
    return undef unless $yaml_text;

    # Extract date field from frontmatter
    if ($yaml_text =~ /^date:\s*(.+)$/m) {
      my $date = $1;
      $date                 =~ s/^\s+|\s+$//g;
      $date                 =~ s/^["']|["']$//g;
      return $date if $date =~ /\d{4}/;            # Basic sanity check
    }
    return undef;
  }

  method _extract_ikiwiki_date ($mdwn_file) {
    return undef unless $mdwn_file->exists;
    my $content = $mdwn_file->slurp_utf8;

    # Try updated first, then date
    if ($content =~ /\[\[\!meta\s+updated="([^"]+)"\s*\]\]/i) {
      return $1;
    }
    if ($content =~ /\[\[\!meta\s+date="([^"]+)"\s*\]\]/i) {
      return $1;
    }
    return undef;
  }

  method _get_git_creation_date ($file) {
    my $repo     = Git::Repository->new(work_tree => '.');
    my $git_root = path($repo->work_tree);
    my $rel      = $file->absolute->relative($git_root)->stringify;

    my $output = eval {
      $repo->run('log', '--diff-filter=A', '--follow',
        '--format=%cd', '--date=iso8601-strict', '--', $rel);
    };
    return undef unless $output;

    my @lines = split /\n/, $output;
    return $lines[-1] if @lines;
    return undef;
  }

  method build_manifest () {
    my %dates;
    my $log_dir = $source_dir->child('log');

    unless ($log_dir->is_dir) {
      croak("log directory not found: $log_dir");
    }

    # Scan for all content files under log/
    my $iter = $log_dir->iterator({ recurse => 1, follow_symlinks => 0 });
    my @content_files;
    while (my $file = $iter->()) {
      next unless $file->stringify =~ /\.(md|mdwn)$/;
      push @content_files, $file;
    }

   # Deduplicate by base path (prefer .md over .mdwn for frontmatter extraction)
    my %by_base;
    for my $file (sort @content_files) {
      my $rel = $file->relative($source_dir)->stringify;
      (my $base = $rel) =~ s/\.(md|mdwn)$//;
      $by_base{$base} //= {};
      if ($rel =~ /\.md$/) {
        $by_base{$base}{md} = $file;
      }
      else {
        $by_base{$base}{mdwn} = $file;
      }
    }

    for my $base (sort keys %by_base) {
      my $entry = $by_base{$base};
      my $date;

      # Priority 1: frontmatter date from .md file
      if ($entry->{md}) {
        $date = $self->_extract_frontmatter_date($entry->{md});
      }

      # Priority 2: ikiwiki meta date from .mdwn source
      if (!$date && $entry->{mdwn}) {
        $date = $self->_extract_ikiwiki_date($entry->{mdwn});
      }

      # Priority 3: git first-commit date
      if (!$date) {
        my $file = $entry->{md} // $entry->{mdwn};
        $date = $self->_get_git_creation_date($file);
      }

      $dates{$base} = $date if $date;
    }

    # Write output
    my $out = path($output_file);
    $out->parent->mkpath;
    my $json = JSON::MaybeXS->new(utf8 => 1, canonical => 1, pretty => 1);
    $out->spew_raw($json->encode(\%dates));

    say "Wrote " . scalar(keys %dates) . " date entries to $output_file";
    return \%dates;
  }
}

1;
__END__

=head1 NAME

App::Build::DateManifest - Pre-compute absolute dates for blog content

=head1 SYNOPSIS

  my $dm = App::Build::DateManifest->new(source_dir => '.');
  my $dates = $dm->build_manifest();

=head1 DESCRIPTION

Scans all content files under log/ and extracts dates using a priority order:

1. YAML frontmatter C<date> field from .md files
2. C<[[!meta updated="..."]]> or C<[[!meta date="..."]]> from .mdwn sources
3. Git first-commit date (fallback)

Output is written to C<build-output/dates.json> as a JSON object mapping
extensionless relative paths to ISO 8601 date strings.

=cut
