# Changelog

## 1.2.0

- **Damage-over-time ticks are named**, with the spell's icon: Rake, Rip, Rend, Garrote, Rupture, Moonfire, Insect Swarm, Corruption, Immolate, Curse of Agony, Shadow Word: Pain, Flame Shock and more. Bleeds need Start BattleText clicked (it's how a tick is told from a swing).
- **Your damage shield is named** (Thorns, Lightning Shield, Retribution Aura, Fire Shield), once BattleText has seen it answer two blows.
- **New option: Damage shields** (under "What you do"). Untick it to hide your shield's hits.
- A hit of another school that lands in the same instant as your cast is no longer named after the cast (Thorns answering as you open with Claw).
- A spell that only ticks (Rip) no longer names a swing that lands as you cast it.

## 1.1.0

- **Your hits show again.** The game now hides the text of its combat log lines from addons, so BattleText reads your hits from the unit you hit instead: your target, and the mobs attacking you or your pet (turn on enemy nameplates to see the ones you aren't targeting). No setup needed when you play alone.
- **In a group**, click Start BattleText once after you log in: the game then tells BattleText when you did something, so other people's hits on your target are left out.
- What the game no longer says: which spell a hit was (it's named only when it lands the instant you cast), and whether a hit was yours or your pet's (alone, your pet's hits show with yours). Killing blow notices only appear when the game lets the lines be read.
- **15 more fonts** (20 in all), picked from a **dropdown**. Picking one shows a line in it straight away.
- **Closing the options window locks the text areas** and unticks "Move the text areas".
- `/btf debug` now also records each unit's hits and why one was or wasn't shown.

## 1.0.0

First release: scrolling combat text for WoW: Forever.

- **Your hits and heals** scroll in their own area, with spell names and icons. Crits are bigger, pop out and hold for a moment. Rapid hits from one spell add up on one line.
- **Damage and heals you take** scroll on the other side, with the attacks you dodge, parry, block or resist.
- **Notifications**: entering and leaving combat, killing blows, experience, reputation, honor, loot, money and skill ups.
- Three text areas you can drag anywhere, and options for font, size, crit size, speed, straight or curved scrolling, and what gets shown.
- A **Start BattleText** button after you log in: one click gets the game writing its combat lines.
- Your misses and your pet's hits show once you tick them in the Combat Log's "My actions" filter.
