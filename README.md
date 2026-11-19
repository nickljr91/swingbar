# SwingBar

Small, low-key swing timers for **World of Warcraft: Forever** (interface 16001).
It shows when your next auto attack lands so you can time spells and abilities around it.

- One bar per hand: **main hand**, **off hand** (only when dual wielding) and **ranged**.
- Looks like the classic cast bar, but smaller and semi-transparent. A flat "clean" look is included.
- Bars appear only while a swing is running, then fade out.

## Install

1. Download this repository and name the folder `SwingBar`.
2. Put it in `World of Warcraft/_forever_/Interface/AddOns/` (the folder that holds your other Forever addons).
3. Restart the game or `/reload`.

## Weapon types covered

| Bar | Weapon types |
| --- | --- |
| Main hand | One- and two-handed axes, maces and swords, daggers, fist weapons, polearms, staves, fishing poles, unarmed, druid forms |
| Off hand | Any one-handed weapon held in the off hand (axe, mace, sword, dagger, fist weapon) |
| Ranged | Bows, guns, crossbows, thrown weapons, wands |

Shields and held-in-off-hand items do not swing, so they get no bar.

## Settings

Open with `/swingbar` (or `/swb`), or Game Menu > Options > AddOns > SwingBar.

| Setting | What it does | Slash command |
| --- | --- | --- |
| Bar look | Classic cast bar or solid clean | `/swb style classic` / `clean` |
| Opacity | Overall transparency | `/swb alpha 0.1-1` |
| Background opacity | Darkness behind the bar | `/swb bg 0-1` |
| Scale | Size of everything | `/swb scale 0.5-2.5` |
| Width / Height | Bar dimensions | `/swb width 60-400`, `/swb height 4-30` |
| Gap between bars | Spacing | `/swb gap 0-30` |
| Colour | One colour per bar | panel only |
| Show spark / time left / weapon type | Extra detail on the bar | panel only |
| Drain instead of fill | Bar empties rather than fills | panel only |
| Hide bars when not swinging | Off = bars always visible | panel only |
| Enable per bar | Turn main hand, off hand or ranged off | panel only |
| Lock position | Unlock to drag the bars | `/swb unlock`, `/swb lock` |
| Test bars | Looping preview | `/swb test` |
| Reset | Back to defaults | `/swb reset` |

## How it works

WoW Forever does not let addons read the combat log. Instead the game fires a
`PLAYER_SWING` event with the swing duration and the hand (main, off, ranged) each time
an auto attack goes on cooldown. SwingBar starts the matching bar from that event,
rescales it if your attack speed changes mid-swing, and restarts it when you swap weapons.

## Development

```bash
lua5.1 tests/run.lua
```

The test loads the addon against a stubbed game API and checks the timer logic.
It cannot replace an in-game test.

## Licence

MIT

## Reporting a bug

Type `/swb debug`, reproduce the problem, and copy the chat lines it prints
(swing events and attack speeds). `/swb debug` again turns it off.
