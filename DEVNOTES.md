# BattleText Forever — developer notes

Scrolling combat text for **World of Warcraft: Forever** (interface 16001, client 1.60.x): your hits, heals and misses, the damage you take, and notifications.

- Author: `severd8`. License: MIT.
- CurseForge project ID: goes in the `.toc` as `X-Curse-Project-ID` once the project exists.
- Sister addons: TauntMaster Forever, ToppedOff Forever, Outfitter Forever. This project's setup mirrors ToppedOff's.
- Written from scratch. It's in the spirit of MikScrollingBattleText, but uses none of its code (MSBT is All Rights Reserved, and its combat log parser can't work on Forever).

## Files

- `BattleTextForever.toc` — `## Version: @project-version@` is filled in by the packager from the git tag. `BattleTextForeverDB` holds every setting (account-wide).
- `Parse.lua` — turns one Combat Log line into a table (`ns.Parser:Parse(line)`). Its only game calls are reading the game's text and your own GUID.
- `Core.lua` — settings, the three scroll areas and their animation (`Emit`, `Animate`), turning parsed lines and `UNIT_COMBAT` into text (`ShowCombat`, `OnUnitCombat`), notifications, the Start button, minimap button, slash commands, events.
- `Options.lua` — the options window.
- `Bindings.xml` — keybindings (loaded automatically): `CLICK BattleTextForeverStart:LeftButton` and `BATTLETEXTFOREVER_OPTIONS`.
- `Media/Icon.tga` — the logo mark (64×64 TGA). `art/` — logo sources (not shipped): `logo.svg`, `logo.png` (CurseForge and README), `icon.svg`.
- `tests/` — offline tests and the layout renderer (not shipped).
- `.github/` — `test.yml` (tests on every push), `release.yml` (on a `v*` tag: tests, package, upload to CurseForge; needs the `CF_API_KEY` secret), `add-to-project.yml` (new issues go to the GitHub project; needs `ADD_TO_PROJECT_PAT`), issue forms.

## Where the combat data comes from

Forever refuses `COMBAT_LOG_EVENT` and `COMBAT_LOG_EVENT_UNFILTERED` to addons. Two things are still allowed:

1. **`COMBAT_LOG_MESSAGE`** — the finished text of each Combat Log window line: `message, r, g, b, order`. Readable in combat. Blizzard's secure `Blizzard_CombatLogProcessor` builds it (`GenerateMessage`) for Blizzard's own Combat Log window; addons can register it too. On screen a line reads

       Your Claw hit Bristleback Hunter Faust 50 Physical. (Critical)

   and underneath every part is a link:

       |Hunit:<guid>:<name>|hYour|h |Hspell:16827:0:SPELL_DAMAGE|h|cffffffffClaw|r|h |Haction:SPELL_DAMAGE|hhit|h |Hunit:<guid>:<name>|hBristleback Hunter Faust|h |cffffffff50|r |cffffffffPhysical|r. (Critical)

   - The **action link** names the event (`SWING_DAMAGE`, `SPELL_MISSED`, `SPELL_HEAL`, `PARTY_KILL`, ...). The **spell link** has the spell's ID. A swing has no spell: its name ("Melee") is a second action link. The **unit links** before and after the action are who did it and who it happened to; yours read "You" / "Your".
   - **Names are scrambled.** The other unit's name changes from line to line (a random mob name and surname). Never use it.
   - `order == Enum.CombatLogMessageOrder.Oldest` is history replayed when the window refills (the game does this at login too). Skip it.
2. **`UNIT_COMBAT`** for `player` — `unit, action, flag, amount, schoolMask`. Damage, heals, avoids and power gains that happen to you, with no spell name. Needs no setup. `WOUND` with no amount is an attack that did nothing (`flag` says `ABSORB`, `BLOCK` or `RESIST`, else it's a miss).

### What makes the lines flow

- The game only produces them **after the Combat Log window has been shown** once since login or `/reload` (confirmed in game, 2026-10-02). That's when Blizzard's UI loads its filter with `C_CombatLog.ApplyFilterSettings` (in `COMBATLOG`'s `OnShow`).
- **Never call `C_CombatLog.ApplyFilterSettings`.** It's Blizzard-only: from an addon it's blocked ("action only available to the Blizzard UI"), and the half-applied filter then makes Blizzard's processor throw `bad argument #1 to 'sub'` on every combat event until `/reload` (confirmed in game).
- When the window hides, Blizzard calls `C_CombatLog.SetFilteredEventsEnabled(false)` and the lines stop. **An addon may call `SetFilteredEventsEnabled(true)`**, and the lines come back (confirmed in game). `KeepLogFlowing` does that on the window's `OnHide`, after the Start click, and on a 3-second ticker.
- Blizzard also loads the filter when its Combat Log code loads at login, but that doesn't take (the call needs a real click), so a Combat Log window that's already showing at login isn't enough either.
- So the **Start button** is a secure button whose macro is `/click ChatFrame2Tab` then `/click <the tab you were on>` (or, if you're on the Combat Log tab, `/click ChatFrame1Tab` then `/click ChatFrame2Tab`): Blizzard's own code opens and closes the window, untainted. `ChatFrame2:Show()` from addon code would run that `OnShow` tainted and hit the blocked call. It's registered for `AnyUp` and `AnyDown` because the game runs a macro button on one or the other (the `ActionButtonUseKeyDown` setting).
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
- `/btf debug` records every live line exactly as the game sent it, marked "read" or "skipped", along with each `UNIT_COMBAT`, and the time each arrived. `/btf copy` shows them in an edit box (with `|` doubled so the links can be read), because chat can't be copied.

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
- `tests/run_tests.lua` holds the scenarios: the `.toc` and keybindings, reading every real line three ways (with the game's text, without it, and as plain words), the Start button, your hits, adding up, crits, misses and heals, what happens to you both ways, scrolling and spacing, notifications, pet lines, settings, combat lockdown, the options window.
- The stub can't make `==` on a secret value throw (Lua won't call a metamethod there). Instead a test reads the source and fails on any comparison of `opts.secret`, a raw `amount`, `message` or `order`.
- `lua5.1 tests/run.lua` also runs `tests/reload_in_combat.lua` in a process of its own: logging in mid-fight with the Combat Log tab showing.

Visual check: `lua5.1 tests/render.lua out.json && python3 tests/render.py out.json outdir` draws a fight in progress, the unlocked areas with the Start button, and the options window as PNG images (an approximation of the game's look). Needs Python with Pillow.

Only testable in game:

- that `/click ChatFrame2Tab` from the Start button opens the tab without a "blocked" message, in and out of combat, and from the keybinding
- that the lines arrive with their links, and that the links' GUIDs are real (pet lines depend on it): `/btf debug`, then `/btf copy`
- whether `UNIT_COMBAT` amounts are readable or secret, and whether the log line or `UNIT_COMBAT` comes first (the same recording shows both)
- whether `order` is readable (if it's secret, replayed history can't be told from new lines)
- whether `floatingCombatTextCombatDamage` and `floatingCombatTextCombatHealing` exist on this client (they aren't in the game's Lua; a missing one is skipped)
- fonts, and how the text looks in motion

## Releasing

1. Make the change, run the tests, and add a new section at the top of `CHANGELOG.md` (e.g. `## 1.0.1`).
2. Commit and push to `main`. The **Tests** workflow must be green.
3. Create the tag in GitHub Desktop (History tab → right-click the commit → Create Tag → e.g. `v1.0.1` → Push origin). Tags containing `beta` or `alpha` upload as Beta/Alpha files.
4. The **Package and release** workflow runs the tests again, then uploads to CurseForge. Check the Actions tab for a green check and the CurseForge Files page (new files go through CurseForge review).

