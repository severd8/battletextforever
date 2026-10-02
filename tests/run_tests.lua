-- Test scenarios for BattleText Forever. Run via tests/run.lua (see DEVNOTES.md).
-- Any Lua error aborts with a traceback.
local ADDON = "BattleTextForever"
local ns = {}
local function load_file(path)
    local f = assert(io.open(path)) local src = f:read("*a") f:close()
    local chunk = assert(loadstring(src, "@" .. path))
    chunk(ADDON, ns)
end
-- Blizzard's globals: the addon may add to these tables but must never assign
-- the global itself, or hand Blizzard's frames new scripts (that taints the
-- Blizzard UI). While the addon loads, any such assignment fails.
local BLIZZARD_GLOBALS = { "UISpecialFrames", "SlashCmdList", "COMBATLOG", "ChatFrame1", "ChatFrame2",
    "SELECTED_DOCK_FRAME", "C_CombatLog", "Enum" }
local guarded = {}
for _, n in ipairs(BLIZZARD_GLOBALS) do guarded[n] = rawget(_G, n); rawset(_G, n, nil) end
setmetatable(_G, {
    __index = function(_, k) return guarded[k] end,
    __newindex = function(t, k, v)
        if guarded[k] ~= nil then error("assigned Blizzard global " .. k .. " (taints the Blizzard UI)", 2) end
        rawset(t, k, v)
    end,
})
load_file(ADDON_DIR .. "/Parse.lua")
load_file(ADDON_DIR .. "/Core.lua")
load_file(ADDON_DIR .. "/Options.lua")
setmetatable(_G, nil)
for n, v in pairs(guarded) do rawset(_G, n, v) end
local BT, Parser = ns.BT, ns.Parser

local function fire(event, ...)
    for _, f in ipairs(ALL_FRAMES) do
        if f.__events and f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
    end
end
local function step(name) print("STEP " .. name) end
local function assertEq(a, b, msg)
    if a ~= b then error(("ASSERT %s: got %s expected %s"):format(msg, tostring(a), tostring(b)), 2) end
end
local function log(line) fire("COMBAT_LOG_MESSAGE", line, 1, 1, 1, Enum.CombatLogMessageOrder.Newest) end
-- The lines currently in an area, oldest first, as text
local function lines(area)
    local out = {}
    for _, o in ipairs(BT.areas[area].active) do out[#out + 1] = o.text:GetText() end
    return out
end
local function last(area) local l = lines(area) return l[#l] end
local function clear()
    Advance(8)
    for _, a in pairs(BT.areas) do assertEq(#a.active, 0, "area emptied: " .. a.key) end
end

---------------------------------------------------------------------------
step("reading combat log lines")
Parser:Init()
local function parse(line) return Parser:Parse(line) end
local p = parse("Your Melee hit Bristleback Hunter Fizzlesticks 27 Physical.")
assertEq(p.kind, "damage", "swing: kind"); assertEq(p.fromMe, true, "swing: mine")
assertEq(p.melee, true, "swing: melee"); assertEq(p.spell, nil, "swing: no spell name")
assertEq(p.amount, 27, "swing: amount"); assertEq(p.unit, "Physical", "swing: school"); assertEq(p.toMe, nil, "swing: not at me")
p = parse("Your Claw hit Bristleback Hunter Fizzlesticks 50 Physical. (1 Blocked)")
assertEq(p.spell, "Claw", "spell name"); assertEq(p.amount, 50, "spell amount"); assertEq(p.blocked, 1, "blocked amount")
assertEq(p.crit, nil, "not a crit")
p = parse("Your Melee hit Bristleback Hunter Quillbane 56 Physical. (Critical)")
assertEq(p.crit, true, "crit"); assertEq(p.amount, 56, "crit amount")
p = parse("Your Claw hit Bristleback Thornweaver Lightbrand 17 Physical. (35 Overkill)")
assertEq(p.overkill, 35, "overkill"); assertEq(p.amount, 17, "overkill: amount")
p = parse("Your Mortal Strike hit Defias Thug Volare 1,234 Physical. (120 Absorbed) (Critical)")
assertEq(p.spell, "Mortal Strike", "two-word spell"); assertEq(p.amount, 1234, "thousands separator")
assertEq(p.absorbed, 120, "absorbed"); assertEq(p.crit, true, "crit after another result")
p = parse("You killed Bristleback Thornweaver Fizzlesticks.")
assertEq(p.kind, "kill", "kill"); assertEq(p.fromMe, true, "kill: mine")
p = parse("Bristleback Hunter Pal's Melee hit You 12 Physical. (3 Blocked)")
assertEq(p.kind, "damage", "incoming: kind"); assertEq(p.toMe, true, "incoming: at me"); assertEq(p.fromMe, nil, "incoming: not mine")
assertEq(p.melee, true, "incoming: melee"); assertEq(p.amount, 12, "incoming: amount"); assertEq(p.blocked, 3, "incoming: blocked")
p = parse("Defias Pillager Son's Fireball hit You 84 Fire.")
assertEq(p.spell, "Fireball", "incoming spell"); assertEq(p.unit, "Fire", "incoming school")
p = parse("Kobold Geomancer Zapsu's Hunter's Mark hit You 5 Arcane.")
assertEq(p.spell, "Hunter's Mark", "a spell with an apostrophe")
p = parse("Your Melee missed Bristleback Hunter Totes. Dodge")
assertEq(p.kind, "miss", "miss"); assertEq(p.missType, "DODGE", "miss type"); assertEq(p.missText, "Dodge", "miss word")
p = parse("Your Moonfire missed Bristleback Hunter Totes. (Resist)")
assertEq(p.missType, "RESIST", "miss type in brackets"); assertEq(p.spell, "Moonfire", "missed spell")
p = parse("Bristleback Hunter Faust's Melee missed You. Parry")
assertEq(p.kind, "miss", "incoming miss"); assertEq(p.toMe, true, "incoming miss at me"); assertEq(p.missType, "PARRY", "parry")
p = parse("Your Healing Touch healed You 500 Nature. (120 Overhealed)")
assertEq(p.kind, "heal", "heal"); assertEq(p.fromMe, true, "heal mine"); assertEq(p.toMe, true, "heal on me")
assertEq(p.amount, 500, "heal amount"); assertEq(p.overheal, 120, "overheal")
p = parse("Your Rejuvenation healed Anduin Gabgubman 61 Nature.")
assertEq(p.kind, "heal", "heal on someone else"); assertEq(p.toMe, nil, "not on me")
p = parse("Your Rend damaged Bristleback Hunter Faust 9 Physical.")
assertEq(p.kind, "damage", "damage over time"); assertEq(p.spell, "Rend", "dot spell")
p = parse("Your Bloodrage energized You 10 Rage.")
assertEq(p.kind, "energize", "power gain"); assertEq(p.unit, "Rage", "power type"); assertEq(p.toMe, true, "power to me")
p = parse("Your |cffff8000Claw|r hit |Hunit:Creature-0:Boar|hBoar Faust|h 50 Physical.")
assertEq(p.spell, "Claw", "color codes are ignored"); assertEq(p.amount, 50, "links are ignored")
assertEq(parse("Bristleback Hunter Faust died.").kind, "died", "a death (not shown by itself)")
assertEq(parse("Stormsnout dies, you gain 103 experience."), nil, "not a combat line")
assertEq(parse(""), nil, "empty line")
assertEq(parse(Secret("Your Claw hit X 5 Physical.")), nil, "hidden text isn't read")

---------------------------------------------------------------------------
step("load and log in")
fire("ADDON_LOADED", ADDON)
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
assert(BT.areas.incoming and BT.areas.outgoing and BT.areas.notify, "three text areas")
assertEq(BT.db.enabled, true, "on by default")
assertEq(BT.areas.outgoing.mover:IsShown(), false, "areas are locked by default")

step("start button: the combat log needs opening once")
local start = BT.startButton
assertEq(start:IsShown(), true, "Start button shows after login")
assertEq(start:GetAttribute("type"), "macro", "it's a click on the Combat Log tab")
assertEq(start:GetAttribute("macrotext"), "/click ChatFrame2Tab\n/click ChatFrame1Tab", "open the tab, then go back")
assertEq(BT.started, nil, "not started yet")
-- The click: mouse down, then up. The game opens and closes the Combat Log tab.
start.__scripts.PostClick(start, "LeftButton", true)
assertEq(start:IsShown(), true, "still there after the press (the release may be what opens the tab)")
ChatFrame2:Show(); ChatFrame2:Hide()
STATE.filteredEvents = false   -- the game turns the lines off when the tab hides
if ChatFrame2.__scripts.OnHide then ChatFrame2.__scripts.OnHide(ChatFrame2) end
start.__scripts.PostClick(start, "LeftButton", false)
assertEq(BT.started, true, "started")
assertEq(start:IsShown(), false, "Start button gone")
assertEq(STATE.filteredEvents, true, "BattleText turned the lines back on")
STATE.filteredEvents = false
for _, fn in ipairs(TICKERS) do fn() end
assertEq(STATE.filteredEvents, true, "and keeps them on")

---------------------------------------------------------------------------
step("your hits")
BT.db.icons = false
log("Your Melee hit Bristleback Hunter Fizzlesticks 27 Physical.")
assertEq(last("outgoing"), "27", "a swing shows its number")
Advance(1)
log("Your Claw hit Bristleback Hunter Fizzlesticks 50 Physical. (1 Blocked)")
assertEq(last("outgoing"), "Claw 50 |cffb0b0b0(1 blocked)|r", "a spell shows its name, number and what was blocked")
assertEq(#lines("incoming"), 0, "nothing in the incoming area")
BT.db.spellNames = false
Advance(1)
log("Your Claw hit Bristleback Hunter Fizzlesticks 50 Physical.")
assertEq(last("outgoing"), "50", "spell names off")
BT.db.spellNames, BT.db.icons = true, true
Advance(1)
log("Your Claw hit Bristleback Hunter Fizzlesticks 51 Physical.")
assertEq(last("outgoing"), "|T132140:0|t Claw 51", "spell icon")
BT.db.icons = false
clear()

step("rapid hits add up")
log("Your Swipe hit Boar Faust 40 Physical.")
log("Your Swipe hit Boar Totes 45 Physical.")
log("Your Swipe hit Boar Pal 50 Physical.")
assertEq(#lines("outgoing"), 1, "one line for three hits")
assertEq(last("outgoing"), "Swipe 135 |cffb0b0b0(x3)|r", "total and count")
Advance(1.5)
log("Your Swipe hit Boar Faust 40 Physical.")
assertEq(#lines("outgoing"), 2, "a later hit is its own line")
BT.db.merge = false
clear()
log("Your Swipe hit Boar Faust 40 Physical.")
log("Your Swipe hit Boar Totes 45 Physical.")
assertEq(#lines("outgoing"), 2, "adding up turned off")
BT.db.merge = true
clear()

step("crits are bigger and hold")
log("Your Claw hit Boar Faust 100 Physical. (Critical)")
local crit = BT.areas.outgoing.active[1]
assertEq(crit.sticky, true, "sticky")
assertEq(crit.text.__font[2], 30, "150% of the text size")
log("Your Claw hit Boar Faust 110 Physical. (Critical)")
assertEq(BT.areas.outgoing.active[2].slot, 1, "a second crit stacks above the first")
Advance(0.5)
assertEq(crit.__scale, 1, "settled after the pop")
BT.db.sticky = false
clear()
log("Your Claw hit Boar Faust 100 Physical. (Critical)")
assertEq(BT.areas.outgoing.active[1].sticky, false, "sticky off: crits scroll, still bigger")
assertEq(BT.areas.outgoing.active[1].text.__font[2], 30, "still bigger")
BT.db.sticky = true
clear()

step("misses, heals and small hits")
log("Your Melee missed Bristleback Hunter Totes. Dodge")
assertEq(last("outgoing"), "Dodge", "a dodged swing")
log("Your Rejuvenation healed Anduin Gabgubman 61 Nature.")
assertEq(last("outgoing"), "Rejuvenation +61", "a heal on someone else")
BT.db.minDamage = 30
log("Your Melee hit Boar Faust 12 Physical.")
assertEq(last("outgoing"), "Rejuvenation +61", "hits below the limit are hidden")
BT.db.minDamage = 0
BT.db.outMisses = false
log("Your Melee missed Bristleback Hunter Totes. Dodge")
assertEq(last("outgoing"), "Rejuvenation +61", "misses turned off")
BT.db.outMisses = true
clear()

---------------------------------------------------------------------------
step("damage you take, without the combat log")
fire("UNIT_COMBAT", "player", "WOUND", "", 23, 1)
assertEq(last("incoming"), "-23", "a hit on you")
fire("UNIT_COMBAT", "player", "WOUND", "CRITICAL", 58, 1)
assertEq(BT.areas.incoming.active[2].sticky, true, "a crit on you holds")
fire("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
assertEq(last("incoming"), "Dodge", "you dodged")
fire("UNIT_COMBAT", "target", "WOUND", "", 99, 1)
assertEq(#lines("incoming"), 3, "other units are ignored")
fire("UNIT_COMBAT", "player", "WOUND", "", Secret(40), 1)
assertEq(last("incoming"), "<secret fmt>", "a hidden amount is still shown by the game")
clear()
fire("UNIT_COMBAT", "player", "HEAL", "", 120, 8)
Advance(0.3)
assertEq(last("incoming"), "+120", "a heal on you")
clear()

step("your own heals aren't shown twice")
fire("UNIT_COMBAT", "player", "HEAL", "", 500, 8)
log("Your Healing Touch healed You 500 Nature. (120 Overhealed)")
Advance(0.3)
assertEq(#lines("incoming"), 1, "one line")
assertEq(last("incoming"), "+500 Healing Touch |cffb0b0b0(120 over)|r", "with the spell's name")
clear()

step("damage you take, when the combat log shows it")
fire("UNIT_COMBAT", "player", "WOUND", "", 12, 1)
log("Bristleback Hunter Pal's Melee hit You 12 Physical. (3 Blocked)")
assertEq(BT.logIncoming, true, "the log covers what happens to you")
fire("UNIT_COMBAT", "player", "WOUND", "", 84, 4)
log("Defias Pillager Son's Fireball hit You 84 Fire.")
local inc = lines("incoming")
assertEq(inc[#inc], "-84 Fireball", "with the spell's name")
assertEq(#inc, 3, "the second hit is shown once")
-- The player switches back to "My actions": no more incoming lines in the log
for _ = 1, 4 do fire("UNIT_COMBAT", "player", "WOUND", "", 10, 1) end
assertEq(BT.logIncoming, false, "noticed the log stopped covering it")
assertEq(last("incoming"), "-10", "UNIT_COMBAT takes over again")
clear()

---------------------------------------------------------------------------
step("old and hidden lines")
fire("COMBAT_LOG_MESSAGE", "Your Claw hit Boar Faust 50 Physical.", 1, 1, 1, Enum.CombatLogMessageOrder.Oldest)
assertEq(#lines("outgoing"), 0, "replayed history isn't shown")
fire("COMBAT_LOG_MESSAGE", Secret("Your Claw hit Boar Faust 50 Physical."), 1, 1, 1, 0)
assertEq(last("outgoing"), "<secret fmt>", "hidden text is shown as it is")
clear()

step("lines scroll, keep their distance and go away")
log("Your Claw hit Boar Faust 50 Physical.")
log("Your Bite hit Boar Faust 60 Physical.")
log("Your Rake hit Boar Faust 70 Physical.")
local act = BT.areas.outgoing.active
assert(act[2].start > act[1].start and act[3].start > act[2].start, "each line starts after the one before")
Advance(1)
assert(act[1].__pos[2] < 0, "moving down")
assert(act[1].__pos[1] > 0, "bowing outward")
BT.db.curved = false
Advance(0.1)
assertEq(act[1].__pos[1], 0, "straight when curves are off")
BT.db.curved = true
Advance(5)
assertEq(#BT.areas.outgoing.active, 0, "gone after their time")
for i = 1, 40 do log("Your Spell" .. i .. " hit Boar Faust 5 Physical.") end
local latest = BT.areas.outgoing.active[40]
assert(latest.start - GetTime() <= 1.21, "a flood never waits more than a moment")
clear()

---------------------------------------------------------------------------
step("notifications")
fire("PLAYER_REGEN_DISABLED")
assertEq(last("notify"), "+Combat", "entering combat")
fire("PLAYER_REGEN_ENABLED")
assertEq(last("notify"), "-Combat", "leaving combat")
log("You killed Bristleback Thornweaver Fizzlesticks.")
assertEq(last("notify"), "Killing blow!", "killing blow")
STATE.xp = 203
fire("PLAYER_XP_UPDATE")
assertEq(last("notify"), "+103 XP", "experience")
STATE.xp, STATE.xpMax = 50, 1200   -- levelled up: 797 to finish the level, 50 into the next
fire("PLAYER_XP_UPDATE")
assertEq(last("notify"), "+847 XP", "experience across a level")
fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:2589::::::::20:::::|h[Linen Cloth]|h|rx2.")
assertEq(last("notify"), "+2 |cffffffff|Hitem:2589::::::::20:::::|h[Linen Cloth]|h|r", "your loot")
fire("CHAT_MSG_LOOT", "Anduin receives loot: |cffffffff|Hitem:2589::::::::20:::::|h[Linen Cloth]|h|r.")
assertEq(last("notify"), "+2 |cffffffff|Hitem:2589::::::::20:::::|h[Linen Cloth]|h|r", "someone else's loot isn't")
fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Your reputation with Stormwind has increased by 25.")
assertEq(last("notify"), "Your reputation with Stormwind has increased by 25", "reputation")
fire("CHAT_MSG_SKILL", Secret("Your skill in Swords has increased to 12."))
assertEq(last("notify"), "Your reputation with Stormwind has increased by 25", "hidden chat lines are skipped")
BT.db.nCombat = false
fire("PLAYER_REGEN_DISABLED")
assertEq(last("notify"), "Your reputation with Stormwind has increased by 25", "combat notifications turned off")
BT.db.nCombat = true
clear()

---------------------------------------------------------------------------
step("pet lines only with a pet out")
log("Fluffy Zapsu's Bite hit Boar Faust 20 Physical.")
assertEq(#lines("outgoing"), 0, "no pet: someone else's hit")
STATE.pet = true
log("Fluffy Zapsu's Bite hit Boar Faust 20 Physical.")
assertEq(last("outgoing"), "Bite (Pet) 20", "your pet's hit")
STATE.pet = false
clear()

step("moving and turning off")
SlashCmdList.BATTLETEXTFOREVER("unlock")
assertEq(BT.areas.outgoing.mover:IsShown(), true, "boxes to drag")
SlashCmdList.BATTLETEXTFOREVER("lock")
assertEq(BT.areas.outgoing.mover:IsShown(), false, "locked again")
BT.db.areas.outgoing.x = 400
SlashCmdList.BATTLETEXTFOREVER("reset")
assertEq(BT.db.areas.outgoing.x, 230, "positions reset")
SlashCmdList.BATTLETEXTFOREVER("off")
log("Your Claw hit Boar Faust 50 Physical.")
assertEq(#lines("outgoing"), 0, "nothing while turned off")
assertEq(start:IsShown(), false, "no Start button while turned off")
SlashCmdList.BATTLETEXTFOREVER("test")
Advance(4)
assert(#lines("outgoing") > 0 and #lines("incoming") > 0 and #lines("notify") > 0, "sample text shows even when off")
SlashCmdList.BATTLETEXTFOREVER("on")
clear()

step("the game's own numbers")
BT.db.hideBlizzard = true
BT:ApplySettings()
assertEq(STATE.cvars.floatingCombatTextCombatDamage, "0", "turned off")
BT.db.hideBlizzard = false
BT:ApplySettings()
assertEq(STATE.cvars.floatingCombatTextCombatDamage, "1", "put back as it was")
assertEq(BT.db.savedCVars, nil, "nothing left over")

step("combat lockdown")
BT.started = nil
BT.startButton.wanted = nil
COMBAT, BLOCKED = true, {}
BT:UpdateStartButton()
BT:SetStartMacro()
BT:ApplySettings()
log("Your Claw hit Boar Faust 50 Physical.")
Advance(1)
assertEq(#BLOCKED, 0, "protected frame touched in combat: " .. table.concat(BLOCKED, ", "))
COMBAT = false
fire("PLAYER_REGEN_ENABLED")
assertEq(start:IsShown(), false, "a line arrived, so it had started")
clear()

step("options window")
BT:OpenConfig()
assertEq(BT.config:IsShown(), true, "opens")
assertEq(UISpecialFrames[#UISpecialFrames], "BattleTextForeverOptions", "Escape closes it")
-- Click every checkbox twice: nothing errors, and the settings end where they began
local before = {}
for k, v in pairs(BT.db) do before[k] = v end
for _, f in ipairs(ALL_FRAMES) do
    if f.__kind == "CheckButton" and f.__scripts.OnClick then
        f:SetChecked(not f:GetChecked()); f.__scripts.OnClick(f)
        f:SetChecked(not f:GetChecked()); f.__scripts.OnClick(f)
    end
end
for k, v in pairs(before) do
    if type(v) ~= "table" then assertEq(BT.db[k], v, "setting unchanged: " .. k) end
end
BT:OpenConfig()
assertEq(BT.config:IsShown(), false, "closes")
print("ALL TESTS PASSED")
