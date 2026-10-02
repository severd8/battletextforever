<p align="center"><img src="https://raw.githubusercontent.com/severd8/battletextforever/main/art/logo.png" width="160" alt="BattleText Forever logo"></p>

# BattleText Forever

**Scrolling combat text for World of Warcraft: Forever.**

BattleText Forever puts the fight on your screen: your hits and heals scroll on one side, the damage you take on the other, and loot, experience and kills in the middle. It's built for Forever's addon rules, in the spirit of the classic scrolling combat text addons.

---

## Features

- **Your hits and heals**, with the spell's name and icon, tinted by school. Crits are bigger and hold in place for a moment, rapid hits add up ("Swipe 135 (x3)"), and blocked, absorbed and resisted amounts show beside the number.
- **What happens to you**, in its own area: damage and heals you take, and the attacks you dodge, parry, block or resist.
- **Notifications**: combat, killing blows, experience, reputation, honor, loot, money and skill ups.
- **Three text areas** you can drag anywhere on screen.
- **Your look**: fonts, text and crit size, scroll speed and distance, straight or curved scrolling.
- **Your choice of what's shown.** Turn any kind of text off, hide small hits, and hide the game's own numbers so nothing shows twice.
- **Misses and your pet's hits**, once you tick them in the Combat Log's filter (see Good to know).

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
| `/btf debug` | Start or stop recording the combat lines the game sends (for bug reports) |
| `/btf copy` | Show the recorded lines in a box you can copy from |

`/battletext` works too.

## Good to know

WoW: Forever doesn't let addons read the combat log, so BattleText works from what the game does allow:

- **Click Start BattleText once per login.** Your hits and heals come from the Combat Log window's lines, and the game only writes those after that tab has been opened. The button opens it and switches back for you.
- **Keep the Combat Log's filter on "My actions"** (the default). On **What happened to me?** your own hits stop showing.
- **Misses and your pet are left out of that filter by default.** To add them: with **My actions** selected, right-click the Combat Log tab and choose **Settings**. Tick the **Misses** boxes under **Message Types** and **Pet** in the **Done By** column under **Message Sources**, then press **Okay**.
- **Damage you take has no spell names**, and **enemy names aren't shown** (the game scrambles them).
- **Leave "Use Verbose Mode" off** in the Combat Log's Formatting settings.

## Troubleshooting

- **No numbers for your hits.** Click **Start BattleText**, or open the Combat Log tab once. Check that the Combat Log's filter is **My actions**.
- **No misses, or nothing from your pet.** Tick them in the Combat Log's filter (see Good to know).
- **Numbers show twice.** Tick **Hide the game's own numbers** in the options.
- **Something isn't shown.** Type `/btf debug`, fight for a moment, then type `/btf copy` and copy the lines into a bug report. Type `/btf debug` again to stop.
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
