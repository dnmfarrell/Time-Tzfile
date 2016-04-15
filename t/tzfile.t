#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

BEGIN { use_ok 'Time::Tzfile' }

subtest version_one => sub {
  ok my $tzfile = Time::Tzfile->parse({
      filename => 't/London',use_version_one => 1}), 'parse tzfile v2';
  # validate header
  cmp_ok $tzfile->{header}{intro},    'eq', 'TZif', 'Intro is TZif';
  cmp_ok $tzfile->{header}{time_cnt}, '==', 243, 'Time count matches';
  cmp_ok $tzfile->{header}{leap_cnt}, '==',   0, 'Leap count matches';
  cmp_ok $tzfile->{header}{char_cnt}, '==',  17, 'Time count matches';
  cmp_ok $tzfile->{header}{type_cnt}, '==',   8, 'Time count matches';
  cmp_ok $tzfile->{header}{version},  '==',   2, 'Version matches';
  cmp_ok $tzfile->{header}{std_cnt},  '==',   8, 'Time count matches';
  cmp_ok $tzfile->{header}{gmt_cnt},  '==',   8, 'Time count matches';

  # validate body
  cmp_ok @{$tzfile->{transitions}},    '==',243, 'GMT entry count matches';
  cmp_ok @{$tzfile->{transition_idx}}, '==',243, 'GMT entry count matches';
  cmp_ok @{$tzfile->{ttinfo_structs}}, '==',  8, 'ttinfo entry count matches';
  cmp_ok @{$tzfile->{tz_abbreviation}},'==',  1, 'ttinfo entry count matches';
  cmp_ok @{$tzfile->{leap_seconds}},   '==',  0, 'leap entry count matches';
  cmp_ok @{$tzfile->{gmt_local}},      '==',  8, 'GMT entry count matches';
  cmp_ok @{$tzfile->{std_wall}},       '==',  8, 'STD entry count matches';
};

subtest version_two => sub {
  ok my $tzfile = Time::Tzfile->parse({filename => 't/London'}), 'parse tzfile v2';
  # validate header
  cmp_ok $tzfile->{header}{intro},    'eq', 'TZif', 'Intro is TZif';
  cmp_ok $tzfile->{header}{time_cnt}, '==', 243, 'Time count matches';
  cmp_ok $tzfile->{header}{leap_cnt}, '==',   0, 'Leap count matches';
  cmp_ok $tzfile->{header}{char_cnt}, '==',  17, 'Time count matches';
  cmp_ok $tzfile->{header}{type_cnt}, '==',   8, 'Time count matches';
  cmp_ok $tzfile->{header}{version},  '==',   2, 'Version matches';
  cmp_ok $tzfile->{header}{std_cnt},  '==',   8, 'Time count matches';
  cmp_ok $tzfile->{header}{gmt_cnt},  '==',   8, 'Time count matches';

  # validate body
  cmp_ok @{$tzfile->{transitions}},    '==',243, 'GMT entry count matches';
  cmp_ok @{$tzfile->{transition_idx}}, '==',243, 'GMT entry count matches';
  cmp_ok @{$tzfile->{ttinfo_structs}}, '==',  8, 'ttinfo entry count matches';
  cmp_ok @{$tzfile->{tz_abbreviation}},'==',  1, 'ttinfo entry count matches';
  cmp_ok @{$tzfile->{leap_seconds}},   '==',  0, 'leap entry count matches';
  cmp_ok @{$tzfile->{gmt_local}},      '==',  8, 'GMT entry count matches';
  cmp_ok @{$tzfile->{std_wall}},       '==',  8, 'STD entry count matches';
};

done_testing;
