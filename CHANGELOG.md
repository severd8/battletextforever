# Changelog

## 1.47.2

- **Rake's bleed ticks show as Rake again, for the whole session.** Druids saw only Rake's first hit, and every bleed tick after it as a plain white hit (or not at all). The game sends no combat line for Rake's ticks on WoW Forever, so BattleText names them by their 3-second beat. But it also watches for games that do send those lines, and switches the beat off when it sees them. Thorns' and the Spiked Shell Band's lines (and Thrill of Adventure's), landing at the same moment as a Rake tick, were mistaken for Rake's own lines, so after a couple of fights the beat was switched off until you logged out or reloaded. Lines that belong to your shields, gear or heals no longer count, and any tick that arrives on its beat with no line behind it switches the beat back on.

## 1.47.1

- **The miss words can be translated** (GitHub #47, thanks to ashnamuh). "Block", "Dodge", "Parry", "Miss", "Resist", "Immune" and the rest used to come only from the game's own words, so translators couldn't change them and a Korean player still saw one in English. They're now in the language files like everything else: a translation there is used first, then the game's own word, then the English.
- **Show sample uses your game's spell names.** The sample lines (Claw, Moonfire, Rejuvenation, Healing Touch) were always in English. Now they show in your game's language.
- Translators: "Thrill of Adventure" and the newer lines (icon picker, friendly names, /btf report) are in the language files waiting to be filled in.

## 1.47.0

- **Pick a spell's icon from a grid.** Clicking a spell's icon on the Spells tab now opens an icon picker, like Outfitter Forever's, so you don't have to type a spell's name or ID anymore. Choose from your spells' icons, the game's ability icons, item icons, or all of them. The search box finds icons by spell name or by part of the icon's name (like "sword"). Click an icon and press Use, or just double-click it. "Its own icon" (or a right-click on the spell's icon on the list) puts the usual icon back.

## 1.46.0

- **Deep Wounds ticks get their own name and icon** (GitHub #44, thanks to lich906). Warriors with the Deep Wounds talent saw its bleed ticks as plain white hits with their main hand weapon's icon. The game starts the bleed by itself when you crit, so BattleText never saw a "cast" for it. Now each of your melee crits starts Deep Wounds on that mob, and its ticks show as "Deep Wounds" with the talent's icon, and can be hidden with "DoTs and area spells" (Outgoing tab) or on the Spells tab like any other bleed.
- **Pick your own icon for any spell** (Spells tab). Each spell on your list now has its icon at the start of the row. Click it, type a spell's name or ID (or an icon's name from Wowhead, like ability_backstab) and press Enter: that spell shows with that icon from then on, in your lines, with Masque, in the Line order you set, and in the fight summary. Right-click puts its own icon back. Handy for any spell whose icon you don't like, or one that has none.

## 1.45.0

- **BattleText speaks Spanish** (GitHub #42, thanks to Javat00). The options window, on-screen words like "+Combate" and "disponible" (ready), chat messages and the fight summary now show in Spanish on a Spanish game. The same translation is used for Latin American Spanish too. A few lines added in 1.44.0 (the friendly names option on the Healing tab) still show in English until they're translated.
- **Accented letters in the options window's card titles.** Titles are written in capitals, and accented letters stayed small ("OPCIONES BáSICAS"). Now they're capitals too ("OPCIONES BÁSICAS"), in every language, Russian included.
- **Longer words fit better.** On the Text tab the lists move over to make room for a long label like "Contorno de críticos", and a long sound label (like "Sonido de golpe de gracia") goes on two lines instead of being cut off.

## 1.44.0

- **Your heals on players outside your group show now** (GitHub #29). Mouseover Penance (or Flash Heal, Holy Light and the like) on a stranger in the open world showed nothing. The game only tells addons about a heal on a player outside your group while that player has a nameplate, and friendly nameplates are off by default. Two changes fix it:
  - **Healers get names over friendly players.** For priests, paladins, druids and shamans, BattleText turns on the game's friendly player nameplates once, showing only their names (no health bars). Then those heals show like any other: "+312 Penance". If you already had friendly nameplates on, nothing changes. If you turn them off again yourself (Shift-V or the game's options), they stay off. Don't want it? Turn off "Names over friendly players" on the Healing tab and your nameplate settings go back to how they were.
  - **Without a nameplate, the game's own line shows.** If the player still has no nameplate (you turned them off, or they're too far away), the game's combat log line for your heal shows instead, like "Your Penance heals Bob for 312." It's the whole sentence because the game locks that line: addons can put it on screen but can't take the number out of it.
- **Hunters: your shots keep their names after the first fight** (GitHub #41). With your pet and hawks on the mob, every Auto Shot and Aimed Shot after the first fight showed as your pet's. BattleText mistook the pet's and hawks' many blows for a hidden damage-over-time effect of yours, and then refused to name any shot that landed in step with it. Your pet's and hawks' hits don't count for that anymore, so each shot gets its name again. A glancing blow is never taken for a shot either, since only melee attacks glance.

## 1.43.0

- **Left and Right alignment work the right way round.** Lines used to start from the middle of their window, so "Left" text sat in the right half of the box (and "Pop Left" popped on the right). Now Left lines up with the window's left edge and Right with its right edge. Your windows shift over once by half their width when you update, so your text stays exactly where it was on screen.
- **Move windows one pixel at a time.** While the text areas are unlocked, click a window to pick it (it gets a gold edge), then use the arrow keys to nudge it 1 pixel at a time, or 10 with Shift. Click it again to let go. Locking the windows or starting a fight lets go too, so your arrow keys are never stuck.
- **Sample text and the reset buttons are in the bottom bar.** "Show sample text", "Reset positions" and "Reset all" sit next to Close now, so you can test the look from any tab. Close looks different from them, since it only shuts the window.
- **No more small hitches when you loot.** Every looted item made BattleText re-read all your gear's tooltips. Now it only re-reads them when something you wear actually changes, like new gear or a new poison.
- **Consecration ticks keep their name with Retribution Aura on.** A Consecration tick that came without its combat line, often when the mob died, could show as a bare number. It's named Consecration now.
- **Hunters: your shots stop going to your pet** (GitHub #41). With your pet on the same mob, the pet's next blow after your shot often took the shot's name ("Auto Shot Dodge", "Aimed Shot Parry"), and then the real shot showed up as your pet's. Now only a hit that comes with your own combat line is named as your shot. If your pet and a hawk are both on the same mob, their hits still both show as your pet's, because the game doesn't say which one hit.
- **Wanding doesn't show your melee weapon** (GitHub #40). A wand miss or resist, or a swing the game counted along with your wand shot, could show your main hand weapon's icon. That doesn't happen anymore.

## 1.42.0

- **BattleText speaks German.** On a German game the options window, on-screen words, chat messages and the fight summary are now in German. (Thanks to ogogo1 for the whole translation.)
- **Longer words fit the options window.** Buttons now grow to fit their text, and the sound lists beside "Low health", "Low mana", "Crit sound" and "Kill sound" (and the color beside "Hide" on the Spells tab) move over when the label is longer, so German and other languages aren't cut off. The "Good to know" box grows with its text; if the General page runs out of room, the Share settings note moves into the Export and Import tooltips.
- Also in this version: Shield Specialization's mana (see 1.41.1 below).

## 1.41.1

- **Shield Specialization's mana shows now.** A Protection paladin's blocks give mana back, but on Forever the game sends no mana line for it at all, so it never showed. Now the block itself shows it: "+X Mana Shield Specialization", at most once every 3 seconds like the talent. If the game lets BattleText read your mana bar, X is what the bar actually went up (and nothing shows when your mana was full). If your mana is hidden, it shows 4% of your most mana, or "+4% Mana" when that's hidden too. Mana only shows with "Power gains" turned on (Incoming tab).

## 1.41.0

- **`/btf report`: send one report instead of many logs.** `/btf debug` now keeps a whole play session (it used to keep only the last fight or so). Play for a while, then type `/btf report`: it shows only the lines that look wrong, each kind counted with one example. That covers casts whose hit showed with no name, heals on you with no source, and hits that went unclaimed. Copy it into one bug report, and everything in it can be fixed together. `/btf copy` still shows everything. The recording ends when you log out or reload.

## 1.40.5

- **Ravage keeps its name and icon.** Opening from Prowl with Ravage could show its hit as a plain white hit with your auto attack icon. The game sends Ravage's hit just before the cast itself, and sometimes without the hidden line that used to tell them apart. Now when a cast has no hit after it, the hit right before it is the cast's.
- **Thrill of Adventure's first heal is caught sooner.** The first heal can come as early as one second after your killing blow, not two, so it's named from the first tick now.

## 1.40.4

- **Thrill of Adventure's heals are named.** After your killing blow, this talent heals you a little every 2 seconds, five times. Those heals used to show as a bare "+" with no name. Now they show as Thrill of Adventure with its icon. If you'd rather not see them, add "Thrill of Adventure" on the Spells tab and switch Hide on. (Turning off "Unnamed heals on you" no longer hides them, since they have a name now.)

## 1.40.3

- **Rake's bleed shows as Rake again.** On some games Rake's bleed ticks come without the hidden combat log line the addon used to recognise them, so after the first hit they showed up as plain white hits. Now a physical hit right on Rake's 3 second beat, up to its three ticks, is named Rake. On games that do send those lines, nothing changes.
- **The Spells tab row is tidier.** "Usual color" no longer runs under the Remove button.
- **Clearer `/btf debug`.** When a hit is hidden on the Spells tab, the log now says which spell it was, like "hidden on the Spells tab (Spiked Shell Band)". With Thorns and a Spiked Shell Band, each blow on you makes two Nature hits: Thorns' is shown, the ring's is hidden, and now the log says so.

## 1.40.2

- **Numbers over nameplates no longer pile on top of each other.** In a busy fight, a new number over a nameplate could land right on one still fading out, so "Claw 36" and "Dodge 58" turned into one blur. Now they line up in one column over the nameplate: the newest pops in at the bottom and pushes the others up, so every number stays readable. At most six show over one nameplate at a time; past that the oldest goes.

## 1.40.1

- **Glancing blows and seals in your game's language.** On a German (or other non-English) game, glancing blows said "(glancing)" and paladin seals kept their English names, like "+Seal of Command". Now glancing and crushing blows use the game's own word ("Streifschlag" in German), and seals show the name your game gives them ("Siegel des Befehls"), on the seal notice and on the seal's hits. (Thanks to ogogo1.)

## 1.40.0

- **Your hits over the enemy's nameplate.** On the Layout tab, "Your hits" (and "Your misses", if you like) can now be set to **Enemy nameplates**. Each number then pops up over the nameplate of the mob you hit and drifts up, instead of scrolling in the Outgoing area. A mob with no nameplate on screen still gets its numbers in Outgoing, so nothing is lost. Two new sliders under it, **Left and right** and **Up and down**, move the numbers to fit custom nameplates from other addons. Off unless you pick it. Turn on enemy nameplates in the game (V) to use it. (Thanks to xSky7 for the idea.)

## 1.39.0

- **Put your lines in your own order.** A new "Line order" box on the Outgoing tab sets how your hits and misses are written, with `{icon}`, `{name}` and `{damage}`. The usual is `{icon} {name} {damage}`; type `{icon} {damage} {name}` to get "[icon] 250 Fireball", or take a part out. The Healing tab has its own box for the heals you do. Reset puts it back. Works with hidden numbers too, and the Icons and Names switches still hide their parts. (Thanks to xSky7 for the idea.)

## 1.38.3

- **Masque icons are the right size again.** With Masque installed, the spell icons on your text came out much bigger than the text (and stayed big with BattleText's Masque group turned off). Masque sizes a skin once, when the icon is first set up, so it never shrank to your text size. Now the icons are scaled to your text size, skin and all. (Thanks to Oncewasperfect.)

## 1.38.2

- **Mouseover heals show everywhere, not just in dungeons.** Penance and other heals cast with a mouseover macro on a party member still weren't shown as yours in the open world: the name the game gives for the cast didn't match anyone in the group, so BattleText couldn't tell who it went to. Now a friend under your mouse is who it went to whenever the name doesn't tell, as long as your target isn't another friend. Names with a realm or in another case also match now. (Thanks again to k45tr0spam.)

## 1.38.1

- **Mouseover heals show in dungeons.** Heals cast with a mouseover macro (or a click on a party frame) on a party member, like Penance, weren't shown as yours in a dungeon, because the game hides everyone's names there and BattleText couldn't tell who the cast went to. Now a friend under your mouse is who it went to, as long as your target isn't another friend. (Thanks to k45tr0spam for the log.)

## 1.38.0

- **Masque skins BattleText's icons.** If you use Masque, the spell icons on your scrolling text now take your Masque skin, like your action bars. Pick the skin under Masque's options, group "BattleText Forever" (turn the group off there for plain icons). The icons stay where they were on each line. Without Masque nothing changes. (Thanks to the CurseForge player who asked.)

## 1.37.2

- **Korean is complete.** The last English line, the paladin seal option, is now in Korean, with Seal of Fury as 분노의 문장. (Thanks to Jaemok.)

## 1.37.1

- **Simplified Chinese is complete.** The last English line, the paladin seal option, is now in Chinese, with Seal of Fury as 愤怒圣印. (Thanks to Sanchez_3000.)

## 1.37.0

- **BattleText speaks Simplified Chinese.** On a Simplified Chinese game the options window, on-screen words, chat messages and the fight summary are now in Chinese. (Thanks to Sanchez_3000 for the translation.)
- **Clearer Korean combat text.** On a Korean game, entering and leaving a fight now shows "전투 시작" and "전투 종료" (combat start and combat end) instead of "+전투" and "-전투". (Thanks to Jaemok.)

## 1.36.0

- **BattleText speaks Korean.** On a Korean game the options window, on-screen words, chat messages and the fight summary are now in Korean. (Thanks to Jaemok for the whole translation.)
- **Money you loot is short and coloured.** With "Money" turned on (Notifications tab), looted money now shows as "+1g 25s 30c" in gold, silver and copper colours, instead of the game's whole sentence. It reads the game's own words for gold, silver and copper, so it works in every language. Money still starts off. (Thanks to Jaemok.)

## 1.35.0

- **Russian names show in every font you can pick.** Most of BattleText's fonts have no Russian letters, so on a Russian game spell and player names in those fonts came out blank. Now a Russian game only lists the fonts that have Russian letters: Default, Friz Quadrata, Arial Narrow, Morpheus, Skurri, Fira Sans, Lato, Press Start 2P, PT Sans Narrow, Russo One and Ubuntu. Friz Quadrata, Morpheus and Skurri now use the game's own Russian versions. If you'd already picked a font without Russian letters, your text uses Default until you choose another. On Korean and Chinese games, where none of the fonts have the letters, Default is used. Fonts shared by your other addons are always listed. (Thanks to Barmy for asking.)
- **Starshards is named.** A Night Elf priest's Starshards showed as plain numbers. Its damage now shows "Starshards" with its icon. (Thanks to user_mh4740vmz90ckp8o.)
- **Seal of Fury is named.** Forever's new paladin seal adds Holy damage to your swings, and that damage showed as plain numbers. It now shows the seal's name and icon, like Seal of Righteousness and Seal of Command.
- **Shield Specialization's mana is named.** Paladins with Shield Specialization get mana back when they block. That mana now shows as "+X Mana Shield Specialization" with its icon, instead of plain "+X Mana". Mana only shows with "Power gains" turned on (Incoming tab), which starts off. (Thanks to user_5rhd3cwqzdc4rhle for asking.)

## 1.34.2

- **Heroic Strike is named every time.** The game sends Heroic Strike as two hits: an empty one, then the real attack. Usually they arrive together, but sometimes the real attack comes a split second later. When it did, BattleText showed it as a plain white swing and put the Heroic Strike name on the empty part. Now it waits that split second, names the real attack, and leaves the empty part out. Maul, Cleave and Raptor Strike work the same way.

## 1.34.1

- **No more "Heroic Strike 0".** When an attack of yours did no damage, BattleText could show it as a hit for 0 instead of a miss. The game hides the number in many places, so BattleText couldn't tell it was a 0 and showed it anyway. Now a hidden 0 is simply left out, and a 0 the game does let BattleText read shows as Miss, Absorb, Block or Resist, whichever it was. Your real hits look the same as before.

## 1.34.0

- **See which school a hit on you is.** Magic damage you take now shows in its school's color with the school's name after the number, like "-120 Shadow" in purple or "-80 Fire" in orange. It uses the same colors as your own spells. Now you can tell when a mob hits with shadow or fire, and when to use Shadow Ward, Fire Ward or a resistance potion. Physical hits stay red. This works even when the game hides the number. If the spell's name already says the school ("Shadow Bolt"), the word isn't repeated. You can turn it off with "Damage schools" on the Incoming tab. (Thanks to Myleo-indark for the idea, issue #33.)
- **"Concussion Blow ready" shows again.** In a fight the game sometimes hides both how long a cooldown is and whether it's only the global cooldown. BattleText then gave up on it, so some cooldowns (like Concussion Blow) never got their "ready" message. Now it keeps watching them. Anything that ends within 8 seconds still isn't announced, so the global cooldown doesn't spam you. (Thanks to ashnamuh for the report and the fix idea, issue #34.)

## 1.33.1

- **The last Rip ticks are named too.** Two cases still slipped through 1.32.2. A Rip tick that landed between one of your swings and that swing's own hit was taken for the swing, and a Rip tick in the same moment as a Rake tick was dropped along with it. Rip's beat now gets its tick first, so both show as Rip, and the swing still gets its own hit. (Thanks again to Pansiere for the debug logs, issue #30.)

## 1.33.0

- **Behind the scenes: the addon's code is now in eight files instead of one.** Nothing changes in game. The main file had grown so big it was close to a limit Lua puts on one file, so it's now split by job (the text on screen, hits on you, which hits are yours, alerts, settings and so on). This makes future fixes safer. If anything acts differently after this update, please report it.

## 1.32.2

- **Lighter in groups and raids.** In a group, the game reports every heal on every group member, and every hit on every mob around you, often several times over under different names. BattleText now drops other people's heals straight away when no heal of yours could be going (no healing spell cast in the last 45 seconds), and drops repeated copies of the same hit before checking anything else about it. Your numbers don't change, it just does less work in big fights.
- **Your hits no longer go missing if the game's combat lines stop.** If something turned the combat lines off after BattleText had started them (another addon, or a Combat Log filter change), your bleeds, DoT ticks, spells that land later and procs could disappear in a group without any warning. BattleText now notices when you've been fighting for a while with no lines at all. It turns them back on, and if that doesn't work, the Start BattleText button comes back after the fight.
- **Hits on you aren't swallowed by an old combat line.** If the Combat Log ever delivered a readable line about you (say you tried a different filter), the next few hits on you could go unshown, even minutes later. That now only applies for a few seconds after such a line.
- **Smaller fixes:** mage proc alerts are only looked for on mages, Pop text that has to find a free spot no longer creates hundreds of throwaway objects each time, the scrolling text only updates what actually changed on each frame, and the "Low mana" sign doesn't reset its font on every mana tick. In other languages, spell names the game hadn't loaded yet at login are picked up when your first fight starts.

## 1.32.1

- **Rip's ticks are named again.** The game sends BattleText no combat line for Rip's bleed ticks (it does for Rake's), so while other lines of yours were arriving, most of Rip's ticks were dropped or shown without a name. Now a physical hit that lands right on Rip's 2-second beat, while Rip is on the mob, counts as its tick, up to the six ticks it has. A white hit your swing accounts for, or a glancing blow, is still a swing. (Thanks to Pansiere on GitHub for the debug log and the fix idea, issue #30.)

## 1.32.0

- **Heals cast with mouseover macros now show.** BattleText assumed a heal went to your target (or to you, with no friend targeted). Healers who heal with mouseover macros or by clicking party frames, while targeting the boss or nothing, lost a lot of their heals: Renew's ticks, Penance and other heals on party members never showed, and Renew could even be taken as one on yourself. BattleText now asks the game who each cast is going to as you press the key, so a heal on the party member under your mouse counts as yours, whatever you have targeted.
- **Prayer of Mending is named.** Its heals come later, as the prayer jumps from one party member to the next, with no cast to go by, so BattleText dropped them. They now show as Prayer of Mending, on the friend you put it on and then on whoever it jumps to.
- (Thanks to the priest on CurseForge who reported it.)

## 1.31.0

- **Smarter warrior alerts.** "Revenge!" now only shows in Defensive Stance, so Arms and Fury warriors don't get it on every parry. "Overpower!" still shows in any stance (many warriors switch to Battle Stance for it), but not while Overpower is on its cooldown, when the button can't be used anyway. And any ability alert can now be turned off on its own: add the ability on the Spells tab and hide it (a color you give it there is used for its alert too). (Thanks to Quarnok for the ideas.)
- **Crits can have a font of their own.** On the Text tab, "Crit font" picks a different font for critical hits and heals, so they stand out from the stream of numbers. It starts as "Same as other lines", so nothing changes until you pick one. (Thanks to beefsupreme3954 for the idea.)
- **BattleText can now be translated.** Every word BattleText writes itself (the options window, the text on screen like "Killing blow!" and "Low mana!", the fight summary, chat messages and tooltips) can now be shown in your game's language. Spell, item and player names were already in your language, since they come from the game. Korean is the first language being worked on (thanks to the Korean player on CurseForge who offered to translate). Until a translation is in, everything shows in English as before.
- **Want BattleText in your language?** There's a file ready for every language the game comes in: German, French, Spanish, Italian, Portuguese, Russian, Korean and Chinese. Open yours in the addon's `Locales` folder (like `Locales/deDE.lua` for German, or on GitHub), write your text after each `=`, and send it on CurseForge or GitHub. Lines you leave empty stay in English, so a half-done translation works too.
- **Cursed Murloc Eye's 2 damage is hidden next to your spells and abilities too.** With "Hide hits below" set above 2, the Eye's extra hit was already hidden next to your auto attacks, but some still showed when it came with a spell or ability. The game sometimes sends the Eye's hit a moment before or after the hit that set it off, and BattleText only waited for an auto attack to match it with. It now also matches it to your spell and ability hits. Warlocks and priests are the exception: their own Shadow spells could look the same, so for them it plays safe and still shows a hit it isn't sure about. (Thanks to OdysseaLUL for the report.)
- **Multi-Shot and Aimed Shot are named.** BattleText didn't know these hunter shots. They take a moment to fly to the mob, so their hits came in with no name and were treated as auto attacks. With "Auto attacks" turned off they didn't show at all. They're now named like Arcane Shot, and they show whatever "Auto attacks" is set to. (Thanks to feuerbanane for the report.)
- **"Power gains" off now hides the game's "+mana" too.** With "Hide the game's own numbers" on and "Power gains" off (Incoming tab), the game's own mana, rage and energy gains over your character are turned off as well, so no "+mana" text shows anywhere. With "Power gains" on, the game's own stay, because some mana gains never reach BattleText. (Thanks to feuerbanane.)

## 1.30.0

- **Frostfire Bolt is named.** BattleText didn't know Frostfire Bolt, so its hit and the burn it leaves showed as bare numbers with no name or icon. It's now known as a spell that lands a moment after the cast, and its burn ticks are named too.
- **Frostfire Bolt's opener and overkill show.** Because BattleText didn't know the spell, a Frostfire Bolt that opened the pull (on a mob not after you yet) or killed the mob was taken as someone else's and left out. It now counts as yours while it's on its way, like Fireball and Frostbolt. (Thanks to xnmd for the report.)
- **Proc alerts for Missile Barrage and Revelation.** With "Ability alerts" on, "Missile Barrage!", "Revelation!", "Hot Streak!", "Fingers of Frost!", "Brain Freeze!" and "Clearcasting!" now show in Notifications when the buff comes up. One catch: in a fight the game hides most of your buffs from addons, so a proc only shows if the game lets BattleText see it (or lights it up on your action bars). If one never shows for you, a `/btf debug` log helps.
- **No more error with the low mana sign.** When the game hides your mana and you got low, the "Low mana" sign threw a "Font not set" error, over and over. It now shows as it should.

## 1.29.2

- **Penance heals are named.** A priest's Penance heals your target a moment after you cast it, and keeps healing while you channel. BattleText didn't know Penance, so in a group its heals showed as "not yours" and never appeared. It now knows Penance as a channel on your target: its heals on a friend, its damage on an enemy, and its heals on you when you cast it on yourself are all named "Penance".
- **Renew ticks on party members show every time.** In a group, BattleText needs a line from your combat log to know a heal is yours. Sometimes a Renew tick's line came a moment after the heal, or a party member's hit landing at the same moment took the line first, and the tick was left out. Your heal ticks now get their line first, and wait a moment for one that comes late. (Thanks to k45tr0spam for the detailed report.)

## 1.29.1

- **Windfury's last hit shows.** When Windfury went off with Stormstrike and a swing together, its second extra hit sometimes came almost a second after your swing's hit. BattleText stopped waiting for Windfury hits a little before that, so the hit was left out. It now waits a little longer. (Thanks again to agalakov-AI for the log.)

## 1.29.0

- **Gear is understood in every game language.** BattleText learns what your gear does from its tooltip, and until now it could only read English tooltips. On a Russian, German, French or other client it never knew about a cloak or ring that hits back (like Sporid Cape), a weapon's "Chance on hit", or a rogue's poisons, so their hits showed as bare numbers or got the wrong name. Now it reads the "Equip:" and "Chance on hit:" lines in your game's language, takes the numbers from them, and knows the damage type from its name in your language. Poisons are matched by their spell, so their names work in any language too.
- **New `/btf gear` command.** It lists every item you're wearing and what BattleText made of each of its lines. If one of your items isn't named right, type `/btf gear` out of combat, then `/btf copy`, and paste it into a bug report. That shows exactly what your game says, so the item can be fixed.

## 1.28.4

- **Lightning Shield no longer takes credit for your gear's hits.** With Lightning Shield up, some Nature hits that weren't from it got its name. Thorncursed Grips also deal 2 Nature damage to you with each swing, and BattleText took that as a mob hitting you, so the Grips' own hit on the mob in that moment looked like your shield answering. Now the Grips' hit on you doesn't count as a blow, and it tells BattleText the matching hit on the mob is the Grips' (so "Hide hits below" hides it again, even during Windfury). Each damage shield also answers a blow only once now: a second Nature hit after the same blow (like Sporid Cape's, which BattleText can't read on a non-English game) shows as a plain hit instead of a second Lightning Shield. (Thanks to agalakov-AI for the debug log.)

## 1.28.3

- **Thorns and gear that hits back are named every time.** BattleText names your damage shields by matching their hits to a mob's blow on you. With Thorns and a ring like the Spiked Shell Band, their hits sometimes came a little too long after the blow, or the blow showed up as a miss. Then both showed as bare green numbers (a 9 and a 2) with no name or icon. BattleText now waits a bit longer after a blow. And when one Nature hit for each of your Nature shields lands on the mob at the same moment, it knows those are your shields even if no blow shows up. They come up as "Thorns 9" and "Spiked Shell Band 2" (or stay hidden if you hid the ring on the Spells tab).

## 1.28.2

- **Windfury hits show again.** The extra hits from Windfury Weapon came with nothing for BattleText to tell they were yours, so they were left out, and only showed now and then when one killed the mob. Extra attacks that land right after your own swing or Stormstrike now show like your other hits. This also covers other extra attacks, like Hand of Justice and Sword Specialization. In a group, BattleText still checks your own combat lines first, so a party member's swing right after yours isn't shown as yours. (Thanks to ehrinpitts for the debug log.)

## 1.28.1

- **Cursed Murloc Eye and Thorncursed Grips are hidden on non-English game clients too.** BattleText recognised these items by reading the English text on their tooltips, so on a Russian (or any other non-English) client it never knew you had them on, and their 2 damage kept showing whatever "Hide hits below" was set to. It now knows them by the item itself, in any language, and names them with your game's own item name.
- **Stormstrike with the Eye on no longer shows two 2s.** When two hits from the Eye land together (a Stormstrike and your swing), BattleText played it safe and showed both, in case one was a real Shadow spell. Classes with no Shadow spells (shamans, warriors, rogues and more) can't be casting one, so both are now taken for the Eye and hidden. Warlocks, priests and Undead still see both, since one could be a real Shadow spell. (Thanks to agalakov-AI for the debug log.)

## 1.28.0

- **The low mana warning works when the game hides your mana.** For some players the game won't let addons see their mana (we found this while fixing Life Tap), so "Low mana!" could never go off for them. BattleText still can't see the number, but the game lets it hand over your line and show the answer. So when your mana is hidden and you're under your "Low mana at" line, a steady blue "Low mana" now shows just above your notifications, and goes away once you're back above it. There's no sound in this case, since BattleText can't tell the moment you cross the line. If your mana can be read, nothing changes: "Low mana!" scrolls by with its sound as before. Turn it on with "Low mana" in the Warnings card on the Incoming tab.

## 1.27.2

- **Life Tap's mana really shows now.** It turns out the game hides your mana from addons (1.27.1's debug said "mana hidden" on every cast), so BattleText could never see it go up. It now takes the numbers from Life Tap's own description ("Converts 315 health into 315 mana") and shows "+315 Mana Life Tap" right as you cast, along with the health it cost. Remember to turn on "Power gains" on the Incoming tab. If your mana is already full you'll still see the mana line, since BattleText can't tell. (Thanks again to mtfic for testing.)

## 1.27.1

- **Life Tap's mana shows now.** In 1.27.0 the health part showed but the mana never did: the mana reaches your bar a little before or after the cast, and BattleText only waited a split second for it. It now catches the mana from just before the cast up to a second and a half after, and also reads the mana bar itself while it waits, in case the game doesn't say the mana changed. With /btf debug on, it also writes down your mana around each Life Tap, so if it still goes missing a debug log will show why. (Thanks to mtfic for testing.)

## 1.27.0

- **Life Tap shows what it costs and what it gives.** When a warlock casts Life Tap, you now see the health it took on the incoming side ("-200 Life Tap") and the mana it gave as a power gain ("+200 Mana Life Tap"), both with its icon. The game doesn't report Life Tap in the combat log at all, so BattleText reads the mana off your mana bar as you cast it. The game hides your health from addons, so the health shown is the same as the mana gained (Life Tap trades them one for one). If your mana was already full or close to it, the health comes from the spell's own description instead. The mana line follows the "Power gains" switch on the Incoming tab, which starts off, so turn it on to see it. (Thanks to mtfic for asking.)

## 1.26.1

- **Gear that hits back is named beside Thorns.** With Thorns up and a ring like the Spiked Shell Band ("When struck in combat, inflicts 2 Nature damage to the attacker"), every blow on you is answered twice, both in Nature. BattleText named only one of them Thorns and showed the ring's 2 as a bare green number. Now each blow names both: "Thorns 9" and "Spiked Shell Band 2", with the ring's icon. This works for any shield buff (Thorns, Lightning Shield, Retribution Aura, Fire Shield) together with any gear that stings back.
- **1.25.1's "resisted" Thorns is undone.** That 2 was never a resisted Thorns, it was the ring, so it no longer shows as "Thorns 2 (7 resisted)".

## 1.26.0

- **Your pet's hits show its name.** Instead of "(Pet) 21" you now get "(Fluffy) 21", with whatever you named your pet. In places where the game hides names (some dungeons), BattleText keeps the name it last saw, and falls back to "(Pet)" if it never saw one.
- **Your hawk's damage is shown on its own.** Summon Hawk's dive now shows as "Summon Hawk" with its icon, and the hawk's hits after that are marked "(Hawk)" for as long as it's out (18 seconds). The game doesn't say who landed a hit, so when your pet and your hawk are both on the same mob, those hits show your pet's name. The Pet switch on the Outgoing tab turns the hawk's hits off too. (Thanks to Tinter for asking.)

## 1.25.1

- **A partly resisted Thorns is still called Thorns.** When a mob shrugged off part of your Thorns (elementals and other mobs that resist Nature), its hit came in smaller than usual, say a 2 instead of a 9, and showed as a bare green number with no name. It now shows as "Thorns 2 (7 resisted)", with the icon: what landed, and how much the mob shrugged off. The same goes for Lightning Shield, Retribution Aura and Fire Shield.

## 1.25.0

- **Low health and low mana warnings.** BattleText can now warn you with a big "Low health!" or "Low mana!" and a sound when you drop low, so you notice before it's too late. Turn them on in the options, Incoming tab, under Warnings, and pick a sound for each. Low health warns at 35% health: the game hides your health from addons, so BattleText goes by the game's own red screen edges, which come up at 35% (keep "flash screen at low health" on in the game's options). Low mana warns at 35% to start with, and you can move that line. Each warns once as you drop below, and again only after you've recovered, so a bit of regen won't set it off over and over. (Thanks to rroquette for asking.)

## 1.24.5

- **Arcane Wrath shows its name and icon.** BattleText didn't know Arcane Wrath, so its hit showed as a plain number with no name. It's now known as an Arcane spell that lands a moment after the cast, like Fireball and Frostbolt, so its hit is named after it.
- **A spell that opens the pull or kills the mob still shows.** When a spell of yours was on its way to a mob that wasn't after you yet (casting to open a pull), or the mob died from it (the overkill hit), BattleText thought it wasn't your fight and dropped the hit. A hit of the right school on the mob your spell was cast at now counts as yours while the spell can still be on its way. This helps Fireball, Frostbolt, Shadow Bolt, Wrath and the other spells that fly too. (Thanks to xnmd for the report.)

## 1.24.4

- **"Hide hits below" really hides Cursed Murloc Eye's 2 damage now.** Since BattleText started turning the combat lines on by itself (1.23.0), the Eye's hit usually arrives a moment before your swing's hit, not with it. BattleText only looked for your swing alongside or just before the Eye's hit, so it never knew it was the Eye's and always showed it. Now it waits a moment for your swing, then names it after the trinket and hides it if it's below your setting.
- **Thorncursed Grips are known too.** Their 2 Nature damage on every melee swing is named after the gloves and hidden by "Hide hits below" the same way. Only their hit on the mob is hidden this way; the 2 they deal to you still shows on the incoming side. (Thanks to agalakov-AI for the report.)

## 1.24.3

- **No more false "couldn't open the Combat Log tab" warning.** BattleText said this after you clicked Start BattleText even with the normal chat window and its Combat Log tab right there. It now only says it when the Combat Log tab really can't be seen (a chat addon like Chattynator hiding it). BattleText also notices the Combat Log window opening even if the game hasn't fully set it up yet.
- **The Start button stops showing up for no reason.** It came up after any fight that had no combat lines, including fights where you never attacked (a mob hit you and you ran, or someone else killed it). The game only writes lines for what you do, so those fights don't mean anything is wrong. Now the button only shows after a fight where you swung or cast and still no line came.

## 1.24.2

- **Poisons are picked up as soon as you put them on.** In 1.24.1 BattleText only noticed a new poison after you swapped weapons or reloaded. It now reads your weapons a moment after you apply or refresh a poison, and it reads the poison line even with the game's coloring on it. Poison hits also show the poison's icon.
- **Instant and Deadly Poison together are told apart better.** With Deadly Poison on, only a poison hit that lands right with your swing counts as Instant. Everything else is a Deadly tick, including its very first one. A poison also wins over a weapon's own Nature "Chance on hit" (like Electrocutioner Leg), since the poison goes off far more often. (Thanks again to TheFarbod for testing all of this.)
- **Serpent Sting shows its name and icon.** Serpent Sting is a shot, so it lands a moment after you fire it, and its ticks come that much later than BattleText expected. It never matched them, so they showed as plain numbers. Its ticks are now timed from when the shot lands. (Thanks to user_mh4740vmz90ckp8o for the report.)

## 1.24.1

- **Rogue poisons get their name and icon.** Instant Poison, Wound Poison and Deadly Poison hits used to show up as plain numbers with no name. BattleText reads the poison off your weapon (any rank), so poison hits now show as "Instant Poison 110", and they count under their own name in `/btf last`. Deadly Poison's ticks are named too, even the ones that land after you stop swinging. If you have Instant on one hand and Deadly on the other, a poison hit that lands with your swing is Instant, and the steady 3-second ticks are Deadly. Deadly Poison's ticks count as DoT ticks, so "DoT ticks" on the Outgoing tab and the tick window apply to them. (Thanks to TheFarbod for the report and the fix ideas.)

## 1.24.0

- **Holy Shock heals show again.** Since BattleText started by itself in 1.23.0, most Holy Shock heals went missing. On Forever, Holy Shock's heal is cast by the game as a second "Holy Shock" right after yours, and BattleText saw two spells at once and couldn't tell which one healed, so it left the heal out. It now knows those are the same Holy Shock. A heal that lands a moment after you cast it on a friend is still counted as yours, and Holy Shock on yourself shows its name too. (Thanks to envenomnesea for the report.)
- **Light's Vigil heals get their name and icon.** When your Holy Shock sets off Light's Vigil, the heals on that player and their party (you too, if you're in it) now show as Light's Vigil with its icon, and count toward it in the fight summary. The first heal on the player you Holy Shocked is still shown as Holy Shock.

## 1.23.0

- **BattleText starts by itself.** No more clicking Start BattleText every time you log in. BattleText now turns on the game's combat lines as soon as you log in, so bleed ticks get their names and other people's hits are left out from your first fight. (Thanks to Dzib for asking, and for the nudge to look again.)
- **The Start button only shows when it's needed.** If a fight ends and no combat line came (a chat addon that hides the Combat Log can do that), the button shows up then, with one line in chat about it. Click it once, as before.

## 1.22.0

- **Start BattleText without clicking.** The game only lets the Combat Log get going from a real click or key press, so BattleText can't press Start for you when you log in. What you can do now: put `/click BattleTextForeverStart` at the top of a macro you press anyway, like your first attack. The first time you press it after logging in, BattleText starts; after that the line does nothing, so your chat tabs stay put. It works whether or not "cast on key down" is on. You can also still bind a key to Start BattleText. (Thanks to Dzib for asking.)

## 1.21.7

- **Shadow Bolt keeps its name when another Shadow hit lands right as you cast it.** Warlocks have a Shadow damage that ticks on its own about every 2.5 seconds (BattleText has no name for it). When one of those ticks landed in the exact moment a Shadow Bolt finished casting, BattleText took the tick for the bolt, and the real bolt landed a moment later with no name. A spell that flies now never takes a hit that's on that tick's beat, so the bolt gets its name when it actually lands. (Thanks to Ethn91081 for the report and the debug log.)

## 1.21.6

- **"Shoot ready" no longer pops up after every wand shot.** Shoot, Auto Shot and Throw fire again on their own, so their "cooldown" is just your weapon's speed. The game hides how long it is in a fight, so BattleText announced it every time. Spells that repeat on their own are never announced now, and a cooldown the game hides is only announced if it really lasted 8 seconds or more. No need to hide Shoot on the Spells tab any more. (Thanks to ModsAndAddonsAreGreat and Quarnok for the report.)
- **Wand hits show every time again.** With the game's combat lines on, 1.21.4 only counted a hit as yours when its line arrived right with it. A wand hit's line can come a moment later, so some wand hits went missing. Your shot now vouches for its own hit, and a party member's wand hits still don't show as yours.
- **A hunter's pet no longer shows your melee weapon's icon.** While you're shooting, a physical hit that isn't your Auto Shot isn't your melee weapon's: with your pet on that mob it shows as "(Pet)" (and "Pet" off on the Outgoing tab hides it), otherwise it gets the plain Attack icon. In melee, your swings show your weapon as before. (Thanks to Tinter for the report.)
- **Cursed Murloc Eye's 2 Shadow damage is named, and "Hide hits below" hides it.** The game hides that number in a fight, and hidden numbers always showed. BattleText now knows gear that adds the same amount to every hit (2, or 8 on Murlocs), names it after the trinket, and hides it when it's below your setting. (Thanks to OdysseaLUL for the report.)

## 1.21.5

- **`/btf copy` works again after a fight with hidden amounts.** When a hit waited for Touch of the Grave (or a seal or damage shield) and nothing came, its line in the debug log held the game's hidden number, and `/btf copy` stopped with a Lua error instead of opening. Those lines now say "(hidden amount)" like the rest, and if a hidden value ever sneaks into the log again, the copy window shows a short note for that line and opens anyway. (Thanks to Ethn91081 for the report.)

## 1.21.4

- **Your party's wand hits and white hits no longer show as yours.** In a group, BattleText uses your combat log lines to tell your hits from everyone else's. Lines from things that don't deal damage (Sunder Armor, Shield Block) and from swings it had already counted were left over, and a party member's wand shot or auto attack landing just after one was taken for yours. Now a line only counts for the hit it arrives with, and your white hits are counted by your own swings. Your own hits, spells, ticks and your pet's hits still show as before. (Thanks to dries9300 for the report.)

## 1.21.3

- **Off-hand swings show your off-hand weapon's icon.** With a sword in your main hand and a dagger in your off hand, every white hit showed the sword, off-hand hits included. The game's swing timer says which hand each swing came from, so now main-hand hits show the main-hand weapon and off-hand hits show the off-hand weapon, dodges and parries too. When BattleText can't match a hit to a swing, it shows the plain Attack icon instead of guessing. (Thanks to skaine78 for the report.)

## 1.21.2

- **Touch of the Grave shows its name.** The Undead racial's drain and the heal it gives you showed as a plain number and an unnamed heal. BattleText now spots the two landing together, and shows both as Touch of the Grave, with its icon, for every class Undead can play. A Shadow hit with no heal beside it still shows as before.

## 1.21.1

- **Shadow Bolt keeps its name next to your other Shadow damage.** With Bane of Agony, Corruption and Demonic Brand all on a mob, a tick of Demonic Brand could land while your Shadow Bolt was still flying. BattleText took that tick for the bolt, and then the real bolt showed with no name. Damage that keeps ticking on a steady beat is now recognised as a tick, so the bolt's name goes to the bolt when it lands.

## 1.21.0

- **New: "Kick ready".** When a spell of yours comes off its cooldown, a line in Notifications says so, with its icon. Only cooldowns of 8 seconds or more are shown (up to 10 minutes), so your everyday attacks don't spam it. It works in fights too. Turn it off with "Cooldowns ready" on the Notifications tab, or hide one spell on the Spells tab.
- **New: interrupt alerts.** "Interrupted Frostbolt" when you or your pet stop an enemy's cast with Kick, Pummel, Shield Bash, Counterspell, Earth Shock and the like. Turn it off with "Interrupts" on the Notifications tab.
- **New: "Smallest crit".** On the Text tab: crits for less than this number show as normal hits (normal size, no crit sound, they don't hold in place), so only the big ones stand out. Off to start with.

## 1.20.2

- **Killing blows on mobs that weren't your target show again.** When you finished off a mob that wasn't your current target (a second mob on you, or one you'd tabbed away from with a DoT ticking), the final hit was often missing. A dying mob lets go of you just as the last hit lands, so BattleText no longer saw it as part of your fight. A mob you hit in the last few seconds now still counts as yours while it dies.
- Tip: keep enemy nameplates on (V by default). The game often sends the killing blow only under the mob's nameplate, not under your target, so with nameplates off some final hits can't reach any addon.

## 1.20.1

- **Wrack shows its ticks, with its name and icon.** The new Affliction talent wasn't known to BattleText yet, so its damage showed as plain numbers with no name or icon. Each tick now shows as Wrack, with its icon, on the mob you channel it at.
- **Your DoTs stay named while you channel Wrack.** Wrack makes your Corruption, Bane of Agony and Siphon Life tick twice as fast, which threw off how BattleText recognised their ticks. They now keep their own names during the channel.

## 1.20.0

- **New: "(blocked)" on hits you partly block.** When your shield blocks part of a hit, the damage you take now shows a grey "(blocked)" after it, like "-230 (blocked)". The game doesn't tell addons how much was blocked, so the exact amount only shows when BattleText can read the combat lines ("(150 blocked)"). Turn it off with "Show blocked" on the Incoming tab. (Thanks for the idea on CurseForge!)

## 1.19.1

- **Thorns and Retribution Aura together show properly.** When two damage shields answered the same blow (say a druid's Thorns on a paladin with Retribution Aura), only one of them was named. The other showed as a plain number, even with "Damage shields" turned off. Now each shield's hit is named, and "Damage shields" off hides them both.
- **Unsealed Wrath's damage shows.** The Retribution talent's extra Holy hit with your swing was taken for Retribution Aura hitting back, so with "Damage shields" off it disappeared. It now shows as Unsealed Wrath, with its icon, like your seal's hits.
- **"Damage shields" off also hides damage shield hits** read from the combat lines, not just the ones read off your target.

## 1.19.0

- **New: "Reset all"** (General tab, or type `/btf resetall`). Puts every setting back to how it started, colors, places and your Spells list included, after asking first. With "Settings for this character only" on, it resets just that character.
- **Group healing is more accurate.** In a group, other players' heals on your party could take the place of your own and show as yours, while some of your hits went unshown. A heal on someone else now only shows as yours when it's your spell, your heal over time or your Tranquility.
- **Hits on the mobs around you show again in some zones.** On maps where the game hides more from addons, BattleText couldn't tell which mob was attacking you or your pet, so hits on them could be missed. It now asks the game in another way that still works there.
- **Your hits on other mobs aren't skipped when one of your lines is readable.** A readable combat line for your target no longer hides your numbers on the other mobs you're hitting.
- **A spell that showed with no name for the rest of the session is fixed.** One unlucky moment (a Thorns answer landing right behind your Claw) could make BattleText think the spell was of the wrong school, and from then on it showed unnamed until you reloaded. It now waits to be sure, and corrects itself if it was wrong.
- **Healing yourself with a vendor or quest giver targeted** names the heal (and follows your heal over time) as it should.
- **Lots of crits at once stay in their area.** A burst of crits (Blizzard, Hurricane, Volley on a pack) used to pile up past the top of the area. Now as many stay as fit, and the oldest makes way.
- **"Show sample text" in a fight** no longer adds its numbers to your fight summary or fires Overpower.
- **Your own heals count in the fight summary** even when "Heals you get" is off or the spell is hidden on the Spells tab, as the tab says.
- **Buffs you cast on friends** (like Power Word: Fortitude) aren't mistaken for buffs you put on yourself.
- **Talent alerts (Riposte, Counterattack) work** without the game's old spellbook functions turned on.
- **A druid's power gains don't name the wrong power** (mana in cat form said "Energy"). They show the number alone.
- **Your pet's heals on you** no longer stop other players' heals on you from showing for a while.
- **Spell icons that didn't load** the first time are looked up again a little later, instead of staying missing until /reload.
- **The game's own numbers come back** properly when you turn "Hide the game's own numbers" off, even after a crash.
- **"Show who you healed"** now also works on heals BattleText reads from the combat lines.
- **Switching back to a target that still has combo points** no longer shows them again as a gain.
- **`/btf debug` turns itself off** when you log in, so it can't be left recording by mistake.
- Smoother in big fights: less work per line for fonts, Pop spots and group checks, and nothing keeps the combat lines on before you click Start.
- Tooltips fixed: Seals (Judgement leaves your seal on), Add up rapid hits (hidden amounts show the latest hit and how many), Damage shields (named straight away), and Hide the game's own numbers / Experience (hiding the game's "+XP" hides all of its pop-up text in the world).

## 1.18.4

- **Other players' hits on your target no longer show as yours when you're alone.** The game doesn't tell addons who hit what, so BattleText reads the numbers off your target. In a group, Start BattleText already left other people's hits out, but alone every hit on your target counted as yours, so a player outside your group hitting the same mob (or the same enemy player) showed up as your numbers. Now, once you've clicked Start BattleText, a hit alone also needs the game to say you did something just then: one of your attacks or spells, or your swing. Your damage shields (Thorns, Retribution Aura...) still show as before. One exception: on a mob your pet is fighting, every hit still shows, because the game gives no way to tell your pet's hits from anyone else's. Before you click Start, nothing changes. (Thanks to x4r3n for asking.)

## 1.18.3

- **Your heal-over-time ticks on others, and Tranquility, show their icon and name.** The same thing 1.18.1 fixed for ticks on yourself: the game doesn't always say a heal is Nature, so Rejuvenation, Regrowth and Renew ticks on your target, and Tranquility's heals, could show as a plain number or not at all. They're now named whatever school the game gives, as long as it isn't another magic school (a paladin's Holy heal still isn't taken for yours).

## 1.18.2

- **Regrowth's first heal on yourself shows its icon and name.** Its ticks were named in 1.18.1, but the heal as Regrowth lands still showed only "+number". Regrowth leaves a buff on you, so BattleText had learned it as a buff, and buffs never name a heal. A heal over time that also heals as it lands now counts as a heal.

## 1.18.1

- **Regrowth and Rejuvenation ticks on yourself show their icon, overheals too.** 1.16.4 names a heal-over-time tick on you by when it lands, every 3 seconds after your cast. A debug log showed every tick landing right on time, but the game doesn't always say the heal is Nature, so BattleText thought it was someone else's heal and left it as a plain "+number". A tick with no school now counts too (a heal of another school, like a paladin's Holy Light, still doesn't). `/btf debug` now also records the school of heals and hits on you, for future reports.

## 1.18.0

- **New: dispels in Notifications.** When you take something off, BattleText now says what: "Dispelled Deadly Poison" when you cleanse a friend or yourself (poison, curse, disease or magic), "Purged Power Word: Fortitude" when you strip a buff off an enemy, "Stole ..." with Spellsteal, with the icon of what came off. Mouseover dispels count too. **One step to turn it on:** right-click the Combat Log tab, then Settings, Message Types, Auras, tick **Dispels**, and Okay. Without that box, BattleText still shows the cure spell you cast ("Cleanse"), but it can't tell what it took off. On to start with; turn it off with "Dispels" on the Notifications tab, and pick its color on the Colors tab. (Thanks to user_iy4drbxtpt5r9noy4422 for the idea.)
- **New: "Login message"** (General tab). Turn it off to stop "BattleText Forever loaded. Type /btf for options." showing in chat every time you log in or /reload. The "click Start BattleText" line has its own switch just above it, "Remind me to click Start". (Thanks to Richmundo for asking.)

## 1.17.1

- **Shadow Bolt is named again when your damage over time is ticking.** With Bane of Agony, Corruption or another shadow spell ticking on a mob, a Shadow Bolt landing close to one of its ticks was taken for a second tick: it showed with no name, or the two swapped names, the bolt shown as the tick and the tick as the bolt. The game hides the numbers, so BattleText can't tell them apart by size. It now knows each damage over time ticks only once per beat, and once it has ticked it knows when the next one is due, so a spell landing beside a tick keeps its own name. The same goes for any spell that flies to its target landing beside a tick of the same school. (Thanks to Ethn91081 for the report and the debug log.)

## 1.17.0

- **New: "Keep Pop numbers apart"** (Motion tab). With Pop movement, three or four hits at once could land on the same spot and turn into an unreadable pile. Turn this on and a number that would land on top of one still showing moves to the nearest free spot instead, so every number stays readable. Pop still looks random, and crits that stay in place are kept clear too. Off to start with, so nothing changes unless you turn it on. (Thanks to Jarrique01 for the idea.)

## 1.16.5

- **"Add up rapid hits" now works when the game hides the numbers.** Arcane Explosion, Blizzard and other area spells showed one number for every mob they hit, even with "Add up rapid hits" on. The game now hides most damage numbers from addons, so BattleText can't add them together, but hits of one spell that land together now share one line: it shows the latest hit's number and how many hits there were, like "Arcane Explosion 52 (3 hits)". When the numbers can be read, they're added up as before, like "Arcane Explosion 156 (x3)". "Ticks and area hits add up for" sets how long the line keeps counting. (Thanks to Farsenur for the report.)

## 1.16.4

- **Damage shields show their icon from the first hit.** Retribution Aura, Thorns, Lightning Shield and Fire Shield used to need a few hits before BattleText knew their damage, and it often never learned it because the game hides the amounts. Now a hit of the shield's school on a mob that's attacking you is named as soon as that mob's blow on you lands. (Thanks to Ehldarion for the report.)
- **Heal-over-time ticks on yourself show their icon.** Rejuvenation, Regrowth and Renew ticks on you showed only "+number", because the game doesn't say which spell healed you. A heal on you that lands right on the beat of a heal-over-time you cast on yourself is now named after it. (Thanks to Ehldarion for the report.)
- **Retribution Aura can be hidden.** Its hits had no name, so a Hide rule on the Spells tab and "Damage shields" (Outgoing tab) couldn't catch them. Now that they're named, both work. (Thanks to user_qtzuiuer28ngqgnt for the report.)
- **"Hide the game's own numbers" now really hides the game's "+XP".** 1.16.2 changed a game setting by its older name, which Forever doesn't have (its is "WorldTextScale_v2"), so nothing changed. (Thanks to HAWKSMORE for testing it and reporting back.)
- **New: "Unnamed heals on you"** (Healing tab). The game hides the number of most heals on you, so "Hide heals below" can't catch small ones like Thrill of Adventure. Turn this off to hide heals on you that the game doesn't name: other players' heals, food and small passive heals. Your own heals keep their name and still show. On to start with.

## 1.16.3

- **Your white hits show in a group again.** In a group, BattleText only shows a hit when the game confirms it was yours, and it doesn't do that for every swing. Many of your auto attacks, and the mob's dodges and parries of them, never showed. BattleText now also follows the game's swing timer, so every swing you make counts as yours. (Thanks to skaine78 and dries9300 for the reports and the debug logs.)
- **Your abilities missing in a group show too.** A Revenge or Sunder Armor that missed, or was dodged or parried, showed nothing in a group. The game doesn't confirm misses, so the cast itself now counts.

## 1.16.2

- **"Hide the game's own numbers" now hides the game's "+XP" too.** With Experience on in Notifications, the game's own XP text still popped up in the world beside BattleText's. The game has no setting for just that text, so BattleText draws the game's floating world text too big to be seen (the numbers over mobs are already hidden by this option). It all comes back when you turn the option off, turn Experience off, or remove BattleText. (Thanks to HAWKSMORE for the report.)
- **Your heals on yourself show their icon and name.** Holy Light (or any heal) on yourself showed only "+number", because the game doesn't say which spell healed you. A heal that lands right as you finish casting a heal on yourself is now named after that spell. (Thanks to Ehldarion for the report.)
- **Seal of Righteousness hits show their icon and name.** The game sends the seal's damage up to a second before the swing it came with, so it showed as a plain yellow number. A seal hit now waits a moment for your swing and is named when the swing lands. If no swing comes, it shows as before. (Thanks to Ehldarion for asking.)

## 1.16.1

- **Icon zoom** (Text tab): crops the thin border round spell and item icons, so the picture fills its square. Off to start with. (Thanks to aLanaMaunz for the idea.)

## 1.16.0

- **Layout tab: pick the area each kind of text shows in.** Your hits, your misses, heals you do, damage you take, attacks you avoid, heals you get, power gains and notifications can each go to any of the four areas: Outgoing (right), Incoming (left), Healing (bottom) or Notifications (top). Everything starts where it was. An area nothing is sent to has its Appearance greyed out. (Thanks to RichieSams for the idea.)
- "Own area for heals" (Healing tab) is now part of the Layout tab. If you had it off, your heals stay with damage.
- **Dual-wielding: swings show the Attack icon.** The game doesn't say which hand a swing came from, so off-hand swings showed the main-hand weapon's icon. With a weapon in each hand, swings now show the neutral Attack icon.

## 1.15.3

- **No more error on skill ups in German (and other languages that number their sentences).** "Eure Fertigkeit 'Erste Hilfe' hat sich auf 101 erhöht." caused an "invalid capture index" error when BattleText looked for the skill's icon. The skill up now shows with its icon. (Thanks to the player who sent the BugGrabber report.)

## 1.15.2

- **Less work during crafting and bag changes.** The game sends a burst of "spells usable" events then; BattleText looked at its ability alerts (Execute, Hammer of Wrath) for every one. It now looks once per frame, and not at all for a class or level without those abilities. (Thanks to voxan-dev for the report.)

## 1.15.1

- **Turn off DoT and area spell ticks** (Outgoing tab, "DoTs and area spells"): hides the ticks of your damage-over-time spells and of spells that keep hitting an area, like Consecration, Blizzard and Rain of Fire. The spell's own first hit still shows. (Thanks to Dethkloch for asking.)
- **Sounds from your other addons.** Sounds that your other addons share through LibSharedMedia now show at the end of the crit and kill sound lists (Notifications tab). (Thanks to hyperdrivex for asking.)

## 1.15.0

- **Alignment for the side areas** (Outgoing and Incoming tabs, under Appearance): line their text up on the left, in the center or on the right. They start as before: outgoing on the left, incoming on the right. (Thanks to cloaken for asking.)
- **Fonts from your other addons.** Fonts that your other addons share through LibSharedMedia (many UI packs do) now show at the end of the font list on the Text tab. (Thanks to Venemar89 for asking.)

## 1.14.3

- **Bear and Cat Form swings show the right icon.** 1.14.2 showed a blue star instead of the form: the game gives that "form is on" icon for the form you're in. The icon now comes from the form itself.

## 1.14.2

- **Swings in Bear and Cat Form show the form's icon**, not your weapon's: a druid fights with claws there. (Thanks to the druid who asked.)

## 1.14.1

- **Maul no longer shows a "0" under its hit.** When the game hides the numbers, Maul (and Heroic Strike, Cleave, Raptor Strike) arrive with an empty part the game draws as "0". It's now left out, as the readable "Miss" already was. (Thanks to the druid who sent the debug lines.)

## 1.14.0

- **Setting a raid marker no longer gets BattleText blocked.** After you had picked something from one of BattleText's dropdowns (a font, an outline, a sound), choosing a target marker from the game's right-click menu on a unit frame could say "BattleTextForever has been blocked from an action only available to the Blizzard UI". BattleText's dropdowns used the game's own menus, which the game shares with its unit menus. They now open a list of BattleText's own, so the game's menus are left alone. (Thanks to darrell-cmyk for reporting it.)
- **Icons for your auto attacks.** Your swings now show your main hand weapon's icon (the Attack icon with nothing in your hands). Which hand a swing came from can't be told, so off hand swings show the main hand's icon too. (Thanks to prestoncr for the idea.)
- **Ranged attacks are named, with their icon.** Auto Shot, Shoot (bow, gun, crossbow or wand) and Throw showed as plain numbers, because they land a moment after you fire. Now the hit that lands on your target after one is named after it. They count as auto attacks: turning off Auto attacks hides them with your swings.
- The dropdowns' lists scroll with the mouse wheel and close when you click anywhere else or close the options.

## 1.13.0

- **More ability alerts** (Notifications tab, with Ability alerts):
  - **Execute!** (warriors) and **Hammer of Wrath!** (paladins) when your target is low enough to use them. The game hides your target's health, so BattleText goes by the game's own "can you cast it" answer. Short on rage or mana, the alert waits until you can press it.
  - **Spells the game lights up** on your action bars, and procs it shows on screen, like Clearcasting: "Clearcasting!". Overpower from a dodge and from its button lighting up shows once.
- **Combo points** (Notifications tab, on): rogues and cat druids see "2 CP" as they build, and "5 CP: Finish it!" when they have them all. They have their own color on the Colors tab.
- **Hide or recolor a spell** (new Spells tab): type a spell's name, then hide it (its hits, heals and misses don't show) or give it a color of its own. Hidden ones still count in the fight summary. They go with your settings when you share them.
- **Your last fight, spell by spell**: type `/btf last` for a table of each spell's hits, crits, total, share of your damage or healing, and biggest hit.

## 1.12.0

- **Channeled spells are named.** Arcane Missiles, Mind Flay, Drain Life, Drain Soul, Blizzard, Rain of Fire, Hurricane, Volley, Hellfire and Tranquility showed their first hit at most, then bare numbers. Now every hit while you channel is named, with its icon, on every mob it hits (Arcane Missiles, Mind Flay and the drains on the mob you channel at only). What was already on its way when you stop still counts.
- **Spells that keep burning an area are named.** Consecration, Flamestrike's burn, and Magma, Fire Nova and Searing Totem, for as long as they last.
- **Weapon and gear procs are named.** A "Chance on hit" that does damage (Shadowfang, Thunderfury and the like) shows the item's name and icon when it goes off with your weapon hits, and so do weapon enchants that hurt (Fiery Weapon, Icy Chill, Lifestealing, Unholy Weapon). A hit too big to be the proc stays a plain number.
- In a group, all of these still need a combat line of yours, like your other hits.

## 1.11.1

- **Explosives are named, with their icon.** Dynamite and other thrown explosives showed only a number. Now their hits show the item's name and icon, like your abilities, on every mob they hit (your target or not). Covered: Rough, Coarse, Heavy, Solid and Dense Dynamite, Ez-Thro Dynamite and Ez-Thro Dynamite II, Rough Copper Bomb, Large Copper Bomb, Small and Big Bronze Bomb, Iron Grenade, Big Iron Bomb, Mithril Frag Bomb, Hi-Explosive Bomb, The Big One, Thorium Grenade, Dark Iron Bomb, Arcane Bomb and Goblin Sapper Charge. A resist is named too. (Thanks to prestoncr for reporting it.)
- **Paladins: Judgement no longer takes your seal off.** On Forever a seal stays on when you cast Judgement, but BattleText showed "-Seal" at Judgement, then a "+Seal" you hadn't cast at the next look at your buffs. Now the seal stays until it runs out or another seal replaces it, and its hits beside your swing keep its name. How long a seal lasts is now taken from the game when your buffs can be read, so it goes away on time. (Thanks to anmjr757 for reporting it.)

## 1.11.0

- **Spells that fly to their target are named.** Fireball, Frostbolt, Pyroblast, Shadow Bolt, Soul Fire, Wrath, Starfire, Lightning Bolt, Chain Lightning, Hammer of Wrath and Arcane Shot showed as bare numbers, because they land a moment after the cast. Now the hit of that spell's school that lands on the mob you cast it at, within a couple of seconds, is named after it, with its icon. A resist is named too ("Frostbolt Resist").
  - Fireball's and Pyroblast's burn is named too, ticking from when the spell lands.
  - What can land at the same time is kept apart: a tick of yours of the same school on its beat (Insect Swarm while a Wrath is on its way) stays the tick unless its amount says otherwise, a much smaller hit (a mage's Ignite, Lightning Shield answering a blow) isn't taken for the spell once the spell has been seen to land, a seal's Holy hit beside your swing stays the seal's, and a swing landing meanwhile is never taken for it.
- **Ability alerts** (Notifications tab, on): a line when an ability you can use only just then opens up.
  - **Overpower!** when your target dodges you (warriors, level 12 and up).
  - **Revenge!** when you dodge, parry or block (warriors, level 14 and up).
  - **Riposte!** (rogues) and **Counterattack!** (hunters) when you parry, if you have the talent.
  - In a group, a dodge counts only with a combat line of yours, like your hits. The alerts have their own color on the Colors tab.
- The options window is a little taller, to fit the new switch.

## 1.10.3

- **Other players' heals no longer show as yours.** With a player targeted, a heal they got from something else (their own regeneration, someone else's heal) showed as your heal, with their name. Now a heal on someone else shows only when it lands with your own heal, or is a tick of your Rejuvenation, Regrowth or Renew. (Thanks to the player who reported it.)

## 1.10.2

- **Maul no longer shows a "Miss" with its hit.** The game sends some attacks as two parts at once, one for nothing and one with the damage. BattleText showed the empty part as a miss. Now it's one hit, as it already was for attacks on you. (Thanks to the druid who reported it.)

## 1.10.1

- **Start BattleText with a chat addon (like Chattynator).** A chat addon that replaces the game's chat window hides the game's Combat Log tab, so clicking Start BattleText did nothing and the button stayed until combat lines started on their own. Now BattleText notices and says so in chat. There's no real way around it while the game's Combat Log tab is hidden: alone, your hits still show; in a group, other people's hits may show as yours. (Thanks to the player who reported it.)
- **Right-click Start BattleText to hide it** until you log in again.

## 1.10.0

- **Hits on someone else's mob no longer show as yours.** With a mob targeted that another player tagged and is fighting, their hits on it showed up as your numbers. Now they're left out, unless the mob turns on you or your pet. With Start BattleText clicked, your own hits when you help out still show.
- **The options are easier to use:**
  - Click or hover a setting's name, not just its switch. Its tooltip now shows when you point at the name too. Same for the color squares.
  - Settings that do nothing with your other choices are greyed out, like "Ticks and area hits add up for" while "Add up rapid hits" is off, or "Scroll upward" with Pop movement. The Healing tab's Appearance says when heals aren't using their own area.
  - Sliders that are off at 0 say "Off".
  - Nearly every setting has a tooltip, and the ones that had one were checked against what the setting really does.
- **Clearer names:** the Scrolling tab is now **Motion**, with "Time on screen" and "Area height" (in pixels), and "Crits stay in place" instead of "Crits pop and hold". "Seal damage" is now **Name seal hits**, since turning it off shows the number without the seal's name. Each area's "Text size" is now **Size**. The crit sound "Crit" is now "Crafting crit".
- **Tidier tabs:** the Notifications tab is split into Show and Extras, Outgoing puts related switches side by side, and the color list goes by area. Loot's color can be changed too.
- **Safer:**
  - Import asks before replacing your settings, says whether they're this character's or the shared ones, and keeps your text areas where they are unless you turn on "Positions too".
  - Imported numbers are kept within each setting's range, and unknown fonts, outlines, sounds or movements are ignored.
  - Reset positions and Reset colors ask first.
  - Turning "Settings for this character only" off and back on brings back that character's settings instead of starting over.
- Time on screen moves in half seconds. Turning on "Hide the game's own numbers" during a fight says the change waits until the fight ends.

## 1.9.0

- **Fight summary** (Notifications tab, on): when a fight ends, a line with your damage, DPS and healing, like "4,820 damage (127 DPS), 1,200 healed in 38s". It counts the numbers the game lets BattleText read.
- **Movement styles** for each area: Scroll (as before), Pop, Fountain or Horizontal. Pick one under "Movement" on each area's tab.
- **Shadow** as a fourth outline choice (Text tab): a drop shadow instead of an outline, for normal lines and crits separately.
- **Size by hit** (Text tab, off): a big hit shows bigger than the hits before it, a small one smaller.
- **Ticks and area hits add up for longer** (Scrolling tab): set how many seconds the ticks of your DoTs and bleeds, and the hits of an area spell, keep adding up on one line. 0 keeps it as before.
- **Auto attacks** (Outgoing tab, on): turn off to hide your white swings and their misses, and see only your spells and abilities.
- **Sounds** (Notifications tab, off): a sound when you crit, and one on a killing blow. Pick each from 18 of the game's sounds (Crit, Impact, Anvil, Battle horn, Boss defeated, Cheers, Epic loot...); picking one plays it. If Forever doesn't have the one you picked, chat says so and a plain ping or chime plays instead.
- **Share settings** (General tab): Export gives your settings as text to copy; Import takes someone else's. Also `/btf export` and `/btf import`.
- The card with each area's text size, opacity and movement is now called **Appearance** instead of "This area".
- **Bane of Agony's ticks are named.** Forever calls the warlock spell Bane of Agony, not Curse of Agony, so its ticks showed as bare numbers.
- Buffs: Sweeping Strikes is recognized as a buff you put on yourself; a spell that isn't in Forever was taken off the list. Found with `/btf check` in game.

## 1.8.0

- **Each text area scrolls its own way.** "Scroll upward" is now on each area's tab (Outgoing, Incoming, Healing, Notifications), so your hits can scroll up while the damage you take scrolls down. "Curved scrolling" is on the Outgoing and Incoming tabs too (the other two scroll straight). Your current choices carry over to every area.
- **Three new fonts in the style of Diablo**: Cinzel Decorative, Metamorphous and New Rocker (23 fonts in all). Diablo's own font can't be included (it's licensed to Blizzard), so these are free look-alikes.

## 1.7.2

- **A heal on you could go missing.** When one of your own heals on yourself and someone else's heal landed at the same moment, only yours was shown. Now both are.
- Behind the scenes: the text animation rests while nothing is on screen, and BattleText no longer keeps old damage-over-time and merge records for the whole session. Nothing changes in what you see.

## 1.7.1

- **Area spells show on every mob they hit.** Fire Nova, Arcane Explosion and the like only showed on your target and the mobs attacking you; mobs on someone else, or just pulled, were left out. Now a hit on any mob counts as yours when it lands in the same instant, and with the same school, as one of yours on a mob you're fighting. Enemy nameplates still need to be on.
- **"Hide the game's own numbers" works on Forever.** The numbers the game puts over the mobs you hit kept showing: Forever renamed that setting (it's `floatingCombatTextCombatDamage_v2` now), and BattleText only knew the old name. It now turns off the damage, healing and pet numbers by their new names too, and puts them back as they were when you turn the option off. (Thanks to the players who reported it, and to the one who found the setting's name.)
- **Buffs you put on yourself now show during a fight.** Slice and Dice (and Evasion, Sprint, Adrenaline Rush and the like) showed nothing in combat, because the game hides your buffs there. Now its line shows as you cast it, and when it ran out shows as soon as the fight ends.

## 1.7.0

- **Seals** (Notifications tab): paladins get a line when a seal goes on or comes off ("+Seal of Righteousness"), with its icon and its own color. In a fight the game hides your buffs, so a seal coming off is worked out: Judgement uses it up, a new seal replaces it, or its 30 seconds run out.
- **A seal's damage is named**: the Holy hit of Seal of Righteousness or Seal of Command that lands with your swing now shows the seal's name and icon instead of a bare number. Turn off **Seal damage** (Outgoing tab) to keep the plain number.
- **Buffs** (Notifications tab, off unless you turn it on): a line when a buff goes on or comes off ("+Arcane Intellect"). The game hides your buffs during a fight, so what changed in one shows when it ends. Food, drink, and buffs with no time limit (mounts, auras, stances) are left out, and dying doesn't fill the screen.
- `/btf check` also checks the seals and Judgement.

## 1.6.0

- **Colors**: a new Colors tab to pick the color of your hits, spells, misses, the damage you take, avoids, heals, power gains, notifications, combat and experience. **Reset colors** puts them back.
- **Each text area has its own text size and opacity**, at the bottom of its tab (Outgoing, Incoming, Healing, Notifications).
- **Settings for this character only** (General tab): a character can keep its own settings, starting from a copy of the shared ones.
- **Short numbers** (Text tab): 12,345 shows as 12.3k.
- **Show who you healed** (Healing tab): the name of the player after a heal you do, when the game lets BattleText read it.
- **`/btf check`**: checks every spell, text and icon BattleText relies on against your game, on any character, and lists anything missing.

## 1.5.0

- **A new look**, the same as TauntMaster Forever, ToppedOff Forever and Outfitter Forever: the options are a window with tabs down the left (General, Text, Scrolling, Outgoing, Incoming, Healing, Notifications) and a switch for each setting. Your settings are kept.
- The text areas' boxes (while you move them) and the **Start BattleText** button have the shared header bar with the logo, and chat lines start with the logo and name like the other addons.

## 1.4.0

- **Heals have their own area**, under your character: the heals you get and the heals you do. The damage areas now show only damage. Drag the new area where you like with **Move the text areas**, or untick **Own area for heals** to put heals back with the damage.
- **A Healing section in the options**: heals you get, heals you do (your choices carry over), **Show overhealing**, and **Hide heals below** a number.
- **More icons**: spells that hit you or that you avoid, heals you get, and skill ups (professions like First Aid or Herbalism) now show their icon.
- **The options are in three columns**, with sections named after the text areas: **Outgoing**, **Incoming**, **Healing** and **Notifications**. Each has its own **Icons** box, and the combat ones a **Names** box, in place of the old "Spell icons" and "Spell names". Your old choices carry over to every section.

## 1.3.0

- **Scroll upward.** A new option makes the lines start at the bottom of their area and move up, instead of down.
- **Outline thickness**, for normal lines and crits separately: None, Thin or Thick. Picking one shows a sample line in it straight away.

## 1.2.4

- **A reminder to click Start.** Ten seconds after you log in or reload, if you haven't clicked **Start BattleText** yet, a line in chat reminds you (and names the key, if you've bound one). Turn it off with **Remind me to click Start** in the options.

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
