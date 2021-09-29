#!/usr/bin/env perl

use v5.12;
use strict;
use warnings;

use lib 'lib';
use Z2::Music;

my ($file, $world, $song, $out) = @ARGV;

$world //= 5;
$song //= 1;
$out //= 'z2.mid';

my @titles = (
  [ 'Overworld Intro', 'Overworld Theme', 'Battle Theme', 'Battle Theme Variation',
    'Item Fanfare', 'Empty', 'Empty', 'Empty', ],
  [ 'Town Intro', 'Town Theme', 'House Theme Var', 'House Theme',
    'Item Fanfare', 'Empty', 'Empty', 'Empty', ],
  [ 'Town Intro', 'Town Theme', 'House Theme Var', 'House Theme',
    'Item Fanfare', 'Empty', 'Empty', 'Empty', ],
  [ 'Palace Intro', 'Palace Theme', 'Palace Theme Var', 'Boss Theme',
    'Item Fanfare', 'Empty', 'Crystal Fanfare', 'Empty', ],
  [ 'Palace Intro', 'Palace Theme', 'Palace Theme Var', 'Boss Theme',
    'Item Fanfare', 'Empty', 'Crystal Fanfare', 'Empty', ],
  [ 'Great Palace Intro', 'Great Palace Theme', 'Zelda Theme', 'Credits Theme',
    'Item Fanfare', 'Triforce Fanfare', 'Final Boss Theme', 'Empty', ],
  [ 'Title Intro', 'Title Lead', 'Title Buildup', 'Title Theme', 'Title Breakdown', ],
);

say "Parsing song $titles[$world][$song]";

my $rom = Z2::Music->new($file);
my $midi = $rom->dump_song($world, $song);

$midi->write_to_file($out);
