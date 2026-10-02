# BattleText Forever — developer notes

Scrolling combat text for **World of Warcraft: Forever** (interface 16001, client 1.60.x): your hits, heals and misses, the damage you take, and notifications.

- Author: `severd8`. License: MIT.
- CurseForge project ID: goes in the `.toc` as `X-Curse-Project-ID` once the project exists.
- Sister addons: TauntMaster Forever, ToppedOff Forever, Outfitter Forever. This project's setup mirrors ToppedOff's.
- Written from scratch. It's in the spirit of MikScrollingBattleText, but uses none of its code (MSBT is All Rights Reserved, and its combat log parser can't work on Forever).

## Files

- `BattleTextForever.toc` — `## Version: @project-version@` is filled in by the packager from the git tag. `BattleTextForeverDB` holds every setting (account-wide).
- `Parse.lua` — turns one Combat Log line into a table (`ns.Parser:Parse(line)`). No game calls except reading the game's text.
- `Core.lua` — settings, the three scroll areas and their animation (`Emit`, `Animate`), turning parsed lines and `UNIT_COMBAT` into text (`ShowCombat`, `OnUnitCombat`), notifications, the Start button, minimap button, slash commands, events.
- `Options.lua` — the options window.
- `Bindings.xml` — keybindings (loaded automatically): `CLICK BattleTextForeverStart:LeftButton` and `BATTLETEXTFOREVER_OPTIONS`.
- `Media/Icon.tga` — the logo mark (64×64 TGA). `art/` — logo sources (not shipped): `logo.svg`, `logo.png` (CurseForge and README), `icon.svg`.
- `tests/` — offline tests and the layout renderer (not shipped).
- `.github/` — `test.yml` (tests on every push), `release.yml` (on a `v*` tag: tests, package, upload to CurseForge; needs the `CF_API_KEY` secret), `add-to-project.yml` (new issues go to the GitHub project; needs `ADD_TO_PROJECT_PAT`), issue forms.

## Where the combat data comes from

Forever refuses `COMBAT_LOG_EVENT` and `COMBAT_LOG_EVENT_UNFILTERED` to addons. Two things are still allowed, both confirmed in game (2026-10-02):

1. **`COMBAT_LOG_MESSAGE`** — the finished text of each Combat Log window line: `message, r, g, b, order`. Plain text, readable in combat, no links or color codes with the default settings:

       Your Claw hit Bristleback Hunter Faust 50 Physical. (Critical)
       Your Melee hit Bristleback Hunter Son 27 Physical.
       You killed Bristleback Thornweaver Fizzlesticks.

   Blizzard's secure `Blizzard_CombatLogProcessor` builds it with `"%s %s %s %s %s. %s"` (source, spell, action, dest, value, result) and fires it for Blizzard's insecure Combat Log UI; addons can register it too.
   - **Names are scrambled.** The other unit's name changes from line to line (a random mob name and surname). Never use it. "Your" / "You" are reliable.
   - `order == Enum.CombatLogMessageOrder.Oldest` is history being replayed when the window refills. Skip it.
2. **`UNIT_COMBAT`** for `player` — `unit, action, flag, amount, schoolMask`. Damage and heals you take, with no spell name. Needs no setup.

### What makes the lines flow

- The game only produces them **after the Combat Log window has been shown** once since login or `/reload`. That's when Blizzard's UI calls `C_CombatLog.ApplyFilterSettings` (in `COMBATLOG`'s `OnShow`).
- **Never call `C_CombatLog.ApplyFilterSettings`.** It's Blizzard-only: from an addon it's blocked ("action only available to the Blizzard UI"), and the half-applied filter then makes Blizzard's processor throw `bad argument #1 to 'sub'` on every combat event until `/reload`.
- When the window hides, Blizzard calls `C_CombatLog.SetFilteredEventsEnabled(false)` and the lines stop. **An addon may call `SetFilteredEventsEnabled(true)`**, and the lines come back. `KeepLogFlowing` does that on the window's `OnHide` and on a 3-second ticker.
- So the **Start button** is a secure button whose macro is `/click ChatFrame2Tab` then `/click <the tab you were on>`: Blizzard's own code opens and closes the window, untainted. `ChatFrame2:Show()` from addon code would run that `OnShow` tainted and hit the blocked call.
- The lines follow the **filter selected on the Combat Log tab**. "My actions" (default) = you as the source. "What happened to me?" = you as the target. A filter the player makes themselves has both.
- `ShowCombat` takes whatever arrives. If lines about things happening to you show up, `UNIT_COMBAT` is switched off for incoming (`logIncoming`) so nothing is doubled; three `UNIT_COMBAT` hits with no matching line switch it back.
- Your own heals on yourself arrive both ways. `UNIT_COMBAT` heals wait 0.25s and are dropped if the log had one (`lastSelfHeal`).

### Reading the lines (`Parse.lua`)

- The words come from the game's own global strings (`UNIT_YOU_SOURCE_POSSESSIVE`, `ACTION_SWING_DAMAGE`, `TEXT_MODE_A_STRING_RESULT_CRITICAL`, ...), so it follows the game's language. English fallbacks are built in for the tests.
- Only the Combat Log's normal wording is read. With its `fullText` ("verbose") setting the sentences are different and nothing parses.
- A line that doesn't parse is ignored; `/btf debug` prints those lines so they can be reported.
- Not available with the default filters: buffs and debuffs (the default filters hide them), other players' actions.

## WoW Forever rules the code must follow

- **Lua 5.1.**
- **Secret values.** Some API results are hidden from addons; comparing, doing math on or concatenating one throws. Check `IsSecret(v)` or use `Num()` / `Str()` first. A secret can still go to `SetText` / `SetFormattedText` (`Emit`'s `opts.secret`).
- **Taint.** Never assign one of Blizzard's globals or `SetScript` on Blizzard's frames (`HookScript` is fine). The tests load the addon with Blizzard's globals guarded.
- **Combat lockdown.** The Start button is secure: its attributes, and showing or hiding it, wait for combat to end. The text areas and lines are ordinary frames and can change in combat.
- **Hardware events.** Nothing here sends chat or does protected actions. The Start button's macro runs from the player's click.

## Testing

Run from the repo root before every commit:

    lua5.1 tests/run.lua

`tests/wowstub.lua` fakes the game (frames, timers with `Advance(seconds)`, the Combat Log window and tabs, secret values with `Secret(v)`); `tests/run_tests.lua` holds the scenarios: reading lines, the Start button, your hits, adding up, crits, misses and heals, incoming both ways, scrolling and spacing, notifications, pet lines, settings, combat lockdown, the options window. `ApplyFilterSettings` in the stub throws, so calling it fails the tests.

Visual check: `lua5.1 tests/render.lua out.json && python3 tests/render.py out.json outdir` draws a fight in progress, the unlocked areas with the Start button, and the options window as PNG images (an approximation of the game's look). Needs Python with Pillow.

Only testable in game: whether `/click ChatFrame2Tab` from the Start button opens the tab, the exact wording of every kind of line (misses, heals, periodic damage, pets), whether `UNIT_COMBAT` amounts are readable, fonts, and how the text looks in motion.

## Releasing

1. Make the change, run the tests, and add a new section at the top of `CHANGELOG.md` (e.g. `## 1.0.1`).
2. Commit and push to `main`. The **Tests** workflow must be green.
3. Create the tag in GitHub Desktop (History tab → right-click the commit → Create Tag → e.g. `v1.0.1` → Push origin). Tags containing `beta` or `alpha` upload as Beta/Alpha files.
4. The **Package and release** workflow runs the tests again, then uploads to CurseForge. Check the Actions tab for a green check and the CurseForge Files page (new files go through CurseForge review).

