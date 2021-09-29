#!/bin/bash

parse_song() {
  local rom="$1"
  local world="$2"
  local song="$3"
  local name="$4"

  local file="$world$song-$name.mid"
  perl parser.pl "$rom" "$world" "$song" "$world-$song-$name.mid"
}

main() {
  local rom="$1"

  parse_song "$rom" 0 0 "overworld-intro"
  parse_song "$rom" 0 1 "overworld-theme"
  parse_song "$rom" 0 2 "battle-theme"
  parse_song "$rom" 0 4 "item-fanfare"

  parse_song "$rom" 1 0 "town-intro"
  parse_song "$rom" 1 1 "town-theme"
  parse_song "$rom" 1 2 "house-theme"
  parse_song "$rom" 1 4 "item-fanfare"

  parse_song "$rom" 3 0 "palace-intro"
  parse_song "$rom" 3 1 "palace-theme"
  parse_song "$rom" 3 2 "boss-theme"
  parse_song "$rom" 3 4 "boss-fanfare"
  parse_song "$rom" 3 6 "crystal-fanfare"

  parse_song "$rom" 5 0 "great-palace-intro"
  parse_song "$rom" 5 1 "great-palace-theme"
  parse_song "$rom" 5 2 "zelda-theme"
  parse_song "$rom" 5 3 "credits-theme"
  parse_song "$rom" 5 4 "item-fanfare"
  parse_song "$rom" 5 5 "triforce-fanfare"
  parse_song "$rom" 5 5 "final-boos-theme"

  parse_song "$rom" 6 0 "title-intro"
  parse_song "$rom" 6 1 "title-leadin"
  parse_song "$rom" 6 2 "title-buildup"
  parse_song "$rom" 6 3 "title-main"
  parse_song "$rom" 6 4 "title-breakdown"
}

main "$@"
