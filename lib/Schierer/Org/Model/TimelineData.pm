package Schierer::Org::Model::TimelineData;
use v5.42.0;
use utf8::all;
use Mooish::Base -standard;

use YAML::PP;
use Path::Tiny qw(path);
use Carp;

has data_file => (
  is       => 'ro',
  required => 1,
);

has _raw => (
  is      => 'lazy',
  builder => sub ($self) {
    my $file = path($self->data_file);
    croak "Timeline data file not found: $file" unless $file->exists;
    my $ypp = YAML::PP->new;
    return $ypp->load_string($file->slurp_utf8);
  },
);

has categories => (
  is      => 'lazy',
  builder => sub ($self) { $self->_raw->{categories} // {} },
);

has entities => (
  is      => 'lazy',
  builder => sub ($self) {
    my $raw = $self->_raw->{entities} // {};
    my %out;
    for my $id (keys %$raw) {
      my $e = $raw->{$id};
      $out{$id} = {
        id       => $id,
        label    => $e->{label}    // $id,
        category => $e->{category} // 'unknown',
        date     => $e->{date},
        url      => $e->{url},
        parents  => $e->{parents} // [],
      };
    }
    return \%out;
  },
);

# Entities sorted by date (undated at end), then alphabetically
has sorted_entities => (
  is      => 'lazy',
  builder => sub ($self) {
    my $ents = $self->entities;
    return [
      sort {
        my $da = $a->{date} // 9999;
        my $db = $b->{date} // 9999;
        $da <=> $db || $a->{id} cmp $b->{id};
      } values %$ents
    ];
  },
);

# Only entities that have dates
has dated_entities => (
  is      => 'lazy',
  builder => sub ($self) {
    return [grep { defined $_->{date} } @{ $self->sorted_entities }];
  },
);

has min_date => (
  is      => 'lazy',
  builder => sub ($self) {
    my @dates = map { $_->{date} } @{ $self->dated_entities };
    return @dates ? (sort { $a <=> $b } @dates)[0] : 0;
  },
);

has max_date => (
  is      => 'lazy',
  builder => sub ($self) {
    my @dates = map { $_->{date} } @{ $self->dated_entities };
    return @dates ? (sort { $b <=> $a } @dates)[0] : 2000;
  },
);

# Build children map (reverse of parents)
has children_of => (
  is      => 'lazy',
  builder => sub ($self) {
    my %children;
    for my $e (values %{ $self->entities }) {
      for my $pid (@{ $e->{parents} }) {
        push @{ $children{$pid} }, $e->{id};
      }
    }
    return \%children;
  },
);

1;
__END__
