package Win32::IEHistory;

use strict;
use warnings;
use Carp;
use Win32::IEHistory::FileTime;
use File::Spec;

our $VERSION = '0.01';

use constant BADFOOD => chr(0x0d).chr(0xF0).chr(0xAD).chr(0x0B);

sub new {
  my $class = shift;
  my $self = bless {}, $class;

  $self->_read_file( @_ );
  $self->_version_check;
  $self->_size_check;
  $self->_read_hashes;
  $self->_read_entries;

  $self;
}

sub _read_file {
  my ($self, $file) = @_;

  open my $fh, '<', $file or croak $!;
  binmode $fh;
  sysread $fh, ( my $data ), ( my $size = -s $fh );
  close $fh;

  $self->{_data} = $data;
  $self->{_size} = $size;
  $self->{_pos}  = 0;
}

sub _version_check {
  my $self = shift;
  my $header = 'Client UrlCache MMF Ver 5.2';
  my $read   = $self->_read_string;
  unless ( $read eq $header ) {
    croak "unsupported file type: $read";
  }
}

sub _size_check {
  my $self = shift;
  my $read = _to_int( $self->_read );
  unless ( $read == $self->{_size} ) {
    croak "index file seems broken: $read / ".$self->{_size};
  }
}

sub _read_hashes {
  my $self = shift;

  my $first_offset = _to_int( $self->_read );

  $self->__read_hashes( $first_offset );
}

sub __read_hashes {
  my ($self, $hash_start) = @_;

  my @entries;
  while( $hash_start ) {
    unless ( $self->_read_from( $hash_start ) eq 'HASH' ) {
      croak "index file seems broken: HASH not found";
    }
    my $hash_length = _to_int( $self->_read );
    my $next_hash   = _to_int( $self->_read );
    my $unknown     = _to_int( $self->_read );
    my $hash_end    = $hash_start + ( $hash_length * 0x80 );

    while ( $self->{_pos} < $hash_end ) {
      my ( $hashkey, $offset ) = ( $self->_read, $self->_read );
      next if $offset eq BADFOOD;

      my $int_offset = _to_int( $offset );
      next unless $int_offset;

      # last of the offset should be 0x80/0x00 (not 0x03 etc)
      next unless ( $int_offset & 0xf ) == 0;

      my $tag = $self->_test_from( $int_offset );
      next if $tag eq BADFOOD;

      if ( $tag =~ /^(?:URL|REDR|LEAK)/ ) {
        push @entries, $int_offset;
      }
    }
    $hash_start = $next_hash or last;
  }
  $self->{_entries} = \@entries;
}

sub _read_entries {
  my $self = shift;

  foreach my $entry ( @{ $self->{_entries} || [] } ) {
    my $tag = $self->_read_from( $entry );
       $tag =~ s/ $//;
    my $class = 'Win32::IEHistory::'.$tag;

    my $item;
    if ( $tag eq 'REDR' ) {
      my $block   = $self->_read;
      my $unknown = $self->_read(8);
      my $url     = $self->_read_string;

      $item = { url => $url };
    }
    if ( $tag eq 'URL' or $tag eq 'LEAK' ) {
      my $class = "Win32::IEHistory\::$tag";

      my $block              = $self->_read;
      my $last_modified      = filetime( $self->_read(8) );
      my $last_accessed      = filetime( $self->_read(8) );
      my $maybe_expire       = $self->_read(8);
      my $maybe_filesize     = $self->_read(8);
      my $unknown            = $self->_read(20);
      my $offset_to_filename = _to_int( $self->_read );
      my $unknown2           = $self->_read;
      my $offset_to_headers  = _to_int( $self->_read );
      my $unknown3           = $self->_read(32);
      my $url                = $self->_read_string;
      my $filename           = $offset_to_filename
        ? $self->_read_string_from( $entry + $offset_to_filename )
        : '';
      my $headers            = $offset_to_headers
        ? $self->_read_string_from( $entry + $offset_to_headers )
        : '';

      $item = {
        url           => $url,
        filename      => $filename,
        headers       => $headers,
        filesize      => $maybe_filesize,
        last_modified => $last_modified,
        last_accessed => $last_accessed,
      };
    }
    next unless $item;

    push @{ $self->{$tag} ||= [] }, bless $item, $class;
  }
}

sub urls  { @{ shift->{URL}  || [] } }
sub redrs { @{ shift->{REDR} || [] } }
sub leaks { @{ shift->{LEAK} || [] } }

sub _to_int {
  my $dword = shift;
  my @bytes = split //, $dword;
  return (
    ord( $bytes[3] ) * (256 ** 3) +
    ord( $bytes[2] ) * (256 ** 2) +
    ord( $bytes[1] ) * (256 ** 1) +
    ord( $bytes[0] ) * (256 ** 0)
  );
}

sub _read {
  my ($self, $length) = @_;

  $length ||= 4;
  my $str = substr( $self->{_data}, $self->{_pos}, $length );
  $self->{_pos} += $length;
  return $str;
}

sub _read_from {
  my ($self, $start, $length) = @_;
  $self->{_pos} = $start;
  $self->_read( $length );
}

sub _read_string {
  my $self = shift;
  my $start = $self->{_pos};
  my $end   = index( $self->{_data}, "\000", $start );
  my $str   = substr( $self->{_data}, $start, $end - $start );
  $self->{_pos} = $end + 1;
  return $str;
}

sub _read_string_from {
  my ($self, $start) = @_;
  $self->{_pos} = $start;
  $self->_read_string;
}

sub _test_from {
  my ($self, $start, $length) = @_;
  $length ||= 4;
  $start    = $self->{_pos} unless defined $start;
  return substr( $self->{_data}, $start, $length );
}

package #
  Win32::IEHistory::URL;

use strict;
use warnings;
use base qw( Class::Accessor::Fast );

__PACKAGE__->mk_ro_accessors(qw(
  url filename headers filesize last_modified last_accessed
));

package #
  Win32::IEHistory::LEAK;

use strict;
use warnings;
use base qw( Class::Accessor::Fast );

__PACKAGE__->mk_ro_accessors(qw(
  url filename headers filesize last_modified last_accessed
));

package #
  Win32::IEHistory::REDR;

use strict;
use warnings;
use base qw( Class::Accessor::Fast );

__PACKAGE__->mk_ro_accessors(qw( url ));

1;

__END__

=head1 NAME

Win32::IEHistory - parse Internet Explorer's history index.dat

=head1 SYNOPSIS

    use Win32::IEHistory;
    my $index = Win32::IEHistory->new( 'index.dat' );
    foreach my $url ( $index->urls ) {
      print $url->url, "\n";
    }

=head1 DESCRIPTION

This parses so-called "Client UrlCache MMF Ver 5.2" index.dat files, which are used to store Internet Explorer's history, cache, and cookies. As of writing this, I've only tested on Win2K + IE 6.0, but I hope this also works with some of the other versions of OS/Internet Explorer. However, note that this is not based on the official/public MSDN specification, but on a hack on the web. So, caveat emptor in every sense, especially for the redr entries ;)

Patches and feedbacks are welcome.

=head1 METHODS

=head2 new

receives a path to an 'index.dat', and parses it to create an object.

=head2 urls

returns URL entries in the 'index.dat' file. Each entry has url, filename, headers, filesize, last_modified, last_accessed accessors (note that some of them would return meaningless values).

=head2 leaks

returns LEAK entries (if any) in the 'index.dat' file. Each entry has url, filename, headers, filesize, last_modified, last_accessed accessors (note that some of them would return meaningless values).

=head2 redrs

returns REDR entries (if any) in the 'index.dat' file. Each entry has a url accessor.

=head1 SEE ALSO

L<http://www.latenighthacking.com/projects/2003/reIndexDat/>

=head1 AUTHOR

Kenichi Ishigaki, E<lt>ishigaki at cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Kenichi Ishigaki.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
