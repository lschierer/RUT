#!/usr/bin/env perl

use v5.40.0;
use utf8;

use FindBin;
use lib "$FindBin::Bin/../lib";
require App::IkiConverter;
#qw(convert_ikiwiki_files);
use Getopt::Long;

# Parse command line options
my $source_dir = './log';
my $log_file = './dist/conversion_log.txt';
my $help = 0;

GetOptions(
    "source=s" => \$source_dir,
    "log=s"    => \$log_file,
    "help"     => \$help
) or die "Error in command line arguments\n";

if ($help) {
    print <<HELP;
Usage: $0 [options]

Options:
  --source=DIR   Directory containing .mdwn files (default: ./log)
  --log=FILE     Path to log file (default: ./dist/conversion_log.txt)
  --help         Display this help message

Description:
  Converts ikiwiki formatted .mdwn files to standard CommonMark + GFM markdown .md files.
  Successful conversions will result in the original .mdwn file being removed.
  Failed conversions will be logged but the original file will be preserved.
HELP
    exit 0;
}

# Run the conversion
print "Starting conversion of ikiwiki files...\n";
my $converter = App::IkiConverter->new(
  source_dir  => $source_dir,
  log_file    =>$log_file
);
my $count = $converter->convert_ikiwiki_files();
print "Processed $count files. See $log_file for details.\n";
