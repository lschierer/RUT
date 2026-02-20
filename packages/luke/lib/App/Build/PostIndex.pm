use v5.40.0;
use utf8::all;

use Object::Pad;

package App::Build::PostIndex;
our $VERSION = '0.00.1';

class App::Build::PostIndex {
  use Path::Tiny;
  use JSON::MaybeXS;

  field $dates_file  : param //= './build-output/dates.json';
  field $output_file : param //= './build-output/posts_by_date.json';

  method build ($dates_hash = undef) {
    my $json = JSON::MaybeXS->new(utf8 => 1, canonical => 1, pretty => 1);

    # Load dates from file if not passed in-memory
    unless ($dates_hash) {
      $dates_hash = $json->decode(path($dates_file)->slurp_raw);
    }

    my %posts_by_date;

    for my $key (keys %$dates_hash) {
      next if $key =~ /index$/;
      my $date_str = $dates_hash->{$key};
      if ($date_str =~ /^(\d{4})-(\d{2})-(\d{2})/) {
        my ($year, $month, $day) = ($1, $2, $3);
        push @{$posts_by_date{"$year/$month/$day"}}, $key;
        push @{$posts_by_date{"$year/$month"}}, $key unless grep { $_ eq $key } @{$posts_by_date{"$year/$month"} // []};
        push @{$posts_by_date{$year}}, $key unless grep { $_ eq $key } @{$posts_by_date{$year} // []};
      }
    }

    # Write output
    my $out = path($output_file);
    $out->parent->mkpath;
    $out->spew_raw($json->encode(\%posts_by_date));
    say "  Wrote posts_by_date.json";

    return \%posts_by_date;
  }
}

1;
__END__

=head1 NAME

App::Build::PostIndex - Compute posts-by-date index from date manifest

=head1 SYNOPSIS

  my $pi = App::Build::PostIndex->new(
    dates_file  => './build-output/dates.json',
    output_file => './build-output/posts_by_date.json',
  );
  my $posts_by_date = $pi->build();

  # Or pass dates hash directly:
  my $posts_by_date = $pi->build($dates_hash);

=head1 DESCRIPTION

Takes a date manifest (mapping content paths to ISO 8601 dates) and groups
posts by year, year/month, and year/month/day. Writes the result to
C<posts_by_date.json>.

=cut
