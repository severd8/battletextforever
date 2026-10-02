<p align="center"><img src="https://raw.githubusercontent.com/severd8/battletextforever/main/art/logo.png" width="160" alt="BattleText Forever logo"></p>

# BattleText Forever

**Scrolling combat text for World of Warcraft: Forever.**

BattleText Forever puts the fight on your screen: your hits, heals and misses scroll on one side, the damage you take on the other, and loot, experience and kills in the middle. It's built for Forever's addon rules, in the spirit of the classic scrolling combat text addons.

---

## Features

- **Your hits and heals**, with the spell's name and icon. Spell damage is tinted by its school.
- **Crits stand out.** They're bigger, pop out, and hold in place for a moment.
- **Rapid hits add up.** Hits from one spell that land together show as one total, like "Swipe 135 (x3)".
- **Misses, dodges, parries, blocks and resists**, both yours and your enemy's. Blocked, absorbed and resisted amounts are shown beside the number.
- **Damage and heals you take**, in their own area.
- **Notifications**: entering and leaving combat, killing blows, experience, reputation, honor, loot, money and skill ups.
- **Three text areas** you can drag anywhere on screen.
- **Your look**: four fonts, text size, crit size, scroll speed and distance, and straight or curved scrolling.
- **Choose what's shown**, and hide small hits.
- **Hide the game's own numbers**, so nothing is shown twice.
- **Your pet's hits**, when the Combat Log's filter includes your pet.

## Installation

1. Download the latest release.
2. Unzip it into your WoW: Forever `Interface\AddOns` folder so you end up with an `AddOns\BattleTextForever\` folder.
3. Restart the game, or type `/reload` if it's already running.

## Using it

- **Start it.** After you log in, click the **Start BattleText** button at the top of the screen. That's needed once per login (see Good to know). You can also bind a key to it.
- **Move the text.** Type `/btf unlock` (or tick **Move the text areas** in the options), drag the three boxes where you want them, then lock again.
- **See it without fighting.** Type `/btf test`, or right-click the minimap button.
- **Open the options.** Type `/btf`, or left-click the minimap button.

### Options window

| Side | What's there |
|---|---|
| **Text** (left) | Show BattleText, move the text areas, spell names, spell icons, crits pop and hold, curved scrolling, add up rapid hits, hide the game's own numbers, minimap button, font, text size, crit size, scroll time, scroll distance |
| **What you do** | Damage, heals, misses, pet, hide hits below a number |
| **What happens to you** | Damage, heals, avoids, power gains |
| **Notifications** | Combat, killing blows, experience, reputation, honor, loot, money, skill ups |

### Keybindings

Go to **Options → Keybindings → BattleText Forever**:

| Binding | Does |
|---|---|
| **Start BattleText** | Same as clicking the Start button |
| **Open options** | Opens or closes the options window |

### Slash commands

| Command | Does |
|---|---|
| `/btf` | Open or close the options |
| `/btf test` | Show sample text |
| `/btf lock` · `/btf unlock` | Lock or unlock the text areas |
| `/btf reset` | Put the text areas back where they started |
| `/btf on` · `/btf off` | Turn the text on or off |
| `/btf debug` | Print combat lines BattleText doesn't show (for bug reports) |

`/battletext` works too.

## Good to know

WoW: Forever doesn't let addons read the combat log. BattleText works from what the game does allow:

- **Your hits come from the Combat Log window's lines.** The game only writes those after the Combat Log tab has been opened once, which is what the **Start BattleText** button does for you (it opens the tab and switches back). It's needed once each time you log in or reload. If you keep the Combat Log as its own window, BattleText starts by itself.
- **They follow the Combat Log's filter.** With **My actions** (the default) you get everything you do. If you pick **What happened to me?** on that tab, your own hits stop showing until you switch back.
- **Damage you take** comes from a different game event and needs no setup. With the default filter it has no spell names. Make a Combat Log filter that includes both what you do and what happens to you, and incoming damage gets spell names too.
- **Enemy names aren't shown.** The game scrambles them in the lines addons can see.
- **The Combat Log needs its normal wording.** If you've turned on its "verbose" setting, turn it off.

## Troubleshooting

- **No numbers for your hits.** Click **Start BattleText**, or open the Combat Log tab once. Check that the Combat Log's filter is **My actions**.
- **Numbers show twice.** Tick **Hide the game's own numbers** in the options.
- **Something isn't shown.** Type `/btf debug`, fight, and report the "not shown" lines from chat.
- **The text is in the wrong place.** Type `/btf unlock` and drag the boxes, or `/btf reset`.

## Feedback and bug reports

Found a bug or have an idea? Please [submit it on GitHub](https://github.com/severd8/battletextforever/issues/new/choose). A short form asks for your class, your Combat Log filter and any error message. You'll need a free GitHub account. Otherwise, feel free to leave a comment on the CurseForge page.

## Support the addon

BattleText Forever is free. If you enjoy it, you can [leave a small tip on Ko-fi](https://ko-fi.com/tauntmasterforever). Thank you!

## Also by me

- **TauntMaster Forever**: one-click taunts off your healers and DPS, for tanks. Free on CurseForge.
- **ToppedOff Forever**: reminds you when buffs, food, reagents, ammo or gear need topping off. Free on CurseForge.
- **Outfitter Forever**: the classic Outfitter gear manager, ported to WoW Forever. Free on CurseForge.

## License

MIT — see [LICENSE](LICENSE).
