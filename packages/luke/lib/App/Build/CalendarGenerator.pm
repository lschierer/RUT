package App::Build::CalendarGenerator;
use v5.40.0;
use Object::Pad;
# cspell: disable

class App::Build::CalendarGenerator {
  use Path::Tiny;
  use JSON::MaybeXS;
  use Time::Piece;

  field $source_dir         : param;
  field $output_dir         : param;
  field $date_manifest_file : param = undef;
  field $posts_by_date_file : param = undef;

  field $date_manifest = undef;
  field $posts_by_date = undef;

  method generate_all_calendars() {
    # Load pre-computed posts_by_date if available
    if ($posts_by_date_file && -f $posts_by_date_file) {
      my $json = JSON::MaybeXS->new(utf8 => 1);
      $posts_by_date = $json->decode(path($posts_by_date_file)->slurp_raw);
      $self->generate_calendars_from_posts_by_date();
      return;
    }

    # Fallback: compute from date manifest
    if ($date_manifest_file && -f $date_manifest_file) {
      my $json = JSON::MaybeXS->new(utf8 => 1);
      $date_manifest = $json->decode(path($date_manifest_file)->slurp_raw);
      $self->generate_calendars_from_manifest();
      return;
    }

    # Last resort: directory scanning
    $self->generate_calendars_from_directories();
  }

  method generate_calendars_from_posts_by_date() {
    my %days_by_month;

    # Extract days from posts_by_date
    for my $ymd (grep {m{^\d{4}/\d{2}/\d{2}$}} keys %$posts_by_date) {
      my ($year, $month, $day) = split '/', $ymd;
      push @{ $days_by_month{"$year/$month"} }, int($day);
    }

    # Generate calendar for each month
    for my $ym (sort keys %days_by_month) {
      my ($year, $month) = split '/', $ym;
      my @days = sort { $a <=> $b } @{ $days_by_month{$ym} };
      $self->generate_calendar($year, $month, \@days);
    }
  }

  method generate_calendars_from_manifest() {
    my %posts_by_month;

    # Group posts by year/month
    for my $key (sort keys %$date_manifest) {
      next if $key =~ /index$/;
      my $date_str = $date_manifest->{$key};
      if ($date_str =~ /^(\d{4})-(\d{2})-(\d{2})/) {
        my ($year, $month, $day) = ($1, $2, $3);
        push @{ $posts_by_month{"$year/$month"} }, int($day);
      }
    }

    # Generate calendar for each month
    for my $ym (sort keys %posts_by_month) {
      my ($year, $month) = split '/', $ym;
      my @days = sort { $a <=> $b } @{ $posts_by_month{$ym} };
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

    my $html = qq{<div class="spectrum-Calendar">\n};
    $html .=
qq{ <h4 class="spectrum-Heading spectrum-Heading--sizeXXS">$date_str</h4>\n };
    $html .= qq{  <table class="spectrum-Calendar-table">\n};
    $html .= qq{    <thead>\n      <tr>};

    for my $day (qw(Sun Mon Tue Wed Thu Fri Sat)) {
      $html .=
qq{<th class="spectrum-Calendar-tableCell"><abbr class="spectrum-Calendar-dayOfWeek" title="$day">$day</abbr></th>};
    }

    $html .=
      qq{</tr>\n    </thead>\n    <tbody class="spectrum-Calendar-body">\n};

    my $day        = 1;
    my $cell_count = 0;

    # Start first row
    $html .= qq{      <tr>\n};

    # Empty cells before first day
    for (my $i = 0; $i < $first_dow; $i++) {
      $html .= qq{        <td class="spectrum-Calendar-tableCell"></td>\n};
      $cell_count++;
    }

    # Generate days
    while ($day <= $days_in_month) {
      my $class   = "spectrum-Calendar-date";
      my $day_str = sprintf("%02d", $day);

      if ($days_map{$day}) {
        # Day has posts - make it a link
        my $url = "/~luke/log/archive/$year/$month/$day_str/";
        $html .=
qq{        <td class="spectrum-Calendar-tableCell"><a href="$url" class="$class spectrum-Link spectrum-Link--secondary spectrum-Link--quiet">$day</a></td>\n};
      }
      else {
        # No posts - mark as disabled
        $class .= " is-disabled";
        $html .=
qq{        <td class="spectrum-Calendar-tableCell"><span class="$class">$day</span></td>\n};
      }

      $cell_count++;

      # End row after 7 cells
      if ($cell_count % 7 == 0 && $day < $days_in_month) {
        $html .= qq{      </tr>\n      <tr>\n};
      }

      $day++;
    }

    # Fill remaining cells in last row
    while ($cell_count % 7 != 0) {
      $html .= qq{        <td class="spectrum-Calendar-tableCell"></td>\n};
      $cell_count++;
    }

    $html .= qq{      </tr>\n};
    $html .= qq{    </tbody>\n  </table>\n</div>};

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
