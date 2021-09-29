package Z2::Music;

use v5.12;
use strict;
use warnings;

use IO::File;
use MIDI;

#                       80,  , 82, 83, 84, 85, 86,  ,  ,  , 8a
#                      ( 1, 0,  2,  4,  6,  8, 16, 0, 0, 0, 10 );
our @_DURATION_TITLE = ( 6, 0, 12, 24, 36, 48, 96, 0, 0, 0, 60 );

our @_SONG_TABLES = (
  0x01a010,    # Overworld
  0x01a3da,    # East Towns
  0x01a3da,    # West Towns
  0x01a63f,    # Palaces 125
  0x01a63f,    # Palaces 346
  0x01a946,    # Great Palace
  0x0184ea,    # Title
);

sub new {
  my ($class, $file) = @_;

  my $fh = IO::File->new($file, 'r') or die "Unable to open $file: $!";
  my $rom = bless { fh => $fh }, $class;

  $rom->_build_pitch_lut();
  $rom->_build_duration_lut();

  return $rom;
}

sub _build_pitch_lut {
  my ($self) = @_;

  $self->_seek(0x01919f);

  for my $i (0 .. 61) {
    my $h = $self->_get_byte();
    my $l = $self->_get_byte();

    my $bits = $h << 8 | $l;
    my $freq = 1789773 / (16 * $bits + 1);
    my $midi = $bits > 0 ? int(12 * log($freq / 440) / log(2) + 69.5) : 0;

    $self->{pitch}[$i] = $midi;
    say STDERR sprintf "Pitch LUT %02x : %03x : % 3d", $i, $bits, $midi;
  }
}

sub _build_duration_lut {
  my ($self) = @_;

  $self->_seek(0x01915d);

  for my $tempo (0, 8, 16, 24, 32, 40) {
    printf STDERR "Duration LUT  %02x : ", $tempo;
    for my $i (0 .. 7) {
      my $ticks = $self->_get_byte();
      $self->{duration}{$tempo}[$i] = $ticks;
      printf STDERR " %02x", $ticks;
    }
    printf STDERR "\n";
  }
}

sub _seek {
  my ($self, $address) = @_;

  $self->{fh}->seek($address, 0);
}

sub _get_byte {
  my ($self) = @_;
  return ord $self->{fh}->getc;
}

sub _read {
  my ($self, $address, $length) = @_;
  $self->_seek($address);
  $self->{fh}->read(my $buffer, $length);
  return map { ord } split //, $buffer;
}

sub song_table {
  my ($self, $world) = @_;

  my $base = $_SONG_TABLES[$world];

  my @offsets = $self->_read($base, 8);
  return map { $base + $_ } @offsets;
}

sub phrase_table {
  my ($self, $world, $song) = @_;

  my $base    = $_SONG_TABLES[$world];
  my @table   = $self->song_table($world);
  my $address = $table[$song];

  $self->_seek($address);
  my @phrases = ();
  while (my $offset = $self->_get_byte) {
    push @phrases, $base + $offset;
  }

  return @phrases;
}

sub note {
  my ($self, $note, $tempo) = @_;

  my $duration = (($note & 0xc0) >> 6) + (($note & 0x01) << 2);
  my $pitch    = ($note & 0x3e) >> 1;

  my $d = $self->{duration}{$tempo}[$duration];
  my $p = $self->{pitch}[$pitch];

  die sprintf "Unable to parse note %02x (d%02x p%02x)", $note,
    $duration, $pitch
    if not defined $d or not defined $p;

  return [ $d, $p ];
}

sub title_notes {
  my ($self, $address, $max_length) = @_;

  $self->_seek($address);
  my @notes  = ();
  my $length = 0;

  my $duration = undef;
  while (1) {
    my $byte = $self->_get_byte();
    last if $byte == 0;

    if ($byte >= 0x80) {
      # TODO LUT for durations
      $duration = $_DURATION_TITLE[$byte % 0x10];
      die "Unknown duration $byte" unless $duration;
    } elsif ($byte == 0x02) {
      die "Rest before duration set" unless $duration;
      push @notes, [$duration, 0];
      $length += $duration;
    } else {
      die "Note before duration set" unless $duration;
      my $pitch = 69 + ($byte - 0x4c) / 2;
      push @notes, [$duration, $pitch];
      $length += $duration;
    }
    last if defined $max_length and $length >= $max_length;
  }

  return [@notes], $length;
}

sub notes {
  my ($self, $address, $tempo, $max_length) = @_;

  return [], $max_length || 0 unless defined $address;

  if ($tempo == 0) {
    # special handling for the title music, which always sets the tempo to 0x00
    return $self->title_notes($address, $max_length);
  }

  $self->_seek($address);
  my @notes = ();
  my $length = 0;

  while (1) {
    my $byte = $self->_get_byte();

    last if $byte == 0;
    my $note = $self->note($byte, $tempo);

    $length += $note->[0];
    push @notes, $note;
    last if defined $max_length and $length >= $max_length;
  }

  return [@notes], $length;
}

sub phrase_parts {
  my ($self, $address) = @_;

  my @bytes = $self->_read($address, 6);

  my $base = $bytes[1] + 256 * $bytes[2] + 0x10010;

  return (
    tempo    => $bytes[0],
    pulse1   => $base,
    pulse2   => $bytes[4] ? $base + $bytes[4] : undef,
    triangle => $bytes[3] ? $base + $bytes[3] : undef,
    noise    => $bytes[5] ? $base + $bytes[5] : undef,
  );
}

sub __midify {
  my ($seq, $track, $channel, $rest, $override) = @_;

  foreach my $note (@$seq) {
    my ($dur, $pitch) = @$note;

    if ($pitch == 0) {
      $rest += $dur;
    } else {
      $pitch -= 12       if $channel == 3;
      $pitch = $override if defined $override;

      $track->new_event('note_on',  $rest * 4, $channel, $pitch, 100);
      $track->new_event('note_off', $dur * 4,  $channel, $pitch, 100);

      $rest = 0;
    }
  }

  return $rest;
}

sub dump_song {
  my ($self, $world, $song) = @_;

  my @phrases = $self->phrase_table($world, $song);

  my $map      = MIDI::Track->new();
  my $pulse1   = MIDI::Track->new();
  my $pulse2   = MIDI::Track->new();
  my $triangle = MIDI::Track->new();
  my $noise    = MIDI::Track->new();

  $pulse1->new_event('patch_change', 0, 1, 1);
  $pulse2->new_event('patch_change', 0, 2, 2);
  $triangle->new_event('patch_change', 0, 3, 3);
  $noise->new_event('patch_change', 0, 10, 119);
  $map->new_event('set_tempo', 0, 60_000_000 / 150);

  my $p1r = 0;
  my $p2r = 0;
  my $tr  = 0;
  my $nr  = 0;

  foreach my $phrase (@phrases) {
    my %parts = $self->phrase_parts($phrase);

    my ($p1, $p1l) = $self->notes($parts{pulse1}, $parts{tempo});
    my ($p2, $p2l) = $self->notes($parts{pulse2},   $parts{tempo}, $p1l);
    my ($t,  $tl)  = $self->notes($parts{triangle}, $parts{tempo}, $p1l);
    my ($n,  $nl)  = $self->notes($parts{noise},    $parts{tempo}, $p1l);

    # If the noise channel is short (but not empty) loop it
    if ($nl > 0 and $nl < $p1l) {
      push @$n, (@$n) x ($p1l / $nl - 1);
    }

    warn " *** Wrong length for PW2 *** " if $p2l != $p1l;
    warn " *** Wrong length for TRI *** " if $tl != $p1l;

    $p1r = __midify($p1, $pulse1,   1,  $p1r);
    $p2r = __midify($p2, $pulse2,   2,  $p2r);
    $tr  = __midify($t,  $triangle, 3,  $tr);
    $nr  = __midify($n,  $noise,    10, $nr, 38);
  }

  my $opus = MIDI::Opus->new({
    format => 1,
    tracks => [ $map, $pulse1, $pulse2, $triangle, $noise ],
  });

  return $opus;
}

1;
