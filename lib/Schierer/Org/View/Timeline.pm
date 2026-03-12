package Schierer::Org::View::Timeline;
# cspell: disable
use v5.42.0;
use utf8::all;
use Mooish::Base -standard;

use SVG;
use List::AllUtils qw(min max);
use POSIX          qw(ceil);
use Carp;

has data => (
  is       => 'ro',
  required => 1,
);

# Layout constants
has rail_spacing => (is => 'ro', default => 60);
has node_width   => (is => 'ro', default => 180);
has node_height  => (is => 'ro', default => 40);
has y_padding    => (is => 'ro', default => 60);
has x_margin     => (is => 'ro', default => 40);

# Computed layout state
has _category_order => (is => 'lazy', builder => '_build_category_order');
has _rail_x         => (is => 'lazy', builder => '_build_rail_x');
has _placements     => (is => 'rw',   default => sub { {} });
has _used_rects     => (is => 'rw',   default => sub { [] });
has _y_scale        => (is => 'rw',   default => 1);
has _svg_width      => (is => 'rw',   default => 1200);
has _svg_height     => (is => 'rw',   default => 2000);

sub _build_category_order ($self) {
  # Fixed order: catholic first, then heresies, then protestant, etc.
  my @order = qw(
    catholic orthodox oriental_orthodox heresy
    protestant dangerous reunited partial_communion
  );
  # Only include categories that have entities
  my %used;
  for my $e (values %{ $self->data->entities }) {
    $used{ $e->{category} } = 1;
  }
  return [grep { $used{$_} } @order];
}

sub _build_rail_x ($self) {
  my %rx;
  my $x = $self->x_margin + 60;    # room for year labels
  for my $cat (@{ $self->_category_order }) {
    $rx{$cat} = $x;
    $x += $self->rail_spacing;
  }
  return \%rx;
}

sub _date_to_y ($self, $date) {
  return undef unless defined $date;
  # Linear time scaling: 1 year = consistent vertical distance.
  # This preserves the visual impact of quiet vs turbulent centuries.
  # A minimum gap between adjacent dates prevents overlap at tight spots
  # (e.g. 33→34 AD) while keeping overall proportionality.
  return $self->y_padding + $self->_date_offsets->{$date};
}

has _date_offsets => (
  is      => 'lazy',
  builder => sub ($self) {
    my @unique_dates = do {
      my %seen;
      sort { $a <=> $b }
        grep { !$seen{$_}++ }
        map { $_->{date} } @{ $self->data->dated_entities };
    };
    return {} unless @unique_dates;

    my $min_gap     = $self->node_height + 10;    # minimum pixels between dates
    my $px_per_year = 2;                          # base scale: 2px per year

    my %offsets;
    $offsets{ $unique_dates[0] } = 0;

    for my $i (1 .. $#unique_dates) {
      my $year_delta = $unique_dates[$i] - $unique_dates[$i - 1];
      my $px_delta   = max($min_gap, $year_delta * $px_per_year);
      $offsets{ $unique_dates[$i] } =
        $offsets{ $unique_dates[$i - 1] } + $px_delta;
    }

    return \%offsets;
  },
);

sub create ($self) {
  my $entities = $self->data->dated_entities;
  my $n        = scalar @$entities;
  return '<svg></svg>' unless $n;

  # Scale: the _date_offsets lazy attribute handles proportional spacing
  # with minimum gaps. No separate _y_scale needed.

  # Place nodes on rails, then find detail positions
  $self->_place_all_nodes();

  # Compute SVG dimensions from placements
  my $max_x = 0;
  my $max_y = 0;
  for my $p (values %{ $self->_placements }) {
    my $right  = $p->{box_x} + $p->{box_w};
    my $bottom = $p->{box_y} + $p->{box_h};
    $max_x = $right  if $right > $max_x;
    $max_y = $bottom if $bottom > $max_y;
  }
  $self->_svg_width($max_x + $self->x_margin);
  $self->_svg_height($max_y + $self->y_padding);

  # Build SVG
  my $svg = SVG->new(preserveAspectRatio => 'xMidYMid meet');

  # Defs for arrowheads
  my $defs = $svg->defs;
  $defs->tag(
    'marker',
    id           => 'arrowhead',
    markerWidth  => 6,
    markerHeight => 4,
    refX         => 6,
    refY         => 2,
    orient       => 'auto',
  )->tag('polygon', points => '0 0, 6 2, 0 4', fill => '#666');

  my $rails_g  = $svg->group(id => 'rails',  class => 'timeline-rails');
  my $edges_g  = $svg->group(id => 'edges',  class => 'timeline-edges');
  my $nodes_g  = $svg->group(id => 'nodes',  class => 'timeline-nodes');
  my $labels_g = $svg->group(id => 'labels', class => 'timeline-labels');

  $self->_draw_rails($rails_g);
  $self->_draw_year_labels($labels_g);
  $self->_draw_edges($edges_g);
  $self->_draw_nodes($nodes_g);

  my $viewbox = sprintf('0 0 %d %d', $self->_svg_width, $self->_svg_height);
  my $out     = $svg->xmlify(-pubid => "-//W3C//DTD SVG 1.0//EN", -inline => 1);
  $out =~ s/<svg /<svg viewBox="$viewbox" /;
  return $out;
}

sub _place_all_nodes ($self) {
  my %placements;
  my @used_rects;

  for my $entity (@{ $self->data->sorted_entities }) {
    next unless defined $entity->{date};
    my $id     = $entity->{id};
    my $cat    = $entity->{category};
    my $rail_x = $self->_rail_x->{$cat};
    next unless defined $rail_x;

    my $dot_y = $self->_date_to_y($entity->{date});
    my $w     = $self->node_width;
    my $h     = $self->node_height;

    # Adjust height for long labels
    if (length($entity->{label}) > 25) {
      $h += 15;
    }

    # Find a clear position for the detail box
    my $box_pos =
      $self->_find_clear_position($rail_x, $dot_y, $w, $h, \@used_rects);

    push @used_rects, $box_pos;
    $placements{$id} = {
      dot_x    => $rail_x,
      dot_y    => $dot_y,
      box_x    => $box_pos->{x},
      box_y    => $box_pos->{y},
      box_w    => $w,
      box_h    => $h,
      category => $cat,
    };
  }

  $self->_placements(\%placements);
  $self->_used_rects(\@used_rects);
}

sub _find_clear_position ($self, $rail_x, $dot_y, $w, $h, $used) {
  # Try positions to the right of the rail, spreading horizontally on collision
  my $base_x = $rail_x + $self->rail_spacing / 2;
  my $pad    = 4;

  # Generate candidates: right of rail, then further right
  my @offsets;
  for my $col (0 .. 8) {
    my $dx = $base_x + $col * ($w + $pad);
    for my $dy_mult (-2 .. 2) {
      push @offsets, { x => $dx, y => $dot_y + $dy_mult * ($h / 3) - $h / 2 };
    }
  }

  for my $cand (@offsets) {
    next if $cand->{y} < 0;
    my $clear = 1;
    for my $u (@$used) {
      if (_rects_overlap(
        $cand->{x}, $cand->{y}, $w,      $h, $u->{x},
        $u->{y},    $u->{w},    $u->{h}, $pad
      )) {
        $clear = 0;
        last;
      }
    }
    if ($clear) {
      return { x => $cand->{x}, y => $cand->{y}, w => $w, h => $h };
    }
  }

  # Fallback: far right
  my $fb_x = $base_x + 9 * ($w + $pad);
  return { x => $fb_x, y => $dot_y - $h / 2, w => $w, h => $h };
}

sub _rects_overlap ($x1, $y1, $w1, $h1, $x2, $y2, $w2, $h2, $pad) {
  return 0 if $x1 + $w1 + $pad <= $x2;
  return 0 if $x2 + $w2 + $pad <= $x1;
  return 0 if $y1 + $h1 + $pad <= $y2;
  return 0 if $y2 + $h2 + $pad <= $y1;
  return 1;
}

sub _draw_rails ($self, $group) {
  my $cats = $self->data->categories;
  for my $cat (@{ $self->_category_order }) {
    my $x     = $self->_rail_x->{$cat};
    my $label = $cats->{$cat}{label} // $cat;
    $group->line(
      x1    => $x,
      y1    => $self->y_padding - 20,
      x2    => $x,
      y2    => $self->_svg_height - 10,
      class => "rail rail-$cat",
    );
    $group->text(
      x     => $x,
      y     => $self->y_padding - 25,
      class => "rail-label rail-label-$cat",
    )->cdata($label);
  }
}

sub _draw_year_labels ($self, $group) {
  # Draw year markers on the left side
  my %seen_years;
  for my $e (@{ $self->data->dated_entities }) {
    my $date = $e->{date};
    next if $seen_years{$date}++;
    my $y = $self->_date_to_y($date);
    $group->text(
      x     => 5,
      y     => $y + 4,
      class => 'year-label',
    )->cdata($date);
    # Light horizontal guide line
    $group->line(
      x1    => $self->x_margin,
      y1    => $y,
      x2    => $self->_svg_width - 10,
      y2    => $y,
      class => 'year-guide',
    );
  }
}

sub _draw_edges ($self, $group) {
  my $placements = $self->_placements;
  my $entities   = $self->data->entities;

  for my $id (keys %$placements) {
    my $entity = $entities->{$id};
    my $child  = $placements->{$id};

    for my $pid (@{ $entity->{parents} }) {
      my $parent = $placements->{$pid};
      next unless $parent;    # parent may be undated/unplaced

      # Draw from parent dot to child dot
      $group->line(
        x1           => $parent->{dot_x},
        y1           => $parent->{dot_y},
        x2           => $child->{dot_x},
        y2           => $child->{dot_y},
        class        => "edge edge-$entity->{category}",
        'marker-end' => 'url(#arrowhead)',
      );
    }
  }
}

sub _draw_nodes ($self, $group) {
  my $placements = $self->_placements;
  my $entities   = $self->data->entities;

  for my $id (sort keys %$placements) {
    my $p   = $placements->{$id};
    my $e   = $entities->{$id};
    my $cat = $p->{category};

    # Dot on the rail
    $group->circle(
      cx    => $p->{dot_x},
      cy    => $p->{dot_y},
      r     => 4,
      class => "dot dot-$cat",
    );

    # Leader line from dot to box
    my $box_cx = $p->{box_x} + $p->{box_w} / 2;
    my $box_cy = $p->{box_y} + $p->{box_h} / 2;
    $group->line(
      x1    => $p->{dot_x},
      y1    => $p->{dot_y},
      x2    => $p->{box_x},
      y2    => $box_cy,
      class => "leader leader-$cat",
    );

    # Detail box
    my $node_group = $group->group(
      id    => "node-$id",
      class => "node node-$cat",
    );

    $node_group->rectangle(
      x      => $p->{box_x},
      y      => $p->{box_y},
      width  => $p->{box_w},
      height => $p->{box_h},
      rx     => 3,
      ry     => 3,
      class  => "node-rect node-rect-$cat",
    );

    # Label via foreignObject for text wrapping
    my $fo = $node_group->foreignObject(
      x      => $p->{box_x},
      y      => $p->{box_y},
      width  => $p->{box_w},
      height => $p->{box_h},
    );

    my $div = $fo->tag(
      'div',
      xmlns => 'http://www.w3.org/1999/xhtml',
      class => "node-label node-label-$cat",
    );

    if ($e->{url}) {
      $div->tag(
        'a',
        href  => $e->{url},
        class => 'spectrum-Link spectrum-Link--quiet',
      )->cdata($e->{label});
    }
    else {
      $div->cdata($e->{label});
    }
  }
}

1;
__END__
