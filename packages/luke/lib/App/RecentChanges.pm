use v5.40.0;
# cspell: disable
use utf8::all;

use Object::Pad;

package App::RecentChanges;
our $VERSION = '0.00.1';

class App::RecentChanges {
  use Exporter qw(import);
  require JSON::PP;

  use Path::Tiny;
  use HTML::Entities qw(encode_entities);
  use Git::Repository;
  use List::AllUtils qw( first any );
  use DateTime;
  use DateTime::Format::ISO8601;
  use YAML::XS qw(Load);
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
    09737f68 fdd3023e 647de408
    302d1a51 6e677bcd fc3efc8f
    6ed6fa6b 679d474c
  );

  field $json =
    JSON::PP->new()
    ->utf8()
    ->relaxed()
    ->allow_unknown()
    ->allow_blessed()
    ->convert_blessed()
    ->canonical();


  field $RUT_dir = Path::Tiny::path("./log");

  
  # Generate git history JSON file
  method generate_git_history {
    my ($output_file, $repo_path) = @_;
    $repo_path //= '../..';             # Default to parent of parent directory
    say "using repo_path '$repo_path' for git history";

    my $history = [];

    # Create the output directory if it doesn't exist
    $output_file = path($output_file);
    my $output_dir = $output_file->parent;
    $output_dir->mkdir({ mode => 0711 }) unless ($output_dir->exists);

    # Get the list of commit IDs to process
    # Note: git pathspecs use fnmatch globs, not regex — so we list each
    # wanted extension separately rather than trying to use alternation.
    my @log = $repo->run(
      'log',                  '--oneline',
      '--full-history',       '--color=never',
      '--decorate=short',     '--grep',
      '^build: ',             '--grep',
      'calendar update',      '--invert-grep',
      '--',                   '.',
      ':!packages/greenwood',
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
          $filename =~ s{index\.(?:md|mdwn)$}{};
          unless ($filename =~ m{\.(?:md|mdwn|svg|dsv|dot)$} || -d $filename) {
            next;
          }

          next if $filename =~ /^tags\//;
          if ($filename !~ m/index\.md$/) {
            my $fo = {};
            if ($filename) {
              next if $filename =~ m{archives/\d{4}};
              
              $filename =~ s{packages/(.+)}{$1};
              $filename =~ s{luke/(.+)}{$1};
              unless ($filename =~ m{log/}) {
                $filename = "log/$filename";
              }
              $fo->{path} = Path::Tiny::path($filename);
              if ($filename =~ m{fiction/Harry_Potter}) {
                next unless $fo->{path}->exists;
              }
              $fo->{title} = $self->get_title_from_file($fo->{path});
              if ($fo->{path}->exists) {
                $fo->{exists} = 1;
              }
              else {
                if($filename =~ s/wn$//){
                  if(Path::Tiny::path($filename)->exists){
                    $fo->{exists} = 1;
                  } else {
                    $fo->{exists} = 0;    
                  }
                } else {
                  $fo->{exists} = 0;
                }
              }

            }
            else {
              next;
            }
            push @files, $fo;
          }
        }
      }
      next unless scalar(@files);

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

sub get_title_from_file ($self, $file) {
  my $title;
  my $filename = $file->stringify;
  
  if($filename =~ m{\.mdwn$} ){
    unless($file->exists){
      $filename =~ s/wn$//;
      $file = Path::Tiny::path($filename);
    }
  }

  unless($file->exists){
    $title = $file->basename(qr/\.md(:?wn)?/ );
    return $title;
  }

  my $contents = $file->slurp_utf8;

  if ($filename =~ /mdwn$/) {
    if ($contents =~ /\[\[\!meta\s+title\s*=\s*\"(.+)\"/) {
      $title = $1;
    }
  }
  elsif ($filename =~ /md$/) {
    if ($contents =~ /^---\s*\n(.*?)\n---\s*$/sm) {
      my $yaml_str = $1;
      my $frontmatter;
      eval {
        $frontmatter = Load($yaml_str);
      };
      if ($@ || !$frontmatter) {
        say sprintf('failed to parse frontmatter for file "%s": %s',
          $file, $@);
      }
      elsif (exists $frontmatter->{title}) {
        $title = $frontmatter->{title};
      }
      else {
        say sprintf('no title in frontmatter for file "%s"', $file);
      }
    }
    else {
      say sprintf('no frontmatter found in file "%s"', $file);
    }
  }

  $title = $file->basename(qr/\.md(:?wn)?/ ) unless($title && length($title));
  return $title;
}

1;

__END__

