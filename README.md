<p align="center"><img src="https://raw.githubusercontent.com/severd8/battletextforever/main/art/logo.png" width="160" alt="BattleText Forever logo"></p>

# BattleText Forever

**Scrolling combat text for World of Warcraft: Forever.**

BattleText Forever puts the fight on your screen: your hits scroll on one side, the damage you take on the other, heals under your character, and loot and experience in the middle. It's built for Forever's addon rules, in the spirit of the classic scrolling combat text addons.

---

## Features

- **Your hits**, tinted by school, with the spell's name and icon when the game lets BattleText tell which spell it was. Crits are bigger and hold in place for a moment, and rapid hits of one spell add up ("Swipe 135 (x3)").
- **What happens to you**, in its own area: the damage you take, and the attacks you dodge, parry, block or resist.
- **Heals**, the ones you get and the ones you do, in their own Healing area under your character (or with the damage, if you prefer).
- **Notifications**: combat, experience, reputation, honor, loot, money, skill ups, a paladin's seals going on and coming off, and (if you turn it on) your buffs.
- **Fight summary**: when a fight ends, your damage, DPS and healing ("4,820 damage (127 DPS), 1,200 healed in 38s").
- **Four text areas** you can drag anywhere on screen, each with its own movement: Scroll, Pop, Fountain or Horizontal.
- **Your look**: 23 fonts, an outline (thin or thick) or a drop shadow, text and crit size, bigger text for bigger hits, short numbers (12.3k), scroll speed and distance, your own colors, and for each area its own size, opacity and direction (up or down, straight or curved).
- **Your choice of what's shown.** Turn any kind of text off, hide your auto attacks, icons and spell names per area, hide small hits and heals, and hide the game's own numbers so nothing shows twice.
- **Sounds** if you want them, on your crits and killing blows: pick from 18 of the game's sounds (Crit, Impact, Anvil, Battle horn, Boss defeated, Cheers, Epic loot...).
- **Settings per character** if you want them, starting from a copy of your shared ones, and **share your settings** with a friend as a line of text.

## Installation

1. Download the latest release.
2. Unzip it into your WoW: Forever `Interface\AddOns` folder so you end up with an `AddOns\BattleTextForever\` folder.
3. Restart the game, or type `/reload` if it's already running.

## Using it

- **Your hits show as soon as you log in**: on your target, and on the mobs attacking you or your pet.
- **Click Start BattleText** (the button at the top of the screen) once after you log in. With it, BattleText can name the ticks of your bleeds and, in a group, tell your hits from everyone else's (see Good to know). You can also bind a key to it. If you haven't clicked it ten seconds after logging in, a line in chat reminds you (turn off **Remind me to click Start** in the options to stop that). Right-click the button to hide it until you log in again.
- **Move the text.** Turn on **Move the text areas** in the options (or type `/btf unlock`) and drag the four boxes where you want them. Closing the options locks them again.
- **See it without fighting.** Type `/btf test`, or right-click the minimap button.
- **Open the options.** Type `/btf`, or left-click the minimap button.

### Options window

The options have the same look as TauntMaster Forever, ToppedOff Forever and Outfitter Forever: tabs down the left and a switch for each setting. Point at a setting's name for what it does; a setting that does nothing with your other choices is greyed out.


| Tab | What's there |
|---|---|
| **General** | Show BattleText, move the text areas, hide the game's own numbers, minimap button, remind me to click Start, settings for this character only, show sample text, reset positions, share settings (export and import) |
| **Text** | Font (a list of 23), outline and crit outline (none, thin, thick or shadow), text size, crit size, short numbers (12.3k), size by hit |
| **Motion** | Crits stay in place, add up rapid hits, time on screen, area height, how long ticks and area hits add up |
| **Outgoing** | Damage, misses, auto attacks, pet, damage shields, name seal hits, icons, names, hide hits below a number; Appearance: size, opacity, movement, scroll upward and curved scrolling |
| **Incoming** | Damage, avoids, power gains, icons, names; Appearance: size, opacity, movement, scroll upward and curved scrolling |
| **Healing** | Own area for heals, show overhealing, heals you get, heals you do, icons, names, show who you healed, hide heals below a number; Appearance: size, opacity, movement and scroll upward |
| **Notifications** | Show: combat, killing blows, experience, reputation, honor, loot, money, skill ups, seals, buffs. Extras: fight summary, icons, crit sound and kill sound (each with its own pick of sound). Appearance: size, opacity, movement and scroll upward |
| **Colors** | The color of your hits, spells, misses, damage you take, avoids, power gains, heals, notifications, combat and killing blows, experience, loot, seals and buffs; reset colors |

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
| `/btf check` | Check the spells, texts and icons BattleText uses against your game, and report anything missing |
| `/btf export` · `/btf import` | Share your settings as a line of text, or take someone else's |

`/battletext` works too.

## Good to know

WoW: Forever doesn't let addons read the combat log. The game tells an addon **what happened to a unit** (it took 27 damage, it dodged), but not **who did it** or **with which spell**. BattleText works from that:

- **Your hits are read from the unit you hit**: your target, and the mobs attacking you or your pet. An area spell (Fire Nova, Arcane Explosion, Swipe...) also shows on every other mob it hits at the same moment. Turn on **enemy nameplates** to see your hits on the ones you aren't targeting.
- **Alone, every hit on those units is shown as yours**, your pet's hits included (they can't be told apart, so they aren't marked). The exception is a mob someone else tagged that isn't after you or your pet: its hits are theirs and aren't shown (with Start BattleText clicked, your own hits on it still show).
- **Click Start BattleText once per login.** It opens the Combat Log tab and switches back for you. From then on the game tells BattleText *when* you did something. In a group, only that many hits are shown, so other people's are left out (now and then a number may still be a groupmate's hit that landed at the same moment as yours). Keep the Combat Log's filter on **My actions** (the default).
- **Spell names and icons** show for:
  - hits that land the instant you cast (instant attacks and spells with no travel time);
  - the ticks of your damage-over-time spells (Rake, Rip, Rend, Moonfire, Corruption, Shadow Word: Pain and the like). Bleeds need Start BattleText clicked;
  - your **damage shields**: buffs (Thorns, Lightning Shield, Retribution Aura, Fire Shield), once BattleText has seen one answer two blows, and gear that hurts whoever strikes you (named after the item). Turn off **Damage shields** in the options to hide these;
  - a paladin's **seal** (Righteousness, Command): its Holy damage landing with your swing. Turn off **Name seal hits** in the options to show it as a plain number.

  Other hits show as a plain number in their school's color.
- **Seals in a fight.** The game hides your buffs during a fight, so a seal coming off is worked out: Judgement uses it up, a new seal replaces it, or its 30 seconds run out.
- **Buffs** (off unless you turn them on) show when they go on or come off. The game hides your buffs during a fight: there, a buff you put on yourself (Slice and Dice, Evasion, Sprint...) shows as you cast it, and the rest of what changed, including when those ran out, shows when the fight ends. Food, drink, and buffs with no time limit (mounts, auras, stances) aren't shown, and nothing is shown when you die.
- **The last swing on a mob may not show**: the game stops reporting a unit the moment it dies.
- **Damage you take has no spell names.**
- **The fight summary counts what BattleText can read.** When the game hides a hit's number, it isn't in the total. Killing blows (and their sound) need the game to let BattleText read its combat lines.
- **Auto attacks off**: without the game's combat lines, a physical hit BattleText can't name counts as a swing and is hidden too.
- When the game does let BattleText read the Combat Log's lines, they're used instead: every hit then has its spell, and your pet's hits are marked.

## Troubleshooting

- **No numbers for your hits.** Target what you're hitting, or turn on enemy nameplates. In a group, click **Start BattleText**.
- **A bleed's ticks have no name.** Click **Start BattleText**.
- **Start BattleText does nothing.** A chat addon that replaces the game's chat window (like Chattynator) hides the game's Combat Log tab, which the button opens, and there's no real way around that. Alone, your hits still show without it; in a group, other people's hits may show as yours, and bleed ticks have no name. Right-click the button to hide it. The button also goes away by itself if the combat lines start some other way.
- **Other people's hits show as mine.** In a group, click **Start BattleText** and keep the Combat Log's filter on **My actions**.
- **Numbers show twice.** Turn on **Hide the game's own numbers** in the options.
- **Something isn't shown.** Type `/btf debug`, fight for a moment, then type `/btf copy` and copy the lines into a bug report. Type `/btf debug` again to stop.
- **A spell or icon looks wrong.** Type `/btf check`, then `/btf copy`, and add the report to a bug report.
- **The text is in the wrong place.** Type `/btf unlock` and drag the boxes, or `/btf reset`.

## Feedback and bug reports

Found a bug or have an idea? Please [submit it on GitHub](https://github.com/severd8/battletextforever/issues/new/choose). A short form asks for your class, your Combat Log filter and any error message. You'll need a free GitHub account. Otherwise, feel free to leave a comment on the CurseForge page.

## Support the addon

BattleText Forever is free. If you enjoy it, you can [leave a small tip on Ko-fi](https://ko-fi.com/tauntmasterforever). Thank you!

## Also by me

- **TauntMaster Forever**: one-click taunts off your healers and DPS, for tanks. Free on CurseForge.
- **ToppedOff Forever**: reminds you when buffs, food, reagents, ammo or gear need topping off. Free on CurseForge.
- **Outfitter Forever**: the classic Outfitter gear manager, ported to WoW Forever. Free on CurseForge.
- **[AuctionHouse Forever](https://www.curseforge.com/wow/addons/auctionhouse-forever)**: a bigger Auction House window, so long item names stop getting cut off and you see more results at once. Free on CurseForge.

## License

MIT — see [LICENSE](LICENSE).

The fonts in the `Fonts` folder are open fonts, unmodified, each under its own licence (in `Fonts/Licenses`): Anton, Archivo Black, Bangers, Barlow Condensed, Bebas Neue, Cinzel Decorative, Fira Sans, Lato, Metamorphous, New Rocker, Poppins, Press Start 2P, PT Sans Narrow, Rajdhani and Russo One (SIL Open Font License 1.1), Luckiest Guy and Permanent Marker (Apache License 2.0), and Ubuntu (Ubuntu Font Licence 1.0).
