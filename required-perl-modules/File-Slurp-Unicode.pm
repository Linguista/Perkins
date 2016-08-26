#  Copyright (c) 2010 David Caldwell,  All Rights Reserved. -*- cperl -*-

package File::Slurp::Unicode; use strict; use warnings;

our $VERSION = '0.7.1';

use base 'Exporter' ;
our %EXPORT_TAGS = ( 'all' => [ qw( read_file write_file append_file read_dir ) ] ) ;
our @EXPORT = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT_OK = qw( slurp ) ;

*slurp = \&read_file ;

use File::Slurp ();
use Encode;
use Carp;

sub read_file {
    my ($file_name, %args) = @_ ;

    my $binary = ($args{encoding}||'') eq 'binary';
    my $decode = sub {
        map { $binary ? $_ : decode($args{encoding} // 'utf8', $_) } @_;
    };

    if ($args{array_ref}) {
        my $r = File::Slurp::read_file($file_name, %args);
        return [ $decode->(@$r)];
    } elsif ($args{scalar_ref}) {
        my $r = File::Slurp::read_file($file_name, %args);
        return \($decode->($$r))[0];
    } elsif (wantarray) {
        my @r = File::Slurp::read_file($file_name, %args);
        return $decode->(@r);
    } elsif (defined wantarray) { # scalar context
        my $r = File::Slurp::read_file($file_name, %args);
        return ($decode->($r))[0];
    } elsif ($args{buf_ref}) {
        File::Slurp::read_file($file_name, %args);
        ${$args{buf_ref}} = ($decode->(${$args{buf_ref}}))[0];
        return; # void context
    }
    croak "What on earth did you do to get here?";
}

sub write_file {
    my $file_name = shift ;
    my $args = ( ref $_[0] eq 'HASH' ) ? shift : {} ;

    my $binary = ($args->{encoding}||'') eq 'binary';
    my $encode = sub {
        map { !utf8::is_utf8($_) ? $_ :
                  $binary ? croak "Can't encode wide characters as binary"
                          : encode($args->{encoding} // 'utf8', $_)
            } @_
    };

    my @data;
    if ($args->{buf_ref}) {
        @data = $encode->(${$args->{buf_ref}});
    } elsif (ref $_[0] eq 'SCALAR') {
        @data = $encode->(${$_[0]});
    } elsif (ref $_[0] eq 'ARRAY') {
        @data = $encode->(@{$_[0]});
    } else {
        @data = $encode->(@_);
    }

    File::Slurp::write_file($file_name, $args, @data);
}

sub append_file {
    my $file_name = shift ;
    my $args = ( ref $_[0] eq 'HASH' ) ? shift : {} ;
    $args->{append} = 1;
    write_file($file_name, $args, @_);
}

*read_dir = \&File::Slurp::read_dir;

1;

__END__

=head1 NAME

File::Slurp::Unicode - Reading/Writing of Complete Files with Character Encoding Support

=head1 SYNOPSIS

  use File::Slurp::Unicode;

  my $text = read_file('filename', encoding => 'utf8');
  my @lines = read_file('filename'); # utf8 is assumed if no encoding.

  write_file('filename', { encoding => 'utf16' }, @lines);

  # same as File::Slurp::write_file (ie. no encoding):
  write_file('filename', { encoding => 'binary' }, @lines);

  use File::Slurp::Unicode qw(slurp);

  my $text = slurp('filename', encoding => 'latin1');

=head1 DESCRIPTION

This module wraps L<File::Slurp> and adds character encoding support through
the B<< C<encoding> >> parameter. It exports the same functions which take
all the same parameters as File::Slurp. Please see the L<File::Slurp>
documentation for basic usage; only the differences are described from here
on out.

=head2 B<read_file>

Pass in an argument called B<< C<encoding> >> to change the file
encoding. If no argument is passed in, UTF-8 encoding is assumed.

The special encoding B<'binary'> is interpreted to mean that there should
be no decoding done to the data after reading it. This is pretty much the
same as calling C<File::Slurp::read_file()> directly. This option is here
only to make code which needs to read both binary and text files look
uniform.

=head2 B<write_file>

Pass in an argument called B<< C<encoding> >> to change the file
encoding. If no argument is passed in and no wide characters are present in
the output data, then no conversion will be done. If there are wide
characters in the output data then UTF-8 encoding is assumed.

The special encoding B<'binary'> is interpreted to mean that there should
be no encoding done to the data before writing. If you pass a wide string (a
string with Perl's internal 'utf8 bit' set) to C<write_file> and set the
encoding to 'binary' it will die with an appropriate message. This is pretty
much the same as calling C<File::Slurp::write_file()> directly. This option
is here only to make code which needs write both binary and text files look
uniform.

=head1 SEE ALSO

L<File::Slurp>

=head1 BUGS

None known. Contact author or file a bug report on CPAN if you find any.

=head1 COPYRIGHT

This library is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

Copyright (C) 2010 David Caldwell

=head1 AUTHOR

David Caldwell E<lt>david@porkrind.orgE<gt>

L<http://porkrind.org/>

=head1 PROJECT HOME

L<http://github.com/caldwell/File-Slurp-Unicode>

=cut
