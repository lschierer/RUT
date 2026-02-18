#!/usr/bin/env perl
# cspell: disable
use v5.40.0;
use utf8::all;
use lib 'lib';
use Path::Tiny;
use JSON::MaybeXS;
use Getopt::Long;

use App::ConversionManifest;
use App::IkiConverter;
use App::DateManifest;
use App::ArchiveGenerator;
use App::CalendarGenerator;
use App::RecentChanges;
use App::TagPageGenerator;

my $skip_pandoc = 0;
my $skip_convert = 0;
GetOptions(
  'skip-pandoc'  => \$skip_pandoc,
  'skip-convert' => \$skip_convert,
) or die "Usage: $0 [--skip-pandoc] [--skip-convert]\n";

my $dist = path('./dist');
$dist->mkpath;

# Step 1: Analyze git history for selective re-conversion
say "=== Step 1: Analyzing conversion manifest ===";
my $cm = App::ConversionManifest->new(source_dir => './log');
my $manifest = $cm->analyze_all();

my $keep_count      = grep { $_ eq 'keep' } values %$manifest;
my $reconvert_count = grep { $_ eq 'reconvert' } values %$manifest;
say "  Keep: $keep_count, Reconvert: $reconvert_count";

# Step 2: Selective re-conversion (and collect redirect info)
my @redirects;
unless ($skip_convert) {
  say "=== Step 2: Selective conversion ===";
  say "  skip_pandoc=$skip_pandoc";
  my $converter = App::IkiConverter->new(
    source_dir  => './log',
    log_file    => './dist/conversion_log.txt',
    skip_pandoc => $skip_pandoc,
  );
  my $redirect_list = $converter->convert_ikiwiki_files_selective($manifest);
  @redirects = @$redirect_list;
}
else {
  say "=== Step 2: Skipping conversion (--skip-convert) ===";

  # Still need to scan for redirects from .mdwn files
  my $iter = path('./log')->iterator({ recurse => 1, follow_symlinks => 0 });
  while (my $file = $iter->()) {
    next unless $file->stringify =~ /\.mdwn$/;
    my $content = $file->slurp_utf8;
    if ($content =~ /\[\[\!meta\s+redir="([^"]+)"\]\]/i) {
      push @redirects, {
        source => $file->relative('./log')->stringify,
        target => $1,
      };
    }
  }
}

# Write redirects.json
say "=== Writing redirects.json ===";
my %redirect_map;
for my $r (@redirects) {
  my $source_path = $r->{source};
  $source_path =~ s/\.mdwn$//;
  my $source_url = "/~luke/log/$source_path/";
  $source_url =~ s{//+}{/}g;

  my $target = $r->{target};
  # If target is a relative ikiwiki path, convert to /~luke/ URL
  unless ($target =~ m{^/} || $target =~ m{^https?://}) {
    $target = "/~luke/log/$target/";
    $target =~ s{//+}{/}g;
  }

  $redirect_map{$source_url} = $target;
}

my $json = JSON::MaybeXS->new(utf8 => 1, canonical => 1, pretty => 1);
$dist->child('redirects.json')->spew_raw($json->encode(\%redirect_map));
say "  Wrote " . scalar(keys %redirect_map) . " redirects";

# Step 3: Build date manifest and post index
say "=== Step 3: Building date manifest ===";
my $dm = App::DateManifest->new(
  source_dir  => '.',
  output_file => './dist/dates.json',
);
$dm->build_manifest();

# Build posts-by-date index for archive/calendar generation
say "  Building posts-by-date index...";
my $dates_json = $json->decode($dist->child('dates.json')->slurp_raw);
my %posts_by_date;

for my $key (keys %$dates_json) {
  next if $key =~ /index$/;
  my $date_str = $dates_json->{$key};
  if ($date_str =~ /^(\d{4})-(\d{2})-(\d{2})/) {
    my ($year, $month, $day) = ($1, $2, $3);
    push @{$posts_by_date{"$year/$month/$day"}}, $key;
    push @{$posts_by_date{"$year/$month"}}, $key unless grep { $_ eq $key } @{$posts_by_date{"$year/$month"} // []};
    push @{$posts_by_date{$year}}, $key unless grep { $_ eq $key } @{$posts_by_date{$year} // []};
  }
}

$dist->child('posts_by_date.json')->spew_raw($json->encode(\%posts_by_date));
say "  Wrote posts_by_date.json";

# Step 4: Generate archive indexes
say "=== Step 4: Generating archive indexes ===";
my $archive_gen = App::ArchiveGenerator->new(
  source_dir => './log',
  output_dir => './log/archive',
  date_manifest_file => './dist/dates.json',
  posts_by_date_file => './dist/posts_by_date.json',
);
$archive_gen->generate_all_indexes();

# Step 5: Generate calendar fragments
say "=== Step 5: Generating calendar fragments ===";
my $calendar_gen = App::CalendarGenerator->new(
  source_dir => './log',
  output_dir => './log/archive',
  date_manifest_file => './dist/dates.json',
  posts_by_date_file => './dist/posts_by_date.json',
);
$calendar_gen->generate_all_calendars();

# Step 6: Generate tag pages
say "=== Step 6: Generating tag pages ===";
my $tag_gen = App::TagPageGenerator->new(
  source_dir => '.',
  output_dir => '.',
  date_manifest_file => './dist/dates.json',
);
my $tags = $tag_gen->generate_all();
$dist->child('tags.json')->spew_raw($json->encode($tags));
say "  Wrote tags.json with " . scalar(@$tags) . " tags";

# Step 7: Generate recent changes manifest
say "=== Step 7: Generating recent changes manifest ===";
my $json_file = './dist/commitHistory.json';
my $recent_gen = App::RecentChanges->new();
$recent_gen->generate_git_history($json_file);

say "=== Build complete ===";
