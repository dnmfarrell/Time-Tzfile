use autodie;
use strict;
use warnings;
package Time::Tzfile;

use Config;
#ABSTRACT: reads a binary tzfile into a hashref

=head1 SYNOPSIS

  use Time::Tzfile;

  # will get 64bit timestamps if available
  my $tzdata = Time::Tzfile->parse({filename => '/usr/share/zoneinfo/Europe/London'});

  # will always get 32bit timestamps
  my $tzdata = Time::Tzfile->parse({
    filename        => '/usr/share/zoneinfo/Europe/London',
    use_version_one => 1,
  });

=head1 METHODS

=head2 parse ({filename => /path/to/tzfile, use_version_one => 1})

The C<parse> takes a hashref containing the filename of the tzfile to open
and optionally a flag to use the version one (32bit) tzfile entry. Returns a
hashref containing the tzfile data.

Tzfiles can have two entries in them: the version one entry with 32bit timestamps
and the version two entry with 64bit timestamps. If the tzfile has the version
two entry, and if C<perl> is compiled with 64bit support, this method will
automatically return the version two entry. If you want to force the version one
entry, include the C<use_version_one> flag in the method arguments.

The hashref returned looks like this:

  {
    header         => {}, # version and counts for the body
    transitions    => [], # historical timestamps when TZ changes occur
    transition_idx => [], # index of ttinfo structs which apply to transitions
    ttinfo_structs => [], # hashrefs of gmt offset, dst flag & the tz abbrev idx
    tz_abbreviation=> $,  # scalar of tz abbreviations (GMT, BST etc)
    leap_seconds   => [], # hashrefs of the timestamp & offset to apply leap secs
    std_wall       => [], # arrayref of std wall clock indicators
    gmt_local      => [], # arrayref of gm local indicators
  }

I believe that all binary tzfiles are compiled with UTC timestamps, in which case
you can ignore C<std_wall> and C<gmt_local> entries for calculating offsets.

See L<#SYNOPSIS> for examples.

=cut

sub parse {
  my ($class, $args) = @_;

  open my $fh, '<:raw', $args->{filename};
  my $use_version_one = $args->{use_version_one};
  my $header = parse_header($fh);

  if ($header->{version} == 2 # it will have the 64 bit entries
      && !$use_version_one  # not forcing to 32bit timestamps
      && ($Config{use64bitint} eq 'define' # Perl is 64bit int capable
          || $Config{longsize} >= 8)
     ) {

    # jump past the version one entry
    skip_to_next_record($fh, $header);

    return {
      header          => $header,
      transitions     => parse_time_counts_64($fh, $header),
      transition_idx  => parse_time_type_indices($fh, $header),
      ttinfo_structs  => parse_types($fh, $header),
      tz_abbreviation => parse_timezone_abbrev($fh, $header),
      leap_seconds    => parse_leap_seconds_64($fh, $header),
      std_wall        => parse_std($fh, $header),
      gmt_local       => parse_gmt($fh, $header),
    };
  }
  else {
    return {
      header          => $header,
      transitions     => parse_time_counts($fh, $header),
      transition_idx  => parse_time_type_indices($fh, $header),
      ttinfo_structs  => parse_types($fh, $header),
      tz_abbreviation => parse_timezone_abbrev($fh, $header),
      leap_seconds    => parse_leap_seconds($fh, $header),
      std_wall        => parse_std($fh, $header),
      gmt_local       => parse_gmt($fh, $header),
    };
  }
}

sub parse_bytes (*$@) {
  my ($fh, $bytes_to_read, $template, @keys) = @_;

  my $bytes_read = sysread $fh, my($bytes), $bytes_to_read;
  die "Expected $bytes_to_read bytes but got $bytes_read"
    unless $bytes_read == $bytes_to_read;

  return [] unless $template;

  my @data = unpack $template, $bytes;

  if (@keys) {
    die sprintf("Mapping mismatch, got %d keys and %d data variables\n",
      scalar @keys, scalar @data) if @keys != @data;

    push @keys, @data;
    my @map = @keys[map { $_, $_ + @keys/2 } 0..(@keys/2 - 1)];
    return \@map;
  }
  return \@data;
}

sub parse_header {
  my ($fh) = @_;
  my $header_arrayref = parse_bytes($fh, 44, 'a4 A x15 N N N N N N',
    qw(intro version gmt_cnt std_cnt leap_cnt time_cnt type_cnt char_cnt));

  die 'This file does not appear to be a tzfile'
    if $header_arrayref->[1] ne 'TZif';

  # convert arrayref into hashref
  my %header = @$header_arrayref;
  return \%header;
}

sub parse_time_counts {
  my ($fh, $header) = @_;
  my $byte_count    =  4   * $header->{time_cnt};
  my $template      = 'l>' x $header->{time_cnt};
  return parse_bytes($fh, $byte_count, $template);
}

sub parse_time_counts_64 {
  my ($fh, $header) = @_;
  my $byte_count    =  8  * $header->{time_cnt};
  my $template      = 'q>' x $header->{time_cnt};
  return parse_bytes($fh, $byte_count, $template);
}

sub parse_time_type_indices {
  my ($fh, $header) = @_;
  my $byte_count    = 1   * $header->{time_cnt};
  my $template      = 'C' x $header->{time_cnt};
  return parse_bytes($fh, $byte_count, $template);
}

sub parse_types {
  my ($fh, $header) = @_;
  my $byte_count    = 6     * $header->{type_cnt};
  my $template      = 'l>cC' x $header->{type_cnt};
  my $data          = parse_bytes($fh, $byte_count, $template);

  my @mappings   = ();
  for (my $i = 0; $i < @$data-2; $i += 3) {
    push @mappings, {
      gmt_offset => $data->[$i],
      is_dst     => $data->[$i + 1],
      abbr_ind   => $data->[$i + 2],
    };
  }
  return \@mappings;
}

sub parse_timezone_abbrev {
  my ($fh, $header) = @_;
  my $byte_count    = 1   * $header->{char_cnt};
  my $template      = 'a' . $header->{char_cnt};
  return parse_bytes($fh, $byte_count, $template);
}

sub parse_leap_seconds {
  my ($fh, $header) = @_;
  my $byte_count    = 8      * $header->{leap_cnt};
  my $template      = 'l>l>' x $header->{leap_cnt};
  my $data          = parse_bytes($fh, $byte_count, $template);
  my @mappings   = ();
  for (my $i = 0; $i < @$data-1; $i += 2) {
    push @mappings, {
      timestamp => $data->[$i],
      offset    => $data->[$i + 1],
    };
  }
  return \@mappings;
}

sub parse_leap_seconds_64 {
  my ($fh, $header) = @_;
  my $byte_count    = 16      * $header->{leap_cnt};
  my $template      = 'q>q>' x $header->{leap_cnt};
  return parse_bytes($fh, $byte_count, $template);
}

sub parse_gmt {
  my ($fh, $header) = @_;
  my $byte_count    = 1   * $header->{gmt_cnt};
  my $template      = 'c' x $header->{gmt_cnt};
  return parse_bytes($fh, $byte_count, $template);
}

sub parse_std {
  my ($fh, $header) = @_;
  my $byte_count    = 1   * $header->{std_cnt};
  my $template      = 'c' x $header->{std_cnt};
  return parse_bytes($fh, $byte_count, $template);
}

sub skip_to_next_record {
  my ($fh, $header) = @_;
  my $bytes_to_skip = 4 * $header->{time_cnt}
                    + 1 * $header->{time_cnt}
                    + 6 * $header->{type_cnt}
                    + 1 * $header->{char_cnt}
                    + 8 * $header->{leap_cnt}
                    + 1 * $header->{gmt_cnt}
                    + 1 * $header->{std_cnt}
                    + 44; # next header (redundant)
  parse_bytes($fh, $bytes_to_skip);
}

1;
__END__

=head1 SEE ALSO

=over 4

=item * L<DateTime::TimeZone> - automatically uses text versions of the Olsen db to calculate timezone offsets

=item * L<DateTime::TimeZone::Tzfile> - applies TZ offsets from binary tzfiles to DateTime objects

=back

=head1 TZFILE FORMAT INFO

I found these resources useful guides to understanding the tzfile format

=over 4

=item * Tzfile L<manpage|http://linux.die.net/man/5/tzfile>

=item * Very useful description of tzfile format from L<Bloomberg|https://bloomberg.github.io/bde/baltzo__zoneinfobinaryreader_8h_source.html>

=item * Wikipedia L<entry|https://en.wikipedia.org/wiki/IANA_time_zone_database> on the TZ database

=back
