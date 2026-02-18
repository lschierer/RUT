package App::CalendarGenerator;
use v5.40.0;
use Object::Pad;

class App::CalendarGenerator {
  use Path::Tiny;
  use Time::Piece;

  field $source_dir : param;
  field $output_dir : param;
  field $date_manifest_file : param = undef;
  
  field $date_manifest = undef;

  method generate_all_calendars() {
    # Load date manifest if provided
    if ($date_manifest_file && -f $date_manifest_file) {
      my $json = JSON::MaybeXS->new(utf8 => 1);
      $date_manifest = $json->decode(path($date_manifest_file)->slurp_raw);
    }
    
    if ($date_manifest) {
      $self->generate_calendars_from_manifest();
    } else {
      $self->generate_calendars_from_directories();
    }
  }
  
  method generate_calendars_from_manifest() {
    my %posts_by_month;
    
    # Group posts by year/month
    for my $key (keys %$date_manifest) {
      next if $key =~ /index$/;
      my $date_str = $date_manifest->{$key};
      if ($date_str =~ /^(\d{4})-(\d{2})-(\d{2})/) {
        my ($year, $month, $day) = ($1, $2, $3);
        push @{$posts_by_month{"$year/$month"}}, int($day);
      }
    }
    
    # Generate calendar for each month
    for my $ym (keys %posts_by_month) {
      my ($year, $month) = split '/', $ym;
      my @days = sort { $a <=> $b } @{$posts_by_month{$ym}};
      $self->generate_calendar($year, $month, \@days);
    }
  }
  
  method generate_calendars_from_directories() {
    my $log_dir = path($source_dir);
    my @years =
      sort grep { $_->basename =~ /^\d{4}$/ && $_->is_dir } $log_dir->children;

    for my $year_dir (@years) {
      my $year   = $year_dir->basename;
      my @months = sort grep { $_->basename =~ /^\d{2}$/ && $_->is_dir }
        $year_dir->children;

      for my $month_dir (@months) {
        my $month = $month_dir->basename;
        my $days  = $self->get_days_with_posts($year, $month);
        next unless @$days;

        $self->generate_calendar($year, $month, $days);
      }
    }
  }

  method generate_calendar($year, $month, $days_with_posts) {
    my $archive_dir = path($output_dir)->child($year, $month);
    $archive_dir->mkpath;

    my $date_str      = sprintf("%04d-%02d-01", $year, $month);
    my $t             = Time::Piece->strptime($date_str, "%Y-%m-%d");
    my $days_in_month = $t->month_last_day;
    my $first_dow     = $t->day_of_week;    # 0=Sun, 6=Sat

    my %days_map = map { $_ => 1 } @$days_with_posts;

    my $html = qq{<table class="calendar">\n};
    $html .= qq{  <thead>\n    <tr>};
    $html .= qq{<th>Sun</th><th>Mon</th><th>Tue</th><th>Wed</th><th>Thu</th><th>Fri</th><th>Sat</th>};
    $html .= qq{</tr>\n  </thead>\n  <tbody>\n};

    my $day = 1;
    my $cell_count = 0;

    # Start first row
    $html .= qq{    <tr>\n};
    
    # Empty cells before first day
    for (my $i = 0; $i < $first_dow; $i++) {
      $html .= qq{      <td></td>\n};
      $cell_count++;
    }

    # Generate days
    while ($day <= $days_in_month) {
      if ($days_map{$day}) {
        $html .= qq{      <td class="has-posts">$day</td>\n};
      } else {
        $html .= qq{      <td>$day</td>\n};
      }
      
      $cell_count++;
      
      # End row after 7 cells
      if ($cell_count % 7 == 0 && $day < $days_in_month) {
        $html .= qq{    </tr>\n    <tr>\n};
      }
      
      $day++;
    }

    # Fill remaining cells in last row
    while ($cell_count % 7 != 0) {
      $html .= qq{      <td></td>\n};
      $cell_count++;
    }
    
    $html .= qq{    </tr>\n};
    $html .= qq{  </tbody>\n</table>};

    $archive_dir->child('calendar.html')->spew_utf8($html);
    say "  Generated calendar: $year/$month";
  }

  method get_days_with_posts($year, $month) {
    my $month_dir = path($source_dir)->child($year, $month);
    return [] unless -d $month_dir;

    my @days;
    for my $day (1 .. 31) {
      my $day_str = sprintf("%02d", $day);
      my $day_dir = $month_dir->child($day_str);
      next unless -d $day_dir;

      my @posts = grep { $_->basename =~ /\.md$/ } $day_dir->children;
      push @days, $day if @posts;
    }

    return \@days;
  }
}

1;
