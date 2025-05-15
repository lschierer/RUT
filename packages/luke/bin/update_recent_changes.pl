#!/usr/bin/env perl

use v5.40.0;
use strict;
use warnings;
use utf8;

use FindBin;
use lib "$FindBin::Bin/../lib";
use App::RecentChanges qw(update_recent_changes generate_git_history);

# Configuration
my $json_file = './tmp/commitHistory.json';
my $md_file = './log/index.md';
my $limit = 100;

# Generate the git history JSON file
print "Generating git history...\n";
my $commits_processed = generate_git_history($json_file);
print "Processed $commits_processed commits.\n";

# Update the markdown file with recent changes
print "Updating markdown file with recent changes...\n";
my $entries_added = update_recent_changes($json_file, $md_file, $limit);
print "Added $entries_added recent change entries to $md_file\n";

print "Done!\n";
