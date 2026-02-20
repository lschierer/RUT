use v5.40.0;
use utf8::all;

use Object::Pad;

package App::Build::Pipeline;
our $VERSION = '0.00.1';

class App::Build::Pipeline {
  use Path::Tiny;
  use JSON::MaybeXS;

  use App::Build::ConversionManifest;
  use App::Build::IkiConverter;
  use App::Build::DateManifest;
  use App::Build::PostIndex;
  use App::Build::ArchiveGenerator;
  use App::Build::CalendarGenerator;
  use App::Build::RecentChanges;
  use App::Build::TagPageGenerator;

  field $dist_dir     : param //= './build-output';
  field $skip_pandoc  : param //= 0;
  field $skip_convert : param //= 0;

  field $json = JSON::MaybeXS->new(utf8 => 1, canonical => 1, pretty => 1);
  field $dist;

  ADJUST {
    $dist = path($dist_dir);
    $dist->mkpath;
  }

  method run () {
    my %ctx;

    # Phase 1: Analyze git history for selective re-conversion
    $self->_phase1_conversion_manifest(\%ctx);

    # Phase 2: Selective re-conversion (and collect redirects)
    $self->_phase2_iki_convert(\%ctx);

    # Phase 3 (parallel-safe): DateManifest, RecentChanges, TagPages
    $self->_phase3_date_manifest(\%ctx);
    $self->_phase3_recent_changes(\%ctx);
    $self->_phase3_tag_pages(\%ctx);

    # Phase 4: Build posts-by-date index
    $self->_phase4_post_index(\%ctx);

    # Phase 5 (parallel-safe): Archive and Calendar generation
    $self->_phase5_archives(\%ctx);
    $self->_phase5_calendars(\%ctx);

    say "=== Build complete ===";
  }

  method _phase1_conversion_manifest ($ctx) {
    say "=== Phase 1: Analyzing conversion manifest ===";
    my $cm       = App::Build::ConversionManifest->new(source_dir => './log');
    my $manifest = $cm->analyze_all();

    my $keep_count      = grep { $_ eq 'keep' } values %$manifest;
    my $reconvert_count = grep { $_ eq 'reconvert' } values %$manifest;
    say "  Keep: $keep_count, Reconvert: $reconvert_count";

    $ctx->{manifest} = $manifest;
  }

  method _phase2_iki_convert ($ctx) {
    my @redirects;

    unless ($skip_convert) {
      say "=== Phase 2: Selective conversion ===";
      say "  skip_pandoc=$skip_pandoc";
      my $converter = App::Build::IkiConverter->new(
        source_dir  => './log',
        log_file    => "$dist_dir/conversion_log.txt",
        skip_pandoc => $skip_pandoc,
      );
      my $redirect_list =
        $converter->convert_ikiwiki_files_selective($ctx->{manifest});
      @redirects = @$redirect_list;
    }
    else {
      say "=== Phase 2: Skipping conversion (--skip-convert) ===";

      # Still need to scan for redirects from .mdwn files
      my $iter =
        path('./log')->iterator({ recurse => 1, follow_symlinks => 0 });
      while (my $file = $iter->()) {
        next unless $file->stringify =~ /\.mdwn$/;
        my $content = $file->slurp_utf8;
        if ($content =~ /\[\[\!meta\s+redir="([^"]+)"\]\]/i) {
          push @redirects,
            {
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
      unless ($target =~ m{^/} || $target =~ m{^https?://}) {
        $target = "/~luke/log/$target/";
        $target =~ s{//+}{/}g;
      }

      $redirect_map{$source_url} = $target;
    }

    $dist->child('redirects.json')->spew_raw($json->encode(\%redirect_map));
    say "  Wrote " . scalar(keys %redirect_map) . " redirects";

    $ctx->{redirects} = \%redirect_map;
  }

  method _phase3_date_manifest ($ctx) {
    say "=== Phase 3a: Building date manifest ===";
    my $dm = App::Build::DateManifest->new(
      source_dir  => '.',
      output_file => "$dist_dir/dates.json",
    );
    $ctx->{dates} = $dm->build_manifest();
  }

  method _phase3_recent_changes ($ctx) {
    say "=== Phase 3b: Generating recent changes manifest ===";
    my $recent_gen = App::Build::RecentChanges->new();
    $recent_gen->generate_git_history("$dist_dir/commitHistory.json");
  }

  method _phase3_tag_pages ($ctx) {
    say "=== Phase 3c: Generating tag pages ===";
    my $tag_gen = App::Build::TagPageGenerator->new(
      source_dir         => '.',
      output_dir         => '.',
      date_manifest_file => "$dist_dir/dates.json",
    );
    my $tags = $tag_gen->generate_all();
    $dist->child('tags.json')->spew_raw($json->encode($tags));
    say "  Wrote tags.json with " . scalar(@$tags) . " tags";

    $ctx->{tags} = $tags;
  }

  method _phase4_post_index ($ctx) {
    say "=== Phase 4: Building posts-by-date index ===";
    my $pi = App::Build::PostIndex->new(
      dates_file  => "$dist_dir/dates.json",
      output_file => "$dist_dir/posts_by_date.json",
    );
    $ctx->{posts_by_date} = $pi->build($ctx->{dates});
  }

  method _phase5_archives ($ctx) {
    say "=== Phase 5a: Generating archive indexes ===";
    my $archive_gen = App::Build::ArchiveGenerator->new(
      source_dir         => './log',
      output_dir         => './log/archive',
      date_manifest_file => "$dist_dir/dates.json",
      posts_by_date_file => "$dist_dir/posts_by_date.json",
    );
    $archive_gen->generate_all_indexes();
  }

  method _phase5_calendars ($ctx) {
    say "=== Phase 5b: Generating calendar fragments ===";
    my $calendar_gen = App::Build::CalendarGenerator->new(
      source_dir         => './log',
      output_dir         => './log/archive',
      date_manifest_file => "$dist_dir/dates.json",
      posts_by_date_file => "$dist_dir/posts_by_date.json",
    );
    $calendar_gen->generate_all_calendars();
  }
}

1;
__END__

=head1 NAME

App::Build::Pipeline - Orchestrated build pipeline for luke's blog

=head1 SYNOPSIS

  my $pipeline = App::Build::Pipeline->new(
    skip_pandoc  => 1,
    skip_convert => 1,
  );
  $pipeline->run();

=head1 DESCRIPTION

Orchestrates the full build pipeline in 5 phases:

  Phase 1: ConversionManifest          (reads git, no deps)
  Phase 2: IkiConverter                (needs manifest from Phase 1)
  Phase 3: DateManifest, RecentChanges, TagPages (need .md files from Phase 2)
  Phase 4: PostIndex                   (derives from DateManifest output)
  Phase 5: ArchiveGenerator, CalendarGenerator (need posts_by_date from Phase 4)

Steps within the same phase are independent. Data is passed between phases
via a shared context hash, avoiding unnecessary re-reads of JSON from disk.

=cut
