package Win32::IEHistory::History;

use strict;
use warnings;
use base qw( Win32::IEHistory );
use Win32::TieRegistry ( Delimiter => '/' );
use File::Spec;

sub new {
  my $class = shift;

  $class->SUPER::new( $class->_file );
}

sub _file {
  my $class = shift;

  my $dir   = $Registry->{'CUser/Software/Microsoft/Windows/CurrentVersion/Explorer/Shell Folders//History'};

  my $ie5_dir = File::Spec->catdir( $dir, 'History.IE5' );
  $dir = $ie5_dir if -d $ie5_dir;

  return File::Spec->catfile( $dir, 'index.dat' );
}

1;

__END__

=head1 NAME

Win32::IEHistory::History - parse Internet Explorer's History index.dat

=head1 SYNOPSIS

  use Win32::IEHistory::History;
  my $cache = Win32::IEHistory::History->new;

=head1 DESCRIPTION

This is just a sugar for Win32::IEHistory to make Win32 users happy.

=head1 METHOD

=head2 new

searches for a history directory in the registry, and provides it to the parent Win32::IEHistory.

=head1 AUTHOR

Kenichi Ishigaki, E<lt>ishigaki at cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Kenichi Ishigaki.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
