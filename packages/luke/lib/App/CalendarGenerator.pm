use v5.40.0;
use utf8::all;

use Object::Pad;

package App::CalendarGenerator;
our $VERSION = '0.00.1';

class App::CalendarGenerator {
  use Path::Tiny;
  use Carp;
  use DateTime;
  require Date::Manip;
  require Data::Printer;
  use Git::Repository;
  use File::Path     qw(make_path);
  use List::Util     qw(uniq);
  use HTML::Entities qw(encode_entities);

  field $source_dir : param : reader //= './log';
  field $output_dir : param : reader;
  field $git_repo : reader;

  ADJUST {
    $source_dir = Path::Tiny::path($source_dir);
    if (!$source_dir->is_dir()) {
      croak("source_dir $source_dir is not a directory");
    }

    if (!defined $output_dir) {
      croak("output_dir is required");
    }

    $output_dir = Path::Tiny::path($output_dir);
    if (!-d $output_dir) {
      $output_dir->mkdir({mode => 0710 });
    }

    # Initialize Git repository
    $git_repo = Git::Repository->new(work_tree => $source_dir->stringify);
  }

  method all_calendars {
    my $now = DateTime->now();

    my $last_month = 12;
    for my $year (2005 .. $now->year()) {
      # Process each year
      my $last_month = 12;
      for my $month (1 .. 12) {
        # Skip future months in the current year
        if ($year == $now->year() && $month > $now->month()) {
          $last_month = $month;
          next;
        }

        # Generate calendar for this year/month
        $self->generate_calendar($year, $month);
      }
      $self->year_summary_index($year, $last_month);
    }

  }

  method year_summary_index ($year, $last_month = 12) {
    my $year_index =
      Path::Tiny::path($output_dir, $year, "index.md");
    my $content = <<MARKDOWN;

---
title: Archives for $year
date: $year-01-01
layout: rut
---

# Archive pages $year

MARKDOWN

    foreach my $month (1 .. $last_month) {
      $content .= "- [$month](./$month/)\n";
    }
    $content .= "\n";
    $year_index->spew_utf8($content);
  }

  method generate_calendar ($year, $month) {
    # Validate input
    $year  = int($year);
    $month = int($month);

    if ($year < 1900 || $year > 2100 || $month < 1 || $month > 12) {
      croak("Invalid year or month: $year-$month");
    }

    # Create DateTime object for the specified month
    my $dt = DateTime->new(
      year  => $year,
      month => $month,
      day   => 1
    );

    # Get the number of days in the month
    my $days_in_month = $dt->month_length;

    # Get the day of week for the first day (0 = Sunday, 6 = Saturday)
    my $first_day_dow = $dt->day_of_week % 7;  # Convert to 0-based Sunday start

    # Create month directory if it doesn't exist
    my $month_dir = $output_dir->child($year, sprintf("%02d", $month));
    $month_dir->mkdir({ mode => 0711 });

    # Generate calendar HTML
    my $calendar_html =
      $self->_generate_calendar_html($year, $month, $days_in_month,
      $first_day_dow);

    # Write calendar HTML to file
    my $calendar_file = $month_dir->child("calendar.html");
    $calendar_file->spew_utf8($calendar_html);

    # Generate day pages for days with content
    $self->_generate_day_pages($year, $month, $days_in_month, $month_dir);

    return $calendar_file->stringify;
  }

  method _generate_calendar_html($year, $month, $days_in_month, $first_day_dow)
  {
    my $dt         = DateTime->new(year => $year, month => $month, day => 1);
    my $month_name = $dt->month_name;

    my $html = <<HTML;
<div class="calendar-nav">
  <h3>$month_name $year</h3>
  <table class="calendar">
    <tr>
      <th>Sun</th>
      <th>Mon</th>
      <th>Tue</th>
      <th>Wed</th>
      <th>Thu</th>
      <th>Fri</th>
      <th>Sat</th>
    </tr>
HTML

    # Start with empty cells for days before the 1st
    my $current_day = 1;
    my $current_dow = 0;

    $html .= "<tr>";

    # Add empty cells before the first day
    for (my $i = 0; $i < $first_day_dow; $i++) {
      $html .= "<td></td>";
      $current_dow++;
    }

    # Add cells for each day of the month
    while ($current_day <= $days_in_month) {
      # Start a new row if needed
      if ($current_dow == 0) {
        $html .= "<tr>";
      }

      # Format the day with leading zero
      my $day_formatted = sprintf("%02d", $current_day);

      # Check if this day has content
      my $day_file =
        $output_dir->child($year, sprintf("%02d", $month), "$day_formatted.md");
      my $has_content = -f $day_file;

      # Create the cell with or without a link
      if ($has_content) {
        $html .=
qq{<td><a href="/~luke/log/archive/$year/sprintf("%02d", $month)/$day_formatted/">$current_day</a></td>};
      }
      else {
        $html .= "<td>$current_day</td>";
      }

      $current_day++;
      $current_dow++;

      # End the row if it's Saturday
      if ($current_dow == 7) {
        $html .= "</tr>";
        $current_dow = 0;
      }
    }

    # Add empty cells for days after the last day
    if ($current_dow > 0) {
      for (my $i = $current_dow; $i < 7; $i++) {
        $html .= "<td></td>";
      }
      $html .= "</tr>";
    }

    $html .= "</table></div>";

    return $html;
  }

  method _generate_day_pages($year, $month, $days_in_month, $month_dir) {
    # For each day in the month
    for my $day (1 .. $days_in_month) {
      # Format date for git command
      my $date_start = sprintf("%04d-%02d-%02d 00:00:00", $year, $month, $day);
      my $date_end   = sprintf("%04d-%02d-%02d 23:59:59", $year, $month, $day);

      # Get files modified on this day
      my @files = $self->_get_files_modified_on_date($date_start, $date_end);

      # Skip if no files were modified
      next unless @files;

      # Generate markdown content
      my $content = $self->_generate_day_content($year, $month, $day, \@files);

      # Write to file
      my $day_file = $month_dir->child(sprintf("%02d.md", $day));
      $day_file->spew_utf8($content);
    }
  }

  method _get_files_modified_on_date($date_start, $date_end) {
    # Extract year, month, day from date_start
    my ($year, $month, $day) = $date_start =~ /^(\d{4})-(\d{2})-(\d{2})/;

    # Get all commits for this day
    my $cmd_commits = [
      'log',   '--pretty=format:%H',
      '--all', "--after=$date_start",
      "--before=$date_end"
    ];

    my $commits_output = $git_repo->run(@$cmd_commits);
    my @commits        = split(/\n/, $commits_output);

    # No commits found for this day
    return () unless @commits;

    my %unique_files;

    # Process each commit to find modified files
    foreach my $commit (@commits) {
      # Get files changed in this commit
      my $cmd_show = ['show', '--name-only', '--oneline', $commit];

      my $show_output = $git_repo->run(@$cmd_show);
      my @lines       = split(/\n/, $show_output);

      # Skip the first line (commit message)
      shift @lines;

      # Process each file
      foreach my $file (@lines) {
        next unless $file;
        next unless $file =~ /\.(md|mdwn)$/;

        # Store unique files
        $unique_files{$file} = 1;
      }
    }

    # Process each unique file to generate proper paths
    my @result_files;
    foreach my $file (keys %unique_files) {
      # Skip files that don't exist in the repository anymore
      my $full_path = Path::Tiny::path($file);
#nearly nothing will exist until we start looking at rewriting the path to be relative to the ~luke/log directory.
#next unless -e $full_path;

      # Add to result list
      push @result_files, $file;
    }

    return @result_files;
  }

  method _generate_day_content($year, $month, $day, $files) {
    my $date = sprintf("%04d-%02d-%02d", $year, $month, $day);
    my $dt   = DateTime->new(year => $year, month => $month, day => $day);
    my $formatted_date = $dt->strftime("%B %d, %Y");

    my $content = <<MARKDOWN;
---
title: "Changes on $formatted_date"
date: $date
layout: rut
---

## Files modified on $formatted_date

MARKDOWN

    foreach my $file (@$files) {
      my $title = $self->_get_file_title($file);

      # Process the link path based on file location
      my $link_path;
      my $base_path = $file;
      $base_path =~ s/\.(md|mdwn)$//;    # Remove extension

      $file =~ s{^(?:/)?(?:import|posts|luke-wiki\@schierer\.org)/}{/log/};
      if ($base_path eq 'index') {
        $link_path = $file;
        $link_path =~ s{index(?:\.(?:md|mdwn|html))}{};
      }
      # Check if path contains 'log' component
      if ($file =~ m{/log/}) {
        # Extract relative path from the log component
        $file =~ m{(.*?/log/)(.*)};
        my $after_log = $2;
        $link_path = "/~luke/log/$after_log";
        $link_path =~ s/\.(md|mdwn)$//;    # Remove extension if still present

      }
      else {
        # No log component, use full path
        $link_path = "/~luke/log/$base_path/";
      }
      $link_path .= '/' unless $link_path =~ m{/$};
      if ($link_path =~ m{^/~luke/log/(?:archives|tags)/}) {
        next;
      }
      $content .= "* [$title]($link_path)\n";
    }

    return $content;
  }

  method _get_file_title($file_path) {
    my $path = Path::Tiny::path($file_path);

    # Default to filename if file doesn't exist
    unless ($path->exists) {
      my $basename = $path->basename;
      $basename =~ s/\.\w+$//;    # Remove extension
      $basename =~ s/_/ /g;       # Replace underscores with spaces
      return $basename;
    }

    # Try to extract title from file content
    my $content = $path->slurp_utf8;

    # Check for YAML frontmatter title
    if ($content =~ /^---\s*\n(.*?)\n---\s*\n/s) {
      my $frontmatter = $1;
      if ($frontmatter =~ /title:\s*["']?(.*?)["']?\s*$/m) {
        return $1;
      }
    }

    # Check for ikiwiki meta title
    if ($content =~ /\[\[\!meta\s+title="([^"]+)"\s*\]\]/i) {
      return $1;
    }

    # Check for # Heading
    if ($content =~ /^#\s+(.+)$/m) {
      return $1;
    }

    # Fall back to filename
    my $basename = $path->basename;
    $basename =~ s/\.\w+$//;    # Remove extension
    $basename =~ s/_/ /g;       # Replace underscores with spaces
    return $basename;
  }
}

1;
