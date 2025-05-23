use v5.40.0;
use experimental qw(class);
use utf8::all;
use File::FindLib 'lib';
use YAML::PP;
use namespace::clean;
use Mojolicious::Plugin::DefaultHelpers;

package Schierer::Base {
  use Mojo::Base 'Mojolicious', -role, -signatures;
  use Mojo::File::Share qw(dist_dir dist_file);
  require Date::Manip;
  require Date::Manip::Date;
  require Date::Manip::Delta;
  use Carp;
  our $VERSION = 'v0.01.0';

  sub startup ($self) {
    my $distDir = Mojo::File::Share::dist_dir('Schierer::Base');
    my $home    = Mojo::Home->new;
    $home->detect;
    $self->log->debug("Mojo Home is $home");

    # Load configuration from config file
    my $config = $self->plugin(
      'NotYAMLConfig' => {
        module => 'YAML::PP',
      }
    );

    # Configure the application
    $self->secrets($config->{secrets});
    $self->plugin('DefaultHelpers');

    my $r = $self->routes;
    push @{$self->routes->namespaces}, 'Schierer::Controller';
    $r->any("/")->to('Root#index');

    # Load user home directories plugin
    $self->plugin('Schierer::Plugin::UserHome');

    $self->helper(time_ago => sub {
      my ($c, $timestamp) = @_;

      $c->app->log->debug("time_ago timestamp is $timestamp");

      # Create Date objects
      my $date_obj = Date::Manip::Date->new();
      $date_obj->parse($timestamp);

      if(length $date_obj->err()) {
        $c->app->log->debug('time_ago received an error ' . $date_obj->err());
        return "unknown date";
      }

      my $parsed_date = $date_obj->printf("%Y-%m-%d %H:%M:%S %z");
      $c->app->log->debug("Parsed date: $parsed_date");

      my $now_obj = Date::Manip::Date->new();
      $now_obj->parse("now");
      my $now_date = $now_obj->printf("%Y-%m-%d %H:%M:%S %z");
      $c->app->log->debug("Current date: $now_date");

      # Calculate the difference between the dates in days
        # First get the Unix timestamps
        my $date_epoch = $date_obj->secs_since_1970_GMT();
        my $now_epoch = $now_obj->secs_since_1970_GMT();

        # Calculate days difference (ensuring positive value)
        my $delta_days = int(abs($now_epoch - $date_epoch) / (24 * 60 * 60));
        $c->app->log->debug("Delta days calculated from epoch: $delta_days");


      # Now determine the relative time string
      if ($delta_days == 0) {
        return "today";
      } elsif ($delta_days == 1) {
        return "yesterday";
      } elsif ($delta_days < 7) {
        return "$delta_days days ago";
      } elsif ($delta_days < 30) {
        my $weeks = int($delta_days / 7);
        return "$weeks " . ($weeks == 1 ? "week" : "weeks") . " ago";
      } elsif ($delta_days < 365) {
        my $months = int($delta_days / 30);
        return "$months " . ($months == 1 ? "month" : "months") . " ago";
      } else {
        my $years = int($delta_days / 365);
        return "$years " . ($years == 1 ? "year" : "years") . " ago";
      }
    });


    $self->helper(format_datetime => sub {
      my ($c, $timestamp) = @_;
      $c->app->log()->debug( "format_datetime timestamp is $timestamp");
      my $date_obj = Date::Manip::Date->new();
      $date_obj->parse($timestamp);

      if(length $date_obj->err()) {
        $c->app->log->debug('time_ago received an error ' . $date_obj->err());
        return "unknown date";
      }

      my $parsed_date = $date_obj->printf("%Y-%m-%d %H:%M:%S %z");
      $c->app->log->debug("Parsed date: $parsed_date");

      return $date_obj->printf("%B %d, %Y at %I:%M %p");
    });



    $self->start(@ARGV);
  }
};
1;

__END__

#ABSTRACT: The main Mojolicious configuration, command, and control module

=pod

=head1 DESCRIPTION

this module contains the primary Mojolicious command, control and configuration.

=cut
