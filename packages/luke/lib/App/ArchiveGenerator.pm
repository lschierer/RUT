package App::ArchiveGenerator;
use v5.40.0;
use Object::Pad;
# cspell: disable

class App::ArchiveGenerator {
  use Path::Tiny;
  use JSON::MaybeXS;

  field $source_dir : param;
  field $output_dir : param;
  field $date_manifest_file : param = undef;
  field $posts_by_date_file : param = undef;
  
  field $date_manifest = undef;
  field $posts_by_date = undef;

  method generate_all_indexes() {
    # Load pre-computed posts_by_date if available
    if ($posts_by_date_file && -f $posts_by_date_file) {
      my $json = JSON::MaybeXS->new(utf8 => 1);
      $posts_by_date = $json->decode(path($posts_by_date_file)->slurp_raw);
      $self->generate_indexes_from_posts_by_date();
      return;
    }
    
    # Fallback: compute from date manifest
    if ($date_manifest_file && -f $date_manifest_file) {
      my $json = JSON::MaybeXS->new(utf8 => 1);
      $date_manifest = $json->decode(path($date_manifest_file)->slurp_raw);
      $self->generate_indexes_from_manifest();
      return;
    }
    
    # Last resort: directory scanning
    $self->generate_indexes_from_directories();
  }
  
  method generate_indexes_from_posts_by_date() {
    # Generate year indexes
    for my $year (sort grep { !/\// } keys %$posts_by_date) {
      $self->generate_year_index($year, $posts_by_date->{$year});
    }
    
    # Generate month indexes
    for my $ym (sort grep { m{^\d{4}/\d{2}$} } keys %$posts_by_date) {
      my ($year, $month) = split '/', $ym;
      $self->generate_month_index($year, $month, $posts_by_date->{$ym});
    }
    
    # Generate day indexes
    for my $ymd (sort grep { m{^\d{4}/\d{2}/\d{2}$} } keys %$posts_by_date) {
      my ($year, $month, $day) = split '/', $ymd;
      $self->generate_day_index($year, $month, $day, $posts_by_date->{$ymd});
    }
  }
  
  method generate_indexes_from_manifest() {
    my %posts_by_date;
    
    # Group posts by year/month/day
    for my $key (keys %$date_manifest) {
      next if $key =~ /index$/;
      my $date_str = $date_manifest->{$key};
      if ($date_str =~ /^(\d{4})-(\d{2})-(\d{2})/) {
        my ($year, $month, $day) = ($1, $2, $3);
        push @{$posts_by_date{"$year/$month/$day"}}, $key;
        push @{$posts_by_date{"$year/$month"}}, $key;
        push @{$posts_by_date{$year}}, $key;
      }
    }
    
    # Generate year indexes
    for my $year (sort keys %posts_by_date) {
      next if $year =~ m{/};
      $self->generate_year_index($year, $posts_by_date{$year});
    }
    
    # Generate month indexes
    for my $ym (sort grep { m{^\d{4}/\d{2}$} } keys %posts_by_date) {
      my ($year, $month) = split '/', $ym;
      $self->generate_month_index($year, $month, $posts_by_date{$ym});
    }
    
    # Generate day indexes
    for my $ymd (sort grep { m{^\d{4}/\d{2}/\d{2}$} } keys %posts_by_date) {
      my ($year, $month, $day) = split '/', $ymd;
      $self->generate_day_index($year, $month, $day, $posts_by_date{$ymd});
    }
  }
  
  method generate_indexes_from_directories() {
    # Fallback for directory-based scanning (not implemented yet)
    say "Warning: Directory-based archive generation not fully implemented";
  }

  method generate_year_index($year, $posts) {
    my $archive_dir = path($output_dir)->child($year);
    $archive_dir->mkpath;

    my $content = "---\n";
    $content .= "title: \"Archive for $year\"\n";
    $content .= "layout: rut\n";
    $content .= "template: luke/log_entry\n";
    $content .= "archive_type: year\n";
    $content .= "year: $year\n";
    $content .= "---\n\n";
    
    for my $post (sort @$posts) {
      my $title = $post;
      $title =~ s{^log/}{};
      $title =~ s{/}{: }g;
      my $url = "/~luke/$post";
      $content .= "- [$title]($url)\n";
    }

    $archive_dir->child('index.md')->spew_utf8($content);
    say "  Generated year index: $year";
  }

  method generate_month_index($year, $month, $posts) {
    my $archive_dir = path($output_dir)->child($year, $month);
    $archive_dir->mkpath;

    my $month_name = $self->get_month_name($month);
    my $content = "---\n";
    $content .= "title: \"Archive for $month_name $year\"\n";
    $content .= "layout: rut\n";
    $content .= "template: luke/log_entry\n";
    $content .= "archive_type: month\n";
    $content .= "year: $year\n";
    $content .= "month: \"$month\"\n";
    $content .= "---\n\n";
    $content .= "## Posts from $month_name $year\n\n";
    
    for my $post (sort @$posts) {
      my $title = $post;
      $title =~ s{^log/}{};
      $title =~ s{/}{: }g;
      my $url = "/~luke/$post";
      $content .= "- [$title]($url)\n";
    }

    $archive_dir->child('index.md')->spew_utf8($content);
    say "  Generated month index: $year/$month";
  }

  method generate_day_index($year, $month, $day, $posts) {
    my $archive_dir = path($output_dir)->child($year, $month, $day);
    $archive_dir->mkpath;

    my $month_name = $self->get_month_name($month);
    my $content = "---\n";
    $content .= "title: \"Posts from $month_name $day, $year\"\n";
    $content .= "layout: rut\n";
    $content .= "template: luke/log_entry\n";
    $content .= "archive_type: day\n";
    $content .= "year: $year\n";
    $content .= "month: \"$month\"\n";
    $content .= "day: \"$day\"\n";
    $content .= "---\n\n";
    $content .= "## Posts from $month_name $day, $year\n\n";
    
    for my $post (sort @$posts) {
      my $title = $post;
      $title =~ s{^log/}{};
      $title =~ s{/}{: }g;
      my $url = "/~luke/$post";
      $content .= "- [$title]($url)\n";
    }

    $archive_dir->child('index.md')->spew_utf8($content);
    say "  Generated day index: $year/$month/$day";
  }

  method get_month_name($month) {
    my @names =
      qw(January February March April May June July August September October November December);
    return $names[int($month) - 1];
  }
}

1;
