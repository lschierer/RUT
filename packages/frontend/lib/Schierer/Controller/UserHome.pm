package Schierer::Controller::UserHome;
use Mojo::Base 'Mojolicious::Controller';

# Base method that all user home controllers should implement
sub handle {
  my ($self) = @_;
  
  # Get file_path from stash
  my $file_path = $self->stash('file_path') // '';
  
  # This is a base method that should be overridden by specific user controllers
  return $self->reply->not_found;
}

1;

__END__

#ABSTRACT: Base controller for user home directories

=pod

=head1 DESCRIPTION

This is a base controller that defines the interface for user home controllers.
Specific user controllers should inherit from this class and implement the handle method.

=head1 EXAMPLE

  package Schierer::Controller::Luke;
  use Mojo::Base 'Schierer::Controller::UserHome';
  
  sub handle {
    my ($self) = @_;
    my $file_path = $self->stash('file_path') // '';
    # Implementation for Luke's home directory
  }
  
  1;

=cut
