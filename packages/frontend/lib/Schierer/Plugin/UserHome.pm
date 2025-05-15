package Schierer::Plugin::UserHome;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::File;
use Mojo::File::Share qw(dist_dir);

# Register the plugin
sub register {
  my ($self, $app, $conf) = @_;
  
  # Get the home directory
  my $distDir = Mojo::File::Share::dist_dir('Schierer::Base');
  my $home_dir = Mojo::File->new($distDir, 'home');
  
  # Add debug logging
  $app->log->debug("UserHome plugin: Looking for home directories in $home_dir");
  
  # Skip if home directory doesn't exist
  unless (-d $home_dir) {
    $app->log->warn("UserHome plugin: Home directory $home_dir does not exist");
    return;
  }
  
  # Get all entries in the home directory using direct readdir approach
  opendir(my $dh, $home_dir) or do {
    $app->log->error("UserHome plugin: Cannot open directory $home_dir: $!");
    return;
  };
  
  my @entries;
  while (my $entry = readdir($dh)) {
    next if $entry eq '.' or $entry eq '..' or $entry eq '.git';
    next if $entry =~ /^\./; # Skip hidden files/directories
    
    my $full_path = $home_dir->child($entry);
    if (-d $full_path) {
      push @entries, $full_path;
      $app->log->debug("UserHome plugin: Found directory: $entry");
    }
  }
  closedir($dh);
  
  $app->log->debug("UserHome plugin: Found " . scalar(@entries) . " valid directories");
  
  # Make sure controller namespace is in routes
  push @{$app->routes->namespaces}, 'Schierer::Controller' 
    unless grep { $_ eq 'Schierer::Controller' } @{$app->routes->namespaces};
  
  foreach my $user_dir (@entries) {
    my $user_name = $user_dir->basename;
    $app->log->debug("UserHome plugin: Processing user directory: $user_name");
    
    # Check if a corresponding controller exists
    my $controller_name = ucfirst($user_name);  # Capitalize first letter
    my $controller_class = "Schierer::Controller::$controller_name";
    
    # Try to find the module in @INC
    my $module_path = $controller_class;
    $module_path =~ s{::}{/}g;
    $module_path .= ".pm";
    
    my $found = 0;
    foreach my $inc_dir (@INC) {
      my $try_path = "$inc_dir/$module_path";
      if (-f $try_path) {
        $found = 1;
        $app->log->debug("UserHome plugin: Found controller at: $try_path");
        last;
      }
    }
    
    if ($found) {
      # Add routes for this user
      $app->log->info("UserHome plugin: Adding routes for user ~$user_name using $controller_class");
      
      # Add routes for the user's content - using standard route creation
      my $r = $app->routes;
      
      # Route for the root of the user's home directory
      $r->get("/~$user_name")->to(controller => lc($controller_name), action => 'handle');
      
      # Route for paths under the user's home directory - IMPORTANT: use placeholder name that matches parameter name
      $r->get("/~$user_name/*file_path")->to(controller => lc($controller_name), action => 'handle');
    } else {
      $app->log->debug("UserHome plugin: No controller found for ~$user_name");
    }
  }
}

1;

__END__

#ABSTRACT: Plugin for dynamically loading user home directories

=pod

=head1 DESCRIPTION

This plugin automatically discovers user home directories in the share/home folder
and creates routes for them if a corresponding controller exists.

=head1 USAGE

  # In your Mojolicious application
  $app->plugin('Schierer::Plugin::UserHome');

=cut
