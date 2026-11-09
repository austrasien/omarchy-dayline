# Day line

A HUD-style rule along the bottom edge of the Omarchy shell, the third side of
the frame drawn by [Day tape](https://github.com/austrasien/omarchy-daytape) and
[Day bar](https://github.com/austrasien/omarchy-daybar).

Nothing shows at rest. It replaces the on-screen display:

- **Volume**: 0 to 200 % across the screen, 100 % in the middle, in the theme's
  accent up to 100 % and red beyond.
- **Screen and keyboard brightness**: 0 to 100 % in the accent.
- A card above the level names it and gives its value. Messages without a level
  show the card alone.
- **Dictation**: an 8-bit meter runs out from the middle of the screen while
  recording, then turns into a bar with a light swung along it while transcribing.

It shows over everything, a fullscreen video included. Its surface takes no
pointer and only exists while something shows.

## Wiring

It answers `omarchy-shell austraz.dayline osd '<json>'`, with the fields of
Omarchy's OSD model (`iconKey`, `hasProgress`, `value`, `maxValue`, `message`,
`duration`), and `omarchy-shell austraz.dayline dictation`, which answers `ok`
so that a dictation HUD can stand aside. Dictation reads
`$XDG_RUNTIME_DIR/voxtype/state` and `$XDG_RUNTIME_DIR/nemotron/levels.ndjson`.

## Commands

```sh
omarchy-shell austraz.dayline demo recording   # or transcribing, or off
omarchy-shell austraz.dayline snapshot /tmp/dayline.png
```

## Tests

```sh
node --test test/*.test.js
```

## Credits

The pixel meter comes from [Omakoe](https://github.com/ok/omakoe) (MIT).

## License

MIT
