# Changelog

## 1.2.3

- **Shred is named.** Its hits were shown as a bare number, like a swing. The game reports Shred's hit just ahead of the cast, where other attacks (Claw, Rake) come just after it, so BattleText now goes by the combat log line that comes with the hit and no longer by which came first.
- For the same reason a damage shield's answer landing in the same instant as one of your attacks can't be named after the attack, even before the shield has been learned.

## 1.2.2

- No more false **Miss**. Some mobs' special attacks arrive in two parts, one of them for no damage, and the empty part was shown as a miss beside the real hit.

## 1.2.1

- **More than one damage shield at a time.** Thorns and a cloak that stings back were being mixed up: whichever hit first was called Thorns. Now each is its own.
- **Gear with a damage shield is recognised from its tooltip** ("When struck in combat, inflicts 1 Nature damage to the attacker") and its hits are named after the item, with the item's icon. (English game clients.)
- A buff's shield is learned only from clean answers to a blow, so a hit of yours landing in the same instant can't be mistaken for it.
- A shield's answer that lands in the same instant as your cast, just ahead of it, is no longer named after the cast.

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
