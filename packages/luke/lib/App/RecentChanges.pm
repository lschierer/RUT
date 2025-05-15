use v5.40.0;
use utf8;

use Object::Pad;

package App::RecentChanges;
our $VERSION = '0.00.1';

class App::RecentChanges {
  use Exporter qw(import);
  our @EXPORT_OK = qw(update_recent_changes generate_git_history);

  require JSON::PP;
  use Path::Tiny;
  use IPC::Cmd qw(run);
  use DateTime;
  use DateTime::Format::ISO8601;

  field $json =
    JSON::PP->new()
    ->utf8()
    ->relaxed()
    ->allow_unknown()
    ->allow_blessed()
    ->convert_blessed()
    ->canonical();

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

      # Format the date as ISO 8601
      my $timestamp = $entry->{date};
      my $dt        = DateTime->from_epoch(epoch => $timestamp);
      my $iso_date  = $dt->iso8601();

      # Get the commit message (first line of the message array)
      my $message = $entry->{message} // '';

      # Add to the definition list
      $dl_html .= "  <dt><a href=\"$commit_url\">$short_id</a></dt>\n";
      $dl_html .= "  <dd>$iso_date</dd>\n";
      $dl_html .= "  <dd>$message</dd>\n";
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
    my $cmd =
"cd $repo_path && git log --oneline --full-history --color=never --decorate=short "
      . "--grep \"^build: \" --grep \"calendar update\" --invert-grep -- . ':!packages/greenwood' ':**/*.md(wn)?' | "
      . "egrep -v '(00521e38|62e2825d|d642ed21|abdb7103|695cb529|77e74db5|eeb8a0d2|e22afbdc|c0ca2c99|b5290af8|d4b572c5|6dfadc75|0c5b42c4|8c987f5f|eb1d753e)' | "
      . "cut -d ' ' -f 1";

    my ($success, $error_code, $full_buf, $stdout_buf, $stderr_buf) =
      run(command => $cmd, verbose => 0);

    if (!$success) {
      die "Failed to get git commit IDs: " . join("\n", @$stderr_buf);
    }

    # Process the output to get clean commit IDs
    my @commit_ids;
    foreach my $line (@$stdout_buf) {
      chomp($line);

      # Split the line in case there are multiple IDs or extra spaces
      my @ids = split(/\s+/, $line);
      push @commit_ids, grep { $_ && length($_) > 0 } @ids;
    }

    say "Found " . scalar(@commit_ids) . " commit IDs to process";

    # Process each commit
    my $first = 1;
    my $count = 0;

    foreach my $commit_id (@commit_ids) {
      last
        if $count >=
        200; # Process more than needed to ensure we have enough after filtering

      # Get commit details
      my $full_id_cmd = "cd $repo_path && git log --format=%H -n 1 $commit_id";
      my ($success1, $error_code1, $full_buf1, $stdout_buf1) =
        run(command => $full_id_cmd, verbose => 0);

      if (!$success1 || !$stdout_buf1 || !@$stdout_buf1) {
        say "Failed to get full ID for $commit_id";
        next;
      }

      my $full_id = $stdout_buf1->[0];
      chomp($full_id);

      my $message_cmd = "cd $repo_path && git log --format=%B -n 1 $commit_id";
      my ($success2, $error_code2, $full_buf2, $stdout_buf2) =
        run(command => $message_cmd, verbose => 0);
      my @message_lines = @$stdout_buf2;
      chomp(@message_lines);

      my $date_cmd = "cd $repo_path && git log --format=%at -n 1 $commit_id";
      my ($success3, $error_code3, $full_buf3, $stdout_buf3) =
        run(command => $date_cmd, verbose => 0);
      my $date = $stdout_buf3->[0];
      chomp($date);

      my $files_cmd =
"cd $repo_path && git show --no-renames --pretty=reference --color=never --stat=1000 $commit_id | "
        . "tail -n +3 | ghead -n -1 | cut -d '|' -f 1 | tr -s '[:blank:]' | "
        . "egrep \".md(wn)?( )?\$\" | grep -v \"index.md\"";
      my ($success4, $error_code4, $full_buf4, $stdout_buf4) =
        run(command => $files_cmd, verbose => 0);
      my @files = @$stdout_buf4;
      chomp(@files);

      if (!$success4 || !$stdout_buf4 || !@$stdout_buf4) {
        say "no files for $full_id, error was '$error_code4'";
      }
      $first = 0;

      my $object = {};
      $object->{id}      = $full_id;
      $object->{message} = join(' ', @message_lines);
      $object->{date}    = $date;
      $object->{files}   = \@files;
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
