# BattleText Forever — developer notes

Scrolling combat text for **World of Warcraft: Forever** (interface 16001, client 1.60.x): your hits, heals and misses, the damage you take, and notifications.

- Author: `severd8`. License: MIT.
- CurseForge project ID: `1722502` (in the `.toc` as `X-Curse-Project-ID`).
- Sister addons: TauntMaster Forever, ToppedOff Forever, Outfitter Forever. This project's setup mirrors ToppedOff's.
- Written from scratch. It's in the spirit of MikScrollingBattleText, but uses none of its code (MSBT is All Rights Reserved, and its combat log parser can't work on Forever).

## Files

- `BattleTextForever.toc` — `## Version: @project-version@` is filled in by the packager from the git tag. `BattleTextForeverDB` holds every setting (account-wide).
- `Parse.lua` — turns one Combat Log line into a table (`ns.Parser:Parse(line)`). Its only game calls are reading the game's text and your own GUID.
- `Core.lua` — settings, the four scroll areas and their animation (`Emit`, `Animate`), turning `UNIT_COMBAT` and parsed lines into text (`OnUnitCombat`, `OnUnitHit`, `ShowCombat`), notifications, the Start button, minimap button, slash commands, events.
- `Options.lua` — the options window.
- Text thickness: the game can't make a font's letters bolder, so "thickness" is the outline round them, the font flags `""`, `OUTLINE` and `THICKOUTLINE` (`BT.OUTLINES`). `db.outline` is for normal lines, `db.critOutline` for crits (`OutlineFlags`). `db.scrollUp` turns a line's path round in `Animate`; nothing else about it changes.
- Heals: with `db.healArea` (on by default) every heal goes to the `heal` area (`HealArea`), else to `incoming` (on you) or `outgoing` (yours) as before. The area is 0.6 of the scroll distance (`heightScale`) and scrolls at the usual pace. `db.healOver` shows overhealing, `db.minHeal` hides small heals (`HealShown`; a hidden amount always shows). The older tests turn `healArea` off and read heals where they were; "the Healing area" step covers it.
- `Fonts/` — 15 open fonts, unmodified, as static `.ttf` files (from the google/fonts repository), with each one's licence in `Fonts/Licenses/` (`<Family>-OFL.txt`, `-UFL.txt` or `-Apache.txt`; the licences require the text to ship with the font). `BT.FONTS` in `Core.lua` lists them after "Default" and the game's four. A test checks every listed file and its licence exist.
- `Bindings.xml` — keybindings (loaded automatically): `CLICK BattleTextForeverStart:LeftButton` and `BATTLETEXTFOREVER_OPTIONS`.
- `Media/Icon.tga` — the logo mark (64×64 TGA). `art/` — logo sources (not shipped): `logo.svg`, `logo.png` (CurseForge and README), `icon.svg`.
- `tests/` — offline tests and the layout renderer (not shipped).
- `.github/` — `test.yml` (tests on every push), `release.yml` (on a `v*` tag: tests, package, upload to CurseForge; needs the `CF_API_KEY` secret), `add-to-project.yml` (new issues go to the GitHub project; needs `ADD_TO_PROJECT_PAT`), issue forms.

## Where the combat data comes from

Forever refuses `COMBAT_LOG_EVENT` and `COMBAT_LOG_EVENT_UNFILTERED` to addons. What's left:

- **`UNIT_COMBAT`** — what happened to a unit: `unit, action, flag, amount, schoolMask`. No source, no spell. This is the one that always works, and since 1.1.0 it's the main source (next section).
- **`COMBAT_LOG_MESSAGE`** — the finished text of each Combat Log window line. The game **hides the text** (below), so mostly it only says *that* you did something.

### The lines are hidden (since 2026-10-03)

On 2026-10-02 the lines arrived as readable text and 1.0.0 was built on parsing them. On 2026-10-03 (client 1.60.1.70205) every live line arrived as a **`|Ky<n>|k` token** (`|Ky7|k`, `|Ky8|k`, ...): a "K-string", which a font string can display but an addon can't read, split or measure. Blizzard's API notes have said so all along (`CombatLogSecureDocumentation.lua`: "A preformatted combat log message protected by a |K string wrapper"); none of the game's Lua changed between the builds, so the switch is in the client or on the server. Other Forever addons report the same and say lines can still be readable at times (out of combat), so **both paths are kept**: a readable line is parsed as before, a hidden one is only counted.

### Hits from `UNIT_COMBAT` (`OnUnitHit`)

Registered for every unit (`RegisterEvent`, not `RegisterUnitEvent`). `"player"` goes to `OnUnitCombat` as before (what happens to you); every other unit token goes to `OnUnitHit`, which decides whether it's something you did:

- **You and your pet under other names** (`targettarget`, `raid3`, `focus`...) are dropped: `"player"` has its own event, and of what happens to your pet only heals on the `"pet"` token are shown (as your heal).
- **Damage and misses** need a unit you can attack (`UnitCanAttack`) that you're **fighting**: your target, your pet's target, or a unit whose target is you or your pet (`Fighting`). So a mob someone else is fighting nearby isn't yours. Units other than your target only have a token when their **nameplate** is showing.
- **Heals** need a friendly unit: alone, your target; vouched for (below), any friendly unit.
- **One hit, many names.** The event fires once per token the unit has (`target`, `nameplate3`, `focus`). `FirstSight` keeps, per frame and per GUID, only the first token seen, so duplicates go and two real hits in one frame stay. With no readable GUID, your target counts under `target` only.
- **A readable line of yours** (or your pet's) in the last 1.2s (`readAt`) means the log is showing your hits itself: the unit's hits are dropped so nothing is doubled.
- **Alone**, everything that passes is shown. Your pet's hits can't be told from yours.
- **In a group**, once a hidden line has been seen (`hiddenSeen`), a hit must be **vouched for** (`ClaimHit`): with the "My actions" filter every line is an action of yours, so each hidden line is one credit (`NoteHiddenLine`), good for 1.2s (`CREDIT_TIME`) and for one hit. Hits are worked out when their frame is over, so a line that arrives just behind its hit still counts. Imperfect by nature: a groupmate's hit landing between your line and your hit takes the credit (and shows their number instead of yours). In a group before any line has arrived (Start not clicked), every hit on a unit you're fighting is shown.
- Amount, crit (`flag == "CRITICAL"`) and school (`schoolMask`: 1 physical, 2 holy, 4 fire, 8 nature, 16 frost, 32 shadow, 64 arcane) come from the event. `GLANCING`, `BLOCK_REDUCED`, `ABSORB`, `RESIST` flags on a hit add a note. A `WOUND` for 0 is a miss (the flag says how), as for the player. A hidden (secret) amount is handed to the game to draw (`Emit`'s `opts.secret`).

### Which spell it was (`ResolveFrame`)

A hit that passes isn't shown at once. Everything in a frame (hidden lines, your casts, hits) goes into `self.seq` in the order it came (`Queue`), and a zero-delay timer works the frame out when it's over (`FlushHits` → `ResolveFrame`), because what comes before and after a hit says what it was. Tests look through `lines()`/`last()`, which flush first.

What a real fight looks like (`tests/real_fight.txt`, a cat druid with Thorns, 2026-10-03), and the rules read off it:

- **An instant attack**: `hidden, CAST, hidden, hit`, all in one frame. Rule: **exactly one cast in the frame names its hits** (`UNIT_SPELLCAST_SUCCEEDED` for the player, `OnSpellcast`). Not for a spell that only ticks (`direct` false in the table: Rip's cast names no damage, though it names its own miss), and not for a hit of another school than the cast's first hit, or than the school the spell was seen to have before (`spellSchool`): Thorns answered in the very frame of an opening Claw.
- **A swing**: its line, then the hit 0.2–1.2s later (with the animation), usually with no line in the hit's frame. In cat form (a swing a second) a swing's hit sometimes lands in the frame of the *next* swing's line: then the order is `hidden, hit`.
- **A tick**: `hit, hidden` in one frame, the line right behind the hit (10 of 10). Rule (`TickFor`): the hit's unit has a damage-over-time spell of yours on it (remembered from the cast, against your target then: `self.dots[key][name]`, forgotten after 45s or when the cast's own frame holds a miss), the hit is on its beat (a whole number of periods since the cast, give or take 0.25s; the recording's ticks were within 0.09s), of its school, and **a line comes after the hit in the frame** (each line vouches for one tick). With no lines arriving at all (Start not clicked), a tick is named on beat and school alone, and only if it isn't physical: a bleed's tick would be a coin toss against a swing.
- **A damage shield**: a hit with no line (`DAMAGE_SHIELD` isn't in the "My actions" filter), followed 0.3–1.0s later by `UNIT_COMBAT player WOUND` (the blow it answered, shown with its animation). There can be several at once: in `tests/real_fight2.txt` every blow is answered by 11 Nature (Thorns) and 1 Nature (a cape, "Equip: When struck in combat, inflicts 1 Nature damage to the attacker"), in the same frame. (The 1s in the first recording were the cape too; 1.2.0 took them for Thorns.)
  - **Gear** (`ScanItemShields`, `self.itemShields`): each equipped item's tooltip (`C_TooltipInfo.GetInventoryItem`) is searched for "inflicts N School damage to the attacker". English only. That gives the amount, school, name and icon outright; a hit of that school and amount is the item's. Read when gear changes, on entering the world, and as a fight starts and ends (never in one).
  - **Buffs** (`ScanShield`, `self.buffShields` by name): your buffs are read on `UNIT_AURA`, entering the world and as a fight starts and ends; they're hidden in a fight, so the last answer stands, and casting one adds it. A buff's amount isn't known, so it's **learned** (`ShieldFor` → `ConfirmShield` → `LearnShield`): a hit of the buff's school that nothing else explains waits up to 1.2s for a blow on you. While the hidden lines are arriving, only a hit from a frame with no line in it counts (a spell of yours landing has its line). An amount that has answered two blows is given to the buff whose description names it (`C_Spell.GetSpellDescription`, whole numbers), or to the only buff it could be when it's the only amount needing an owner; it takes three answers to replace an amount learned before. Kept in `db.shieldAmounts[name]`. The amount test is what keeps a druid's Wrath from being taken for Thorns.
  - A known shield's hit (`KnownShield`) is the shield's even in the frame of a cast, unless the cast is of that school too.
- **A hit on you for nothing** (`UNIT_COMBAT player WOUND` with amount 0 and no flag) is a miss only on its own. Some mobs' special attacks arrive as `WOUND 0` and `WOUND 33` in one frame (`tests/real_fight3.txt`, three times, each a blow about twice a normal one): the empty part is queued (`nothing`) and dropped when a blow landed in the same frame (`blow`). A zero with a flag (`ABSORB`, `BLOCK`, `RESIST`) is its own attack and shows at once.
- **Which hit is the cast's** (`byLine` in `ResolveFrame`, since 1.2.3): the hit with a line of its own just ahead of it in the frame, on either side of the cast. Claw and Rake arrive as `CAST, line, hit`; Shred arrives as `line, hit, CAST` (`tests/real_fight4.txt`, and until 1.2.3 its hits went unnamed because the rule was "after the cast"). Each line vouches for one hit, the closest unused one before the hit; a shield's answer has no line and a tick's line comes behind it (a hit `TickFor` recognises keeps the line after it). The school and known-shield checks still apply. This only runs while lines are arriving (`linesFlow`) and the frame has exactly one cast.
- **Order in the frame** is the fallback when no hit in the cast's frame has a line (or no lines are arriving): a cast's hit comes after the cast, and a hit ahead of it is something else (the cape answered a blow just before a Claw landed).
- The periods and schools are in `PERIODIC_SPELLS` and `SHIELD_SPELLS` (first rank's ID, English name, ...), turned into name lookups by `SpellLists`: the English name always, the ID's name too on other languages. On an English client an ID whose name disagrees is ignored (Forever isn't quite Classic: its level 14 druid has Rake and Rip). The values are Classic's; only Claw, Rake, Rip and Thorns are confirmed on Forever.
- `/btf debug` writes each event as it arrives, and then, indented, what each hit was taken for: `  nameplate2 28: tick of Rake`.

Not handled yet: spells with a travel time (the cast isn't in the hit's frame), channels, procs, and ticks from Fireball or Pyroblast (they start when the spell lands, not at the cast). MSBT Continued does all of these by learning from `C_DamageMeter` totals after each fight.

Known gaps, all from the game: no spell for most hits; pet and player not told apart; a melee killing blow's event may never arrive (a unit that dies loses its tokens at once, and a swing's `UNIT_COMBAT` comes with its animation, after the death); no "Killing blow!" notice (it came from the readable `PARTY_KILL` line); hits on units with no token (no nameplate, not targeted) don't exist for addons.

What's from where: the `|Ky<n>|k` tokens and readable `UNIT_COMBAT` amounts for `player` are from the author's own `/btf copy` (2026-10-03). That `UNIT_COMBAT` fires for target, focus, nameplate, party and pet tokens with readable amounts, that a swing's event trails its log line by about 0.4–1.0s while ticks, procs and heals come in the same frame, and that dead units lose their tokens, are from the notes of two other Forever addons (MikScrollingBattleText Continued 1.60.01, Galdor Combat Text F-1.0.1), which describe their own in-game tests. Both are All Rights Reserved: **nothing of their code is used here**, only those facts about the game. MSBT Continued goes much further (damage meter events, `PLAYER_SWING`, learning procs, settling against `C_DamageMeter` totals when a fight ends); that's the place to look for ideas if the simple rules here aren't enough. **Confirmed in game with 1.1.0 (2026-10-03, solo cat druid)**: `UNIT_COMBAT` arrives for `nameplateN` and then `target` with readable amounts, schools and `CRITICAL`; the same hit under both names is dropped once; a cast and its hit share a frame. Not yet seen in game: groups (vouching), pets, heals on others, casters.

### The readable lines (when the game allows)

1. **`COMBAT_LOG_MESSAGE`** — the finished text of each Combat Log window line: `message, r, g, b, order`. Blizzard's secure `Blizzard_CombatLogProcessor` builds it (`GenerateMessage`) for Blizzard's own Combat Log window; addons can register it too. On screen a line reads

       Your Claw hit Bristleback Hunter Faust 50 Physical. (Critical)

   and underneath every part is a link:

       |Hunit:<guid>:<name>|hYour|h |Hspell:16827:0:SPELL_DAMAGE|h|cffffffffClaw|r|h |Haction:SPELL_DAMAGE|hhit|h |Hunit:<guid>:<name>|hBristleback Hunter Faust|h |cffffffff50|r |cffffffffPhysical|r. (Critical)

   - The **action link** names the event (`SWING_DAMAGE`, `SPELL_MISSED`, `SPELL_HEAL`, `PARTY_KILL`, ...). The **spell link** has the spell's ID. A swing has no spell: its name ("Melee") is a second action link. The **unit links** before and after the action are who did it and who it happened to; yours read "You" / "Your".
   - **Names are scrambled.** The other unit's name changes from line to line (a random mob name and surname). Never use it.
   - `order == Enum.CombatLogMessageOrder.Oldest` is history replayed when the window refills (the game does this at login too). Skip it.
2. **`UNIT_COMBAT`** for `player` — damage, heals, avoids and power gains that happen to you, with no spell name. Needs no setup. `WOUND` with no amount is an attack that did nothing (`flag` says `ABSORB`, `BLOCK` or `RESIST`, else it's a miss).

### What makes the lines flow

- The game only produces them **after the Combat Log window has been shown** once since login or `/reload` (confirmed in game, 2026-10-02). That's when Blizzard's UI loads its filter with `C_CombatLog.ApplyFilterSettings` (in `COMBATLOG`'s `OnShow`).
- **Never call `C_CombatLog.ApplyFilterSettings`.** It's Blizzard-only: from an addon it's blocked ("action only available to the Blizzard UI"), and the half-applied filter then makes Blizzard's processor throw `bad argument #1 to 'sub'` on every combat event until `/reload` (confirmed in game).
- When the window hides, Blizzard calls `C_CombatLog.SetFilteredEventsEnabled(false)` and the lines stop. **An addon may call `SetFilteredEventsEnabled(true)`**, and the lines come back (confirmed in game). `KeepLogFlowing` does that on the window's `OnHide`, after the Start click, and on a 3-second ticker.
- Blizzard also loads the filter when its Combat Log code loads at login, but that doesn't take (the call needs a real click), so a Combat Log window that's already showing at login isn't enough either.
- So the **Start button** is a secure button whose macro is `/click ChatFrame2Tab` then `/click <the tab you were on>` (or, if you're on the Combat Log tab, `/click ChatFrame1Tab` then `/click ChatFrame2Tab`): Blizzard's own code opens and closes the window, untainted. `ChatFrame2:Show()` from addon code would run that `OnShow` tainted and hit the blocked call. It's registered for `AnyUp` and `AnyDown` because the game runs a macro button on one or the other (the `ActionButtonUseKeyDown` setting).
- **The reminder** (`RemindStart`, since 1.2.4): `REMIND_AFTER` (10) seconds after `PLAYER_LOGIN` (so after a `/reload` too), one chat line if `started` isn't set, naming the key bound to `CLICK BattleTextForeverStart:LeftButton` if there is one. Off with `db.startReminder` ("Remind me to click Start") or when BattleText is off. The click itself can't be automated: see above.
- The button hides once the Combat Log window has been shown (its `OnShow`), or a live line has arrived (`started`). The macro can only be changed out of combat, so it's refreshed on each click, when a fight starts and when one ends.
- Not handled: a Combat Log dragged out into its own window (its tab's click doesn't show or hide it). Clicking a filter's quick button on that window would be the way (`Blizzard_CombatLog_QuickButton_OnClick` loads the filter), untested.
- `/btf off` puts the lines back the way the game has them (off unless its window is showing).

### What the lines contain

They follow the **filter selected on the Combat Log tab** (`Blizzard_CombatLog_Filter_Defaults` in `Blizzard_CombatLog.lua`):

- **"My actions"** (the default): you as the source, and only these events: swing, ranged, spell and periodic damage, heals and periodic heals, `DAMAGE_SPLIT`, `PARTY_KILL`, `UNIT_DESTROYED`, `UNIT_DISSIPATES`. **No misses, no power gains, and not your pet.** The player can add misses and the pet: with "My actions" selected on the tab, right-click the Combat Log tab → Settings → Message Types (four Misses boxes: melee, ranged, spells, periodic) and Message Sources (Pet under "Done By"; the one under "Done To" only adds hits on the pet) → Okay. Power gains have no box there; they come from `UNIT_COMBAT`.
- **"What happened to me?"**: you as the target (damage and heals, no misses).
- A filter the player makes themselves can have both.

`ShowCombat` takes whatever arrives:

- Your pet's lines are told apart by the source link's GUID (`UnitGUID("pet")`).
- What happens to you normally comes from `UNIT_COMBAT`. When the log starts delivering it (`NoteLogIncoming`, per kind: damage, miss, heal, power), `UNIT_COMBAT` is ignored for that kind so nothing is doubled; three `UNIT_COMBAT` events with nothing from the log switch it back (`LogCovers`).
- Your own heals on yourself arrive both ways. `UNIT_COMBAT` heals wait 0.25s and are dropped if the log had one (`lastSelfHeal`). Damage you do to yourself is left to `UNIT_COMBAT`.

### Reading the lines (`Parse.lua`)

- **Links first** (`ParseLinks`): the event comes from the action link, so nothing depends on the game's language. The number and the notes after it ("(Critical)", "(3 Blocked)", "(Dodged)") are matched against the game's own global strings (`TEXT_MODE_A_STRING_RESULT_*`, `ACTION_*_MISSED_*`).
- **Words as a fallback** (`ParseWords`), for a line with no links: finds "Your" and the action word (`ACTION_<EVENT>` strings). Someone else's line can't give a spell name this way (their scrambled name runs into it).
- A spell that fails says how in place of the action word ("Your Moonfire resisted X."); a swing says it in a note ("Your Melee missed X. (Dodged)").
- With the Combat Log's "Use Verbose Mode" the sentences are different and have no action link. Not supported.
- `/btf debug` records every live line exactly as the game sent it, marked "read", "skipped" or "hidden", each `UNIT_COMBAT` with its unit and (for other units) whether it was shown or why not, each cast of yours (`CAST <id> <name>`), and the time each arrived (the last 300). `/btf copy` shows them in an edit box (with `|` doubled so the links can be read), because chat can't be copied.

## WoW Forever rules the code must follow

- **Lua 5.1.**
- **Secret values.** Some API results are hidden from addons; comparing or doing math on one throws, **even `v == nil`**. Check `IsSecret(v)` first, or use `Num()` / `Str()`. A secret can still go to `SetText` / `SetFormattedText` (`Emit`'s `opts.secret`).
- **Taint.** Never assign one of Blizzard's globals or `SetScript` on Blizzard's frames (`HookScript` is fine).
- **Combat lockdown.** The Start button is secure: creating it, its attributes, and showing or hiding it wait for combat to end (`startPending`). The text areas and lines are ordinary frames and can change in combat.
- **Hardware events.** Nothing here sends chat or does protected actions. The Start button's macro runs from the player's click.

## Testing

Run from the repo root before every commit:

    lua5.1 tests/run.lua

- `tests/real_lines.lua` holds **real Combat Log lines**: about 160 of them, written by the game's own `CombatLogProcessor:GenerateMessage` for made-up events, each with what BattleText should read from it. `tests/strings_enus.lua` is the game's English text the addon reads. Both are made by `tests/tools/make_real_lines.lua`, which needs the game's exported interface code and its global strings (see the top of that file). Run it again when the game's Combat Log code changes. Don't write combat lines by hand in tests: the first version's tests passed on wording the game never produces.
- `tests/wowstub.lua` fakes the game. Where it matters it behaves like the game instead of just accepting calls: the Combat Log window loads its filter when shown, which only works from a real click (`ClickButton`) and never from addon code; lines only arrive once that has happened and they're turned on; a secure macro button fires on mouse down or up by the game setting. Things an addon must never do are recorded in `VIOLATIONS` (replacing a Blizzard global or a script on a Blizzard frame, registering the combat log events, calling `ApplyFilterSettings`), and the tests check it's empty.
- `tests/real_fight.txt`, `real_fight2.txt`, `real_fight3.txt` and `real_fight4.txt` are real `/btf copy` recordings (a cat druid: Claw, Rake, Rip, a cape that stings back; in the second Thorns too, two mobs at once and a stretch out of cat form; in the third mobs that are immune to bleeds and hit in two parts; the fourth opens with a Shred from stealth, whose hit comes ahead of its cast, and is also replayed with neither shield known). `replay()` in the tests plays one line by line at its own times (working out which mob the target is from the twin `nameplateN`/`target` lines) and the steps check every hit comes out named as it should: 56, 73, 60 and 15 of them. Add new recordings the same way when a class behaves differently.
- `tests/run_tests.lua` holds the scenarios: the `.toc` and keybindings, reading every real line three ways (with the game's text, without it, and as plain words), the Start button, your hits, adding up, crits, misses and heals, the Healing area, what happens to you both ways, hits read from other units when the lines are hidden (whose fight it is, one hit under several names, spell names from casts, vouching in a group), scrolling and spacing, notifications, pet lines, settings, combat lockdown, the options window (fonts and their files, the dropdown and its two fallbacks, the outlines, locking on close).
- The stub's other units: `STATE.who` maps unit names (`target`, `nameplate1`, `party1`) to units and `STATE.unit` says what each is (`enemy`, `guid`, `target`); `STATE.group` is being in a party. Mind that a `party1` in `STATE.who` counts as being in a group.
- The stub can't make `==` on a secret value throw (Lua won't call a metamethod there). Instead a test reads the source and fails on any comparison of `opts.secret`, a raw `amount`, `message` or `order`.
- `lua5.1 tests/run.lua` also runs `tests/reload_in_combat.lua` in a process of its own: logging in mid-fight with the Combat Log tab showing.

Visual check: `lua5.1 tests/render.lua out.json && python3 tests/render.py out.json outdir` draws a fight in progress, the unlocked areas with the Start button, and the options window as PNG images (an approximation of the game's look). Needs Python with Pillow.

Only testable in game:

- that `/click ChatFrame2Tab` from the Start button opens the tab without a "blocked" message, in and out of combat, and from the keybinding
- that the lines arrive with their links, and that the links' GUIDs are real (pet lines depend on it): `/btf debug`, then `/btf copy`
- whether `UNIT_COMBAT` amounts are readable or secret, and whether the log line or `UNIT_COMBAT` comes first (the same recording shows both)
- everything in `OnUnitHit`: that the event arrives for `target` and nameplate units, how far a hit trails its hidden line, whether a cast and its hit share a frame
- the options window's font dropdown (`WowStyle1DropdownTemplate`; a client without it gets a button that opens a menu)
- whether `order` is readable (if it's secret, replayed history can't be told from new lines)
- whether `floatingCombatTextCombatDamage` and `floatingCombatTextCombatHealing` exist on this client (they aren't in the game's Lua; a missing one is skipped)
- fonts, and how the text looks in motion

## Releasing

1. Make the change, run the tests, and add a new section at the top of `CHANGELOG.md` (e.g. `## 1.0.1`).
2. Commit and push to `main`. The **Tests** workflow must be green.
3. Create the tag in GitHub Desktop (History tab → right-click the commit → Create Tag → e.g. `v1.0.1` → Push origin). Tags containing `beta` or `alpha` upload as Beta/Alpha files.
4. The **Package and release** workflow runs the tests again, then uploads to CurseForge. Check the Actions tab for a green check and the CurseForge Files page (new files go through CurseForge review).

