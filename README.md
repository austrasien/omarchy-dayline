# Day line

A HUD-style rule along the bottom edge of the Omarchy shell, the third side of
the frame drawn by [Day tape](https://github.com/austrasien/omarchy-daytape) and
[Day bar](https://github.com/austrasien/omarchy-daybar).

Nothing shows at rest. It replaces the on-screen display:

- **Volume**: 0 to 200 % across the screen, 100 % in the middle, in the theme's
  accent up to 100 % and red beyond.
- **Screen and keyboard brightness**: 0 to 100 % in the accent.
- Each change sends a wave along the fill, which gathers speed and slams into
  the end it is heading for: the level going up, the left end going down.
- A card above the level names it and gives its value. Messages without a level
  show the card alone.
- **Dictation**: an 8-bit meter runs across the screen from one edge or the
  other while recording, in the theme's accent, then turns into a bar with a light
  swung along it while transcribing. What has been said grows from the opposite
  edge, over the meter; once it fills the band, it scrolls to the left.

- **Notifications**, from austraz.notifications, run along it like a news ticker,
  each behind its own icon, and go by once. Critical ones are red, go round until
  acknowledged, and hold the others back until then. A right click on one
  acknowledges it; a left click runs its action.

It shows over everything, a fullscreen video included. In use, the band rises
from the gap below the windows over their bottom edge, as the side rails do; the
windows themselves never move. Its surface takes no pointer and only exists while
something shows.

## Install

```sh
omarchy plugin add https://github.com/austrasien/omarchy-dayline.git --enable
```

After editing the QML, run `omarchy-restart-shell`.

## Wiring

It answers `omarchy-shell austraz.dayline osd '<json>'`, with the fields of
Omarchy's OSD model (`iconKey`, `hasProgress`, `value`, `maxValue`, `message`,
`duration`), and `omarchy-shell austraz.dayline dictation`, which answers `ok`
so that a dictation HUD can stand aside. Dictation reads
`$XDG_RUNTIME_DIR/voxtype/state`, `$XDG_RUNTIME_DIR/nemotron/levels.ndjson` and
`$XDG_RUNTIME_DIR/nemotron/text`, the text so far.

The on-screen display reaches it through
[Volume Overdrive](https://github.com/austrasien/omarchy-volume-overdrive), which
forwards to it. The live text comes from
[nemotron-dictation](https://github.com/austrasien/nemotron-dictation).

Notifications need a notification service that speaks its side of the ticker: on
`omarchy-shell notifications ticker` it stops showing toasts and writes
`$XDG_RUNTIME_DIR/austraz-notifications-ticker.json`, a list of
`{ id, summary, body, icon, urgent, timestamp }`, and it answers
`omarchy-shell notifications dismissId <id>` and `invoke <id>`. The stock Omarchy
service does not do this: without such a service, the ticker stays empty and
toasts show as usual.

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
