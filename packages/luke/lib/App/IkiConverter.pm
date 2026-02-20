use v5.40.0;
# cspell: disable
use utf8::all;

use Object::Pad;

package App::IkiConverter;
our $VERSION = '0.00.1';

class App::IkiConverter {
  use Path::Tiny;
  use Carp;
  use DateTime::Format::ISO8601;
  use Git::Repository;
  require Pandoc;
  use List::AllUtils qw( none any );
  use HTML::Entities qw(encode_entities);
  use File::Find;

  field $source_dir  : param : reader //= './log';
  field $log_file    : param : reader //= './build-output/conversion_log.txt';
  field $skip_pandoc : param : reader //= 0;

  ADJUST {
    $source_dir = Path::Tiny::path($source_dir);
    if (!$source_dir->is_dir()) {
      croak("source_dir $source_dir is not a directory");
    }
  }

# Extract metadata from ikiwiki file
  method extract_metadata ($file_path, $content) {

    # Initialize variables
    my $title = '';
    my $date  = '';
    my %tags;

    # Extract title from meta directive
    if ($content =~ /\[\[\!meta\s+title="([^"]+)"\s*\]\]/i) {
      $title = $1;
    }

    # If no title found, use filename
    if (!$title) {
      my $base = $file_path->basename('.mdwn');
      $title = $base;
      $title =~ s/_/ /g;

      # If filename is index, use directory name
      if ($title eq 'index') {
        my $dir = $file_path->parent->basename;
        $title = $dir;
      }
    }

    # Extract date from meta directive
    if ($content =~ /\[\[\!meta\s+updated="([^"]+)"\s*\]\]/i) {
      $date = $1;
    }
    elsif ($content =~ /\[\[\!meta\s+date="([^"]+)"\s*\]\]/i) {
      $date = $1;
    }

    # Check if date is empty or only whitespace
    if (!defined($date) || $date eq '' || $date =~ /^\s*$/) {
      my $repo          = Git::Repository->new(work_tree => '.');
      my $abs_file_path = $file_path->absolute;

      # Get the git root directory
      my $git_root = path($repo->work_tree);

      # Make the file path relative to the git root
      my $rel_file_path = $abs_file_path->relative($git_root);

      my @cmd = (
        'log', '--diff-filter=A', '--follow', '--format=%cd', '--date=iso8601',
        '--',  $rel_file_path->stringify
      );
      my $output = $repo->run(@cmd);
      my @lines  = split(/\n/, $output);
      $date = $lines[-1] if @lines;
    }
    if (!defined($date) || $date eq '' || $date =~ /^\s*$/) {
      # If git fails, use current date
      my $dt = DateTime->now;
      $date = $dt->iso8601;
    }

    # Extract tags
    while ($content =~ /\[\[\!tag\s+([^\]]+?)\s*\]\]/g) {
      my $tag_line = $1;

      # Process quoted tags first
      while ($tag_line =~ s/"([^"]+)"//) {
        my $quoted_tag = $1;
        $tags{$quoted_tag}++ if $quoted_tag ne 'uncategorized';
      }

      # Then process remaining unquoted tags
      foreach my $tag (
        grep { $_ ne 'uncategorized' && $_ ne '' }
        split(/\s+/, $tag_line)
      ) {
        $tags{$tag}++;
      }

    }
    my @finalTags = keys %tags;
    @finalTags = sort @finalTags;
    return ($title, $date, \@finalTags);
  }

# Create front matter for the markdown file
  method create_front_matter ($title, $date, $tags) {

    my $front_matter = "---\n\n";
    $front_matter .= "title: \"$title\"\n";
    $front_matter .= "date: $date\n";

    if (@$tags) {
      $front_matter .= "tags:\n";
      foreach my $tag (@$tags) {
        # Quote tags with spaces for YAML
        if ($tag =~ /\s/) {
          $front_matter .= "  - \"$tag\"\n";
        }
        else {
          $front_matter .= "  - $tag\n";
        }
      }

    }

    $front_matter .= "layout: rut\n";
    $front_matter .= "---\n\n";

    return $front_matter;
  }

# Process ikiwiki content to standard markdown
  method process_content ($content) {

    # Remove meta directives
    $content =~ s/\[\[\!meta\s+title="[^"]+"\]\]\s*//g;
    $content =~ s/\[\[\!meta\s+date="[^"]+"\]\]\s*//g;
    $content =~ s/\[\[\!meta\s+updated="[^"]+"\]\]\s*//g;
    $content =~ s/\[\[\!meta\s+guid="[^"]+"\]\]\s*//g;
    $content =~ s/\[\[\!meta\s+HTML_LANG_CODE="[^"]+"\]\]\s*//g;

    # Remove tag directives
    $content =~ s/\[\[\!tag\s+[^\]]+\]\]\s*//g;

    # Convert ikiwiki image syntax
    $content =~ s/\[\[\!img\s+(\S+)\s+.*?alt="([^"]+)"\]\]/![$2]($1)/g;

    # Convert ikiwiki link syntax
    $content =~ s/\[\[([^\|]+)\|([^\]]+)\]\]/[$1]($2)/g;

    # Convert other ikiwiki directives (placeholder - expand as needed)
    $content =~
      s/\[\[\!([^\s\]]+)\s+([^\]]+)\]\]/<!-- ikiwiki directive: $1 $2 -->/g;

    return $content;
  }

  # Generate content for map directives
  # assumes all maps are for files in a directory, not recursive.
  method generate_map_content ($pattern) {

    # Get the root directory for searching
    my ($dir_name) = $pattern =~ /^([\w\/]+)/;

    # Create the path to the target directory
    my $target_dir = $source_dir->child($dir_name);

    say "Looking for files in directory: $target_dir";

    my @matching_files = ();
    # Get all immediate children of the directory
    if ($target_dir->is_dir()) {
      @matching_files = $target_dir->children(qr/\.(mdwn|md)$/);
    }
    else {
      push @matching_files, $target_dir;
    }

    # Filter out index files and directories
    @matching_files =
      grep { !$_->is_dir && $_->basename !~ /^index\.(mdwn|md)$/ }
      @matching_files;

    # Sort files
    @matching_files = sort @matching_files;
    say "found " . scalar @matching_files . " files in $target_dir";

    # Generate markdown list
    my $content = "\n\n## Pages\n\n";

    if (@matching_files) {
      foreach my $file (@matching_files) {
        # Get the basename without extension
        my $basename = $file->basename;
        $basename =~ s/\.(mdwn|md)$//;

        # Convert to title
        my $title = $basename;
        $title =~ s/_/ /g;

        # Create relative link path
        (my $link_path =
            '/~luke/' . $source_dir . '/' . $dir_name . '/' . $basename . '/')
          =~ s{/+}{/}g;

        $content .= "- [$title]($link_path)\n";
      }
    }
    else {
      $content .= "*No matching pages found*\n";
    }

    return $content;

  }

# Validate markdown using Pandoc
  method clean_and_validate_markdown ($content) {

    # Create a new Pandoc instance
    my $pandoc = Pandoc->new();

    # First, convert from markdown (with embedded HTML) to Pandoc's AST
    my $ast = $pandoc->convert(
      'markdown_mmd+footnotes+raw_html' => 'json',
      $content
    );

    # Then convert from AST back to clean markdown
    my $clean_markdown = $pandoc->convert(
      'json' => 'gfm+footnotes',
      $ast
    );

    # Return the cleaned markdown
    return $clean_markdown;

  }

  # Convert a single ikiwiki file
  method convert_file ($mdwn_file) {

    my $result = {
      success => 0,
      md_file => '',
      error   => '',
    };

    # Get file paths
    my $dir     = $mdwn_file->parent();
    my $base    = $mdwn_file->basename('.mdwn');
    my $md_file = $dir->child("$base.md");
    $result->{md_file} = "$md_file";
    # Read the source file
    my $content = $mdwn_file->slurp_utf8;

    # Capture redirect pages — record target but still skip conversion
    if ($content =~ /\[\[\!meta\s+redir="([^"]+)"\]\]/i) {
      my $relative_path = $mdwn_file->relative($source_dir)->stringify;
      $result->{redirect}        = $1;
      $result->{redirect_source} = $relative_path;
      $result->{error}           = "Redirect page to $1";
      return $result;
    }

    # Process map directives if present
    if ($content =~ /\[\[\!map\s+pages="([^"]+)"\s*\]\]/i) {
      my $pattern     = $1;
      my $map_content = $self->generate_map_content($pattern,);
      $content =~ s/\[\[\!map\s+pages="[^"]+"\s*\]\]/$map_content/g;
    }

    # Extract metadata
    my ($title, $date, $tags) = $self->extract_metadata($mdwn_file, $content);

    # Create front matter
    my $front_matter = $self->create_front_matter($title, $date, $tags);

    # Process content
    my $processed_content = $self->process_content($content);
    my $clean_content;
    if ($skip_pandoc) {
      $clean_content = $processed_content;
    }
    else {
      $clean_content = $self->clean_and_validate_markdown($processed_content);
    }
    # Combine front matter and processed content
    my $final_content = $front_matter . $clean_content;

    # Clean and validate the markdown

    $md_file->spew_utf8($final_content);
    $result->{success} = 1;

    return $result;

  }

  # Main function to convert ikiwiki files
  method convert_ikiwiki_files {

    # Create log file directory if it doesn't exist
    path($log_file)->parent->mkdir({ mode => 0711 })
      unless path($log_file)->parent->exists;

    # Open log file
    my $log = path($log_file)->openw_utf8();

    # Find all .mdwn files
    my @files;
    my $logIter = $source_dir->iterator({
      recurse         => 1,
      follow_symlinks => 0,
    });
    my $path;
    while ($path = $logIter->()) {
      if ($path->stringify() =~ m/\.mdwn$/) {
        push @files, $path
          unless $path->stringify() eq
          $source_dir->child('index.md')->stringify();
      }
    }

    # Sort files for consistent processing
    @files = sort @files;

    # Process each file
    foreach my $mdwn_file (@files) {
      my $result = $self->convert_file($mdwn_file);

      if ($result->{success}) {
        print $log "Converted $mdwn_file to $result->{md_file}\n";
      }
      else {
        print $log "Skipped $mdwn_file: $result->{error}\n";
      }
    }

    close $log;
    return scalar(@files);
  }

  # Selective conversion: only converts files where manifest says 'reconvert'
  method convert_ikiwiki_files_selective ($manifest) {

    # Create log file directory if it doesn't exist
    path($log_file)->parent->mkdir({ mode => 0711 })
      unless path($log_file)->parent->exists;

    my $log = path($log_file)->openw_utf8();
    my @redirects;

    # Find all .mdwn files
    my @files;
    my $logIter = $source_dir->iterator({
      recurse         => 1,
      follow_symlinks => 0,
    });
    my $path;
    while ($path = $logIter->()) {
      if ($path->stringify() =~ m/\.mdwn$/) {
        push @files, $path
          unless $path->stringify() eq
          $source_dir->child('index.md')->stringify();
      }
    }

    @files = sort @files;
    my $converted = 0;
    my $skipped   = 0;

    foreach my $mdwn_file (@files) {
      # Check manifest for corresponding .md file
      my $rel_md = $mdwn_file->relative($source_dir)->stringify;
      $rel_md =~ s/\.mdwn$/.md/;

      if (exists $manifest->{$rel_md} && $manifest->{$rel_md} eq 'keep') {
        print $log "Kept (manual edits): $mdwn_file\n";
        $skipped++;
        next;
      }

      my $result = $self->convert_file($mdwn_file);

      if ($result->{redirect}) {
        push @redirects,
          {
          source => $result->{redirect_source},
          target => $result->{redirect},
          };
        print $log "Redirect: $mdwn_file -> $result->{redirect}\n";
      }
      elsif ($result->{success}) {
        print $log "Converted $mdwn_file to $result->{md_file}\n";
        $converted++;
      }
      else {
        print $log "Skipped $mdwn_file: $result->{error}\n";
      }
    }

    close $log;
    say "Converted: $converted, Skipped (kept): $skipped, Redirects: "
      . scalar(@redirects);
    return \@redirects;
  }
}
1;

__END__

=head1 NAME

App::IkiConverter - Convert ikiwiki formatted .mdwn files to GFM markdown

=head1 SYNOPSIS

  use App::IkiConverter qw(convert_ikiwiki_files);

  # Convert all .mdwn files in the log directory
  my $count = convert_ikiwiki_files('./log', './dist/conversion_log.txt');
  print "Processed $count files\n";

=head1 DESCRIPTION

This module provides functionality to convert ikiwiki formatted .mdwn files to
standard GFM markdown .md files. It handles:

- Extracting and converting ikiwiki metadata to YAML front matter
- Converting ikiwiki directives to standard markdown
- Validating the resulting markdown
- Logging conversion results
- Removing original files after successful conversion

=head1 FUNCTIONS

=head2 convert_ikiwiki_files($source_dir, $log_file)

Converts all .mdwn files in the specified directory to .md files.

Parameters:
- $source_dir: Directory containing .mdwn files (default: './log')
- $log_file: Path to log file (default: './dist/conversion_log.txt')

Returns: Number of files processed

=head2 convert_file($mdwn_file)

Converts a single ikiwiki file to markdown.

Parameters:
- $mdwn_file: Path to the .mdwn file

Returns: Hash reference with keys:
- success: Boolean indicating if conversion was successful
- md_file: Path to the output .md file
- error: Error message if conversion failed

=head1 INTERNAL FUNCTIONS

=head2 extract_metadata($file_path, $content)

Extracts title, date, and tags from ikiwiki content.

=head2 create_front_matter($title, $date, $tags)

Creates YAML front matter from extracted metadata.

=head2 process_content($content)

Processes ikiwiki content to convert it to standard markdown.



=cut
