use v5.40.0;
use utf8::all;

use Object::Pad;

package App::RecentChanges;
our $VERSION = '0.00.1';

class App::RecentChanges {
  use Exporter qw(import);
  require JSON::PP;
  require YAML::PP;

  use Path::Tiny;
  use HTML::Entities qw(encode_entities);
  use Git::Repository;
  use List::AllUtils qw( first any );
  use DateTime;
  use DateTime::Format::ISO8601;
  use Carp;

  our @EXPORT_OK = qw(update_recent_changes generate_git_history);

  BEGIN {
    require Data::Printer;
  }

  field $repo = Git::Repository->new(work_tree => '.');

  field @excluded_commits = qw(
    00521e38 62e2825d d642ed21
    abdb7103 695cb529 77e74db5
    eeb8a0d2 e22afbdc c0ca2c99
    b5290af8 d4b572c5 6dfadc75
    0c5b42c4 8c987f5f eb1d753e
    f713ecba 18768f9c 9e300976
    4a1c3918 a2939e60 8017a8a2
    8f1ab293 5f4098ea 4ba63b05
    4c35add1 543232ea d7fdaaab
    c872a572 3ed7e3c0 8bafdeba
    072ed455 117dfe89 3d751bf1
    61151706 ab5f297f fc793a8d
    cc6e84b6 85a0105c 4ab4ee62
    9a92c5aa 9d20e0a9 46f3e45f
    d4b57afc 47ecf079 d361b355
    8b50da56 4b8c30f2 901acc0e
    a1c60e0b 2e01a64f 087bfc94
    99174ee8 70ef2b87 62869f07
    09737f68 fdd3023e
  );

  field $json =
    JSON::PP->new()
    ->utf8()
    ->relaxed()
    ->allow_unknown()
    ->allow_blessed()
    ->convert_blessed()
    ->canonical();

  field $ypp = YAML::PP->new(
    schema       => [qw/ + Perl /],
    yaml_version => ['1.2', '1.1'],
  );

  field $RUT_dir = Path::Tiny::path("./log");

  # Update the log/index.md file with recent changes
  method update_recent_changes {
    my ($json_file, $md_file, $limit) = @_;
    $limit //= 100;    # Default to 100 entries

    # Read the JSON file

    my $json_content = path($json_file)->slurp_utf8;
    my $data;
    $data = $json->decode($json_content);

    # Filter entries with non-empty files array and limit to specified number
    my @filtered_entries;
    foreach my $entry (@$data) {
      next unless $entry->{files} && @{ $entry->{files} } > 0;
      push @filtered_entries, $entry;
      last if scalar(@filtered_entries) >= $limit;
    }

    # Generate the definition list HTML
    my $dl_html = "<dl class=\"recent-changes\">\n";

    foreach my $entry (@filtered_entries) {

      my $short_id   = substr($entry->{id}, 0, 12);
      my $commit_url = "https://github.com/lschierer/RUT/commit/$entry->{id}";
      if ( (!exists $entry->{files})
        or (ref($entry->{files}) ne 'ARRAY')
        or (scalar @{ $entry->{files} } == 0)) {
        next;
      }

      my %displayedPaths;
      my $files_html = '';
      foreach my $file (@{ $entry->{files} }) {

        # Clean up the file name
        $file =~ s/^\s+|\s+$//g;
        $file =~ s/^"(.*)"$/$1/ if $file =~ /^".*"$/;
        next unless $file;

        # Extract just the filename without extension and path
        # Handle both .md and .mdwn extensions
        if ($file =~ m{(?:packages/)?(?:luke/)?(?:log/)?(.+?)\.(?:md|mdwn)$}) {
          my $path         = $1;
          my $display_name = $path;

          # Get just the last part of the path for display name
          if ($path =~ m{.*/([^/]+)$}) {
            $display_name = $1;
          }
          if (!exists $displayedPaths{ encode_entities($path) }) {
            $displayedPaths{ encode_entities($path) }++;

            if (Path::Tiny::path("./log/$path.md")->is_file()) {
              my $content   = Path::Tiny::path("./log/$path.md")->slurp_utf8();
              my $yaml_data = {};
              if ($content =~ s/^---\s*\n(.*?)\n---\s*\n//s) {
                my $yaml = $1;
                eval { $yaml_data = $ypp->load_string($yaml); };
                if ($@) {
                  say "Error parsing YAML front matter: $@";
                }
                elsif (ref $yaml_data eq 'HASH') {
                  # Use title from front matter if available
                  $display_name = $yaml_data->{title}
                    if exists $yaml_data->{title};
                }
              }
              # Create the link with the desired format
              $files_html .=
"    <li><a href=\"/~luke/log/$path/\">$display_name</a></li>\n";
            }
            elsif (Path::Tiny::path("./log/$path.mdwn")->is_file()) {
              $files_html .=
"    <li><a href=\"/~luke/log/$path/\">$display_name</a></li>\n";
            }
            else {
              $displayedPaths{ encode_entities($path) }--;
              if ($displayedPaths{ encode_entities($path) } <= 0) {
                $displayedPaths{ encode_entities($path) } = undef;
                delete $displayedPaths{ encode_entities($path) };
              }
            }

          }
          if (keys %displayedPaths > 10) {
            my $remaining = scalar @{ $entry->{files} };
            $remaining = $remaining - (keys %displayedPaths);
            say "I have $remaining entries I am skipping for $short_id";
            if ($remaining == 1) {
              $files_html .= "    <li>and $remaining additional file.</li>\n";
            }
            elsif ($remaining > 1) {
              $files_html .= "    <li>and $remaining additional files.</li>\n";
            }
            last;
          }

        }
        else {
          # Fallback for files that don't match the expected pattern
          $files_html .= "    <li>" . encode_entities($file) . "</li>\n";
        }
      }

      my $entry_html = '';
      # Format the date as ISO 8601
      my $timestamp = $entry->{date};
      my $dt        = DateTime->from_epoch(epoch => $timestamp);
      my $iso_date  = $dt->iso8601();

      # Get the commit message (first line of the message array)
      my $message = $entry->{message} // '';

      # Add to the definition list
      $entry_html .= "  <dt><a href=\"$commit_url\">$short_id</a></dt>\n";
      $entry_html .= "  <dd>$iso_date</dd>\n";
      $entry_html .= "  <dd>$message</dd>\n";
      $entry_html .= "  <dd>\n";
      $entry_html .= "    <ul class=\"filelist\">\n";
      $entry_html .= $files_html;
      $entry_html .= "    </ul>\n";
      $entry_html .= "  <dd>\n";
      my @paths = keys %displayedPaths;

      if (scalar @paths >= 1) {

        say "$short_id has keys " . Data::Printer::np(@paths);
        $dl_html .= $entry_html;
      }
      else {
        say "skipping $short_id";
      }
    }

    $dl_html .= "</dl>\n";

    # Read the markdown file
    my $md_content = path($md_file)->slurp_utf8;

    # Replace the placeholder with the definition list
    $md_content =~ s/<recent-changes><\/recent-changes>/$dl_html/;

    # Write the updated content back to the file
    path($md_file)->spew_utf8($md_content);

    return scalar(@filtered_entries);   # Return the number of entries processed
  }

  # Generate git history JSON file
  method generate_git_history {
    my ($output_file, $repo_path) = @_;
    $repo_path //= '../..';             # Default to parent of parent directory

    my $history = [];

    # Create the output directory if it doesn't exist
    $output_file = path($output_file);
    my $output_dir = $output_file->parent;
    $output_dir->mkdir({ mode => 0711 }) unless ($output_dir->exists);

    # Get the list of commit IDs to process
    my @log = $repo->run(
      'log',                  '--oneline',
      '--full-history',       '--color=never',
      '--decorate=short',     '--grep',
      '^build: ',             '--grep',
      'calendar update',      '--invert-grep',
      '--',                   '.',
      ':!packages/greenwood', ':**/*.md(wn)?',
    );

    # Process the output to get clean commit IDs
    my @commit_ids;
    foreach my $line (@log) {
      my ($commit_id, $summary) = split / /, $line, 2;
      $line =~ s/^(\w+) .+$/$1/;
      my @ids = split(/\s+/, $line);
      @ids = grep { $_ && $_ =~ /^[0-9a-f]{7,40}$/i } @ids;

      foreach my $id (@ids) {
        push @commit_ids, $id unless any { $id =~ m/^$_/ } @excluded_commits;
      }

    }

    say "Found " . scalar(@commit_ids) . " commit IDs to process";

    # Process each commit
    my $first = 1;
    my $count = 0;

    foreach my $commit_id (@commit_ids) {
      last
        if $count >= 1000
        ;    # Process more than needed to ensure we have enough after filtering

      # Get commit details
      my $message = join "\n",
        $repo->run('log', '--format=%B', '-n', 1, $commit_id);
      chomp($message);
      my $timestamp   = $repo->run('log', '--format=%at', '-n', 1, $commit_id);
      my @filesResult = $repo->run('show', '--no-renames', '--pretty=reference',
        '--color=never', '--stat=1000', $commit_id);

      my @files = ();

      # Skip the first line (commit reference line)
      shift @filesResult;

      # Skip any empty lines at the beginning
      while (@filesResult && $filesResult[0] =~ /^\s*$/) {
        shift @filesResult;
      }
      # Process each line until we hit the summary line
      foreach my $al (@filesResult) {
        # Stop when we hit the summary line (e.g., "4 files changed...")
        last if $al =~ /^\s*\d+\s+files?\s+changed/;

        # Skip empty lines
        next if $al =~ /^\s*$/;

        # Extract filename from diffstat line
        if ($al =~ /^\s*(.*?)\s+\|\s+\d+/) {
          my $filename = $1;
          # Trim any leading/trailing whitespace
          $filename =~ s/^\s+|\s+$//g;
          if ($filename !~ m/index\.md$/) {
            push @files, $filename if $filename;
          }
        }
      }

      $first = 0;

      my $object = {};
      $object->{id}      = $commit_id;
      $object->{message} = $message;
      $object->{date}    = $timestamp;
      $object->{files}   = \@files;
      if ($object->{message} =~ m/^(?:fix|break):/) {
        next;
      }
      push(@{$history}, $object);
      $count++;
    }

    my $json_text = $json->encode($history);
    $output_file->spew_utf8($json_text);
    return $count;
  }

};

1;

__END__

=head1 NAME

App::RecentChanges - Update markdown files with recent git commit information

=head1 SYNOPSIS

  use App::RecentChanges qw(update_recent_changes generate_git_history);

  # Generate the git history JSON file
  generate_git_history('./tmp/commitHistory.json');

  # Update the markdown file with recent changes
  update_recent_changes('./tmp/commitHistory.json', './log/index.md', 100);

=head1 DESCRIPTION

This module provides functions to generate a JSON file containing git commit history
and to update a markdown file with a definition list of recent changes.

=head1 FUNCTIONS

=head2 update_recent_changes($json_file, $md_file, $limit)

Updates the specified markdown file by replacing the <recent-changes></recent-changes>
placeholder with a definition list of recent changes from the JSON file.

Parameters:
- $json_file: Path to the JSON file containing commit history
- $md_file: Path to the markdown file to update
- $limit: Maximum number of entries to include (default: 100)

=head2 generate_git_history($output_file, $repo_path)

Generates a JSON file containing git commit history.

Parameters:
- $output_file: Path where the JSON file should be written
- $repo_path: Path to the git repository (default: ../..)

=cut
