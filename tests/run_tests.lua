-- Test scenarios for BattleText Forever. Run via tests/run.lua (see DEVNOTES.md).
-- Any Lua error aborts with a traceback.
--
-- The combat log lines used here are real: tests/real_lines.lua holds what the
-- game's own Combat Log code writes (see tests/tools/make_real_lines.lua), and
-- the few lines built by hand below are checked against it first.
local ADDON = "BattleTextForever"
local ns = {}
local function read_file(path)
    local f = assert(io.open(path)) local src = f:read("*a") f:close()
    return src
end
local function load_file(path, into)
    local chunk = assert(loadstring(read_file(path), "@" .. path))
    chunk(ADDON, into or ns)
end
local function step(name) print("STEP " .. name) end
local function assertEq(a, b, msg)
    if a ~= b then error(("ASSERT %s: got %s expected %s"):format(msg, tostring(a), tostring(b)), 2) end
end
-- Nothing an addon must never do has happened (see VIOLATIONS in wowstub.lua)
local function assertClean(when)
    assertEq(table.concat(VIOLATIONS, "; "), "", "rule broken " .. when)
    assertEq(STATE.logBroken, false, "the game's combat log is intact " .. when)
end

---------------------------------------------------------------------------
step("files and keybindings")
local toc = read_file(ADDON_DIR .. "/" .. ADDON .. ".toc")
local tocFiles = {}
for line in toc:gmatch("[^\r\n]+") do
    if not line:find("^#") and line:find("%S") then tocFiles[#tocFiles + 1] = line:match("^%s*(.-)%s*$") end
end
assertEq(table.concat(tocFiles, " "), "Parse.lua Core.lua Options.lua", "the files the game loads, in order")
for _, file in ipairs(tocFiles) do assert(io.open(ADDON_DIR .. "/" .. file), "listed file is missing: " .. file) end
assertEq(toc:match("## Interface: (%d+)"), "16001", "made for WoW: Forever")
assert(toc:find("## SavedVariables: BattleTextForeverDB", 1, true), "settings are saved")
local icon = toc:match("## IconTexture: Interface\\AddOns\\" .. ADDON .. "\\(%S+)")
assert(icon and io.open(ADDON_DIR .. "/" .. icon:gsub("\\", "/") .. ".tga"), "the icon file exists")

for _, file in ipairs(tocFiles) do load_file(ADDON_DIR .. "/" .. file) end
local BT, Parser = ns.BT, ns.Parser
assertClean("while the files load")

local bindings = read_file(ADDON_DIR .. "/Bindings.xml")
local bindingNames = {}
for name in bindings:gmatch('<Binding name="([^"]+)"') do
    bindingNames[#bindingNames + 1] = name
    assert(type(_G["BINDING_NAME_" .. name]) == "string", "keybinding has no label: " .. name)
end
assertEq(#bindingNames, 2, "two keybindings")

local function fire(event, ...)
    for _, f in ipairs(ALL_FRAMES) do
        if f.__events and f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
    end
end
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
-- Real lines
---------------------------------------------------------------------------
local REAL = dofile(ADDON_DIR .. "/tests/real_lines.lua")
local byId = {}
for _, entry in ipairs(REAL) do byId[entry.id] = entry end
local function real(id) return assert(byId[id], "no such real line: " .. id).raw end

-- A few lines are built here so their numbers can vary. Each is the game's
-- exact format (checked against the real lines below).
local ME = "|Hunit:Player-5555-0ABCDEF1:Abla|h"
local MOB = "|Hunit:Creature-0-1-2-3-4-000001:Bristleback Hunter Fizzlesticks|hBristleback Hunter Fizzlesticks|h"
local function notes(n) return n and (n .. " ") or "" end
local function hit(spell, id, amount, school, n)   -- "Your Claw hit <mob> 50 Physical. (Critical)"
    return ME .. "Your|h |Hspell:" .. id .. ":0:SPELL_DAMAGE|h|cffffffff" .. spell .. "|r|h |Haction:SPELL_DAMAGE|hhit|h "
        .. MOB .. " |cffffffff" .. amount .. "|r |cffffffff" .. (school or "Physical") .. "|r. " .. notes(n)
end
local function swing(amount, n)                     -- "Your Melee hit <mob> 27 Physical."
    return ME .. "Your|h |Haction:SWING_DAMAGE|h|cffffffffMelee|r|h |Haction:SWING_DAMAGE|hhit|h "
        .. MOB .. " |cffffffff" .. amount .. "|r |cffffffffPhysical|r. " .. notes(n)
end
local function hitMe(spell, id, amount, school)     -- "<mob> Fireball hit You 84 Fire."
    return MOB .. " |Hspell:" .. id .. ":0:SPELL_DAMAGE|h|cffff1313" .. spell .. "|r|h |Haction:SPELL_DAMAGE|hhit|h "
        .. ME .. "You|h |cffff1313" .. amount .. "|r |cffff1313" .. school .. "|r. "
end
local function healMe(spell, id, amount, n)         -- "Your Healing Touch healed You 380 Nature."
    return ME .. "Your|h |Hspell:" .. id .. ":0:SPELL_HEAL|h|cffffffff" .. spell .. "|r|h |Haction:SPELL_HEAL|h|cff7f7f7fhealed|r|h "
        .. ME .. "You|h |cffffffff" .. amount .. "|r |cffffffffNature|r. " .. notes(n)
end

step("the hand-built lines are the game's format")
assertEq(hit("Claw", 16827, 50, "Physical", "(1 Blocked)"), real("spell"), "a spell hit")
assertEq(hit("Moonfire", 8921, 112, "Arcane", "(Critical)"), real("spell, crit"), "a spell crit")
assertEq(swing(27), real("swing"), "a swing")
assertEq(swing(56, "(Critical)"), real("swing, crit"), "a swing crit")
assertEq(hitMe("Fireball", 133, 84, "Fire"), real("spell at me"), "a spell at me")
assertEq(healMe("Healing Touch", 5185, 380, "(120 Overhealed)"), real("heal on myself"), "a heal on myself")

-- Everything BattleText acts on. A field left out of `expect` must be unset.
local FIELDS = { "kind", "fromMe", "toMe", "melee", "spell", "spellId", "amount", "unit", "crit", "glancing", "crushing",
    "periodic", "split", "blocked", "absorbed", "resisted", "overkill", "overheal", "missType" }
local function sameParse(got, expect, fields, id)
    if expect == nil then
        assertEq(got, nil, id .. ": nothing to show")
        return
    end
    assert(got, id .. ": not read at all")
    for _, field in ipairs(fields) do
        local want = expect[field]
        if field == "missType" and want == nil and expect.kind == "miss" then want = "MISS" end
        local have = got[field]
        if have == false then have = nil end
        assertEq(have, want, id .. ": " .. field)
    end
    if expect.srcGUID and fields == FIELDS then assertEq(got.srcGUID, expect.srcGUID, id .. ": who did it") end
end

step("reading the game's combat log lines")
Parser:Init()
for _, entry in ipairs(REAL) do sameParse(Parser:Parse(entry.raw), entry.expect, FIELDS, entry.id) end
assert(#REAL > 150, "the real lines were all there")
assertEq(Parser:Parse(""), nil, "empty line")
assertEq(Parser:Parse(Secret(real("spell"))), nil, "hidden text isn't read")
assertEq(Parser:Parse(nil), nil, "no text at all")

step("reading them without the game's text (built-in English)")
-- The links alone say what happened, whatever the language
WithoutGameText(function()
    local bare = {}
    load_file(ADDON_DIR .. "/Parse.lua", bare)
    bare.Parser:Init()
    local basics = { "kind", "fromMe", "toMe", "melee", "spell", "spellId", "amount", "unit", "crit", "blocked",
        "absorbed", "resisted", "overkill", "overheal" }
    for _, entry in ipairs(REAL) do
        sameParse(bare.Parser:Parse(entry.raw), entry.expect, basics, entry.id .. " (no game text)")
    end
    assertEq(bare.Parser:Parse(real("swing fails: DODGE")).missType, "DODGE", "a dodge, from the built-in words")
    assertEq(bare.Parser:Parse(real("spell fails: RESIST")).missType, "RESIST", "a resist, from the built-in words")
end)

step("reading the words when a line has no links")
-- What's left when the links and colours are taken away: the text as it looks
-- on screen. Your own lines read the same; anyone else's lose the spell name,
-- because it runs into their (scrambled) name.
local function onScreen(raw)
    return (raw:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"))
end
assertEq(onScreen(real("spell")), "Your Claw hit Bristleback Hunter Fizzlesticks 50 Physical. (1 Blocked) ", "as seen in game")
local NO_ID = { "kind", "fromMe", "toMe", "melee", "spell", "amount", "unit", "crit", "glancing", "crushing", "split",
    "blocked", "absorbed", "resisted", "overkill", "overheal", "missType" }
local THEIRS = { "kind", "fromMe", "toMe", "melee", "amount", "unit", "crit", "crushing", "blocked", "absorbed", "resisted",
    "missType" }
-- Too little is left of these to tell them apart by words alone
local WORDS_CANT = {
    ["spell name with an action word"] = true,   -- "Your Critical hit Proc hit ..."
    ["the world, nobody named"] = true,          -- "Falling damaged You ..." (no "Unknown" in front)
    ["I die (a death recap link, not a sentence)"] = true,
}
local readByWords = 0
for _, entry in ipairs(REAL) do
    local expect, id = entry.expect, entry.id .. " (words)"
    if not WORDS_CANT[entry.id] and not entry.id:find("^look: ") then
        local got = Parser:Parse(onScreen(entry.raw))
        if expect == nil then
            assertEq(got, nil, id .. ": nothing to show")
        elseif expect.kind == "interrupt" or expect.kind == "dispel" or expect.kind == "died" then
            assertEq(got and got.kind, expect.kind, id .. ": kind")
        elseif expect.fromMe then
            sameParse(got, expect, NO_ID, id)
        elseif expect.kind == "kill" then
            assertEq(got and got.fromMe, nil, id .. ": not my kill")
        else
            sameParse(got, expect, THEIRS, id)
        end
        readByWords = readByWords + 1
    end
end
assert(readByWords > 130, "nearly every line can be read by its words")
local p = Parser:Parse(onScreen(real("look: timestamps")))
assertEq(p.fromMe, true, "a timestamp in front doesn't hide whose line it is"); assertEq(p.amount, 50, "timestamp: amount")
p = Parser:Parse(onScreen(real("look: braces around names and spells")))
assertEq(p.fromMe, true, "braces: mine"); assertEq(p.spell, "Claw", "braces: spell"); assertEq(p.crit, true, "braces: crit")
assertEq(Parser:Parse("Stormsnout dies, you gain 103 experience."), nil, "not a combat line")

---------------------------------------------------------------------------
step("load and log in")
fire("ADDON_LOADED", ADDON)
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
assert(BT.areas.incoming and BT.areas.outgoing and BT.areas.notify, "three text areas")
assertEq(BT.db.enabled, true, "on by default")
assertEq(BT.areas.outgoing.mover:IsShown(), false, "areas are locked by default")
for _, name in ipairs(bindingNames) do
    local button = name:match("^CLICK (%S+):LeftButton$")
    if button then assert(_G[button] and _G[button].__protected, "the keybinding's button exists and is secure: " .. button) end
end
assertClean("after logging in")

-- A combat log line reaches addons only when the game is writing them: its
-- filter is loaded and the lines are turned on
local function flowing() return STATE.filterApplied and STATE.filteredEvents and not STATE.logBroken end
local function log(line, order)
    if not flowing() then return false end
    fire("COMBAT_LOG_MESSAGE", line, 1, 1, 1, order or Enum.CombatLogMessageOrder.Newest)
    return true
end

step("start button: the combat log needs opening once")
local start = BT.startButton
assertEq(start:IsShown(), true, "Start button shows after login")
assertEq(BT.started, nil, "not started yet")
assertEq(log(swing(27)), false, "the game isn't writing lines yet")
-- History replayed when the game refills the Combat Log window isn't a sign of life
fire("COMBAT_LOG_MESSAGE", swing(27), 1, 1, 1, Enum.CombatLogMessageOrder.Oldest)
assertEq(start:IsShown(), true, "old lines don't hide the button")
assertEq(#lines("outgoing"), 0, "and aren't shown")

ClickButton(start)
assertEq(STATE.filterApplied, true, "the click opened the Combat Log tab (the game loaded its filter)")
assertEq(SELECTED_DOCK_FRAME, ChatFrame1, "and went back to the tab you were on")
assertEq(ChatFrame2:IsShown(), false, "the Combat Log is hidden again")
assertEq(STATE.filteredEvents, true, "BattleText turned the lines back on after the game turned them off")
assertEq(BT.started, true, "started")
assertEq(start:IsShown(), false, "Start button gone")
assertClean("after the Start click")
assertEq(log(swing(27)), true, "lines arrive now")
clear()
-- The game turns the lines off whenever its window hides; they come back
STATE.filteredEvents = false
Advance(3.1)
assertEq(STATE.filteredEvents, true, "BattleText keeps the lines on")
SECURE = true   -- (your own clicks on the tabs)
ChatFrame2Tab.__scripts.OnClick(ChatFrame2Tab, "LeftButton")   -- you look at the Combat Log yourself...
ChatFrame1Tab.__scripts.OnClick(ChatFrame1Tab, "LeftButton")   -- ...and go back
SECURE = false
assertEq(STATE.filteredEvents, true, "still on after you close the Combat Log")

---------------------------------------------------------------------------
step("your hits")
BT.db.icons = false
log(swing(27))
assertEq(last("outgoing"), "27", "a swing shows its number")
Advance(1)
log(hit("Claw", 16827, 50, "Physical", "(1 Blocked)"))
assertEq(last("outgoing"), "Claw 50 |cffb0b0b0(1 blocked)|r", "a spell shows its name, number and what was blocked")
assertEq(#lines("incoming"), 0, "nothing in the incoming area")
BT.db.spellNames = false
Advance(1)
log(hit("Claw", 16827, 50))
assertEq(last("outgoing"), "50", "spell names off")
BT.db.spellNames, BT.db.icons = true, true
Advance(1)
log(hit("Claw", 16827, 51))
assertEq(last("outgoing"), "|T132140:0|t Claw 51", "spell icon, found by the spell's ID")
BT.db.icons = false
Advance(1)
log(hit("Fireball", 133, 1234, "Fire"))
assertEq(last("outgoing"), "Fireball 1,234", "thousands")
assertEq(BT.areas.outgoing.active[#BT.areas.outgoing.active].text.__color[2], 0.5, "tinted by its school (fire)")
clear()

step("rapid hits add up")
log(hit("Swipe", 779, 40))
log(hit("Swipe", 779, 45))
log(hit("Swipe", 779, 50))
assertEq(#lines("outgoing"), 1, "one line for three hits")
assertEq(last("outgoing"), "Swipe 135 |cffb0b0b0(x3)|r", "total and count")
Advance(1.5)
log(hit("Swipe", 779, 40))
assertEq(#lines("outgoing"), 2, "a later hit is its own line")
BT.db.merge = false
clear()
log(hit("Swipe", 779, 40))
log(hit("Swipe", 779, 45))
assertEq(#lines("outgoing"), 2, "adding up turned off")
BT.db.merge = true
clear()

step("crits are bigger and hold")
log(hit("Claw", 16827, 100, "Physical", "(Critical)"))
local crit = BT.areas.outgoing.active[1]
assertEq(crit.sticky, true, "sticky")
assertEq(crit.text.__font[2], 30, "150% of the text size")
log(hit("Claw", 16827, 40))
assertEq(#lines("outgoing"), 2, "a normal hit right after is its own line")
assertEq(crit.text:GetText(), "Claw 100", "and leaves the crit's number alone")
log(hit("Claw", 16827, 110, "Physical", "(Critical)"))
assertEq(BT.areas.outgoing.active[3].slot, 1, "a second crit stacks above the first")
Advance(0.5)
assertEq(crit.__scale, 1, "settled after the pop")
clear()
-- A crit every second: each one takes the lowest free place, so they don't climb
local highest = 0
for i = 1, 12 do
    log(hit("Claw", 16827, 100 + i, "Physical", "(Critical)"))
    for _, o in ipairs(BT.areas.outgoing.active) do highest = math.max(highest, o.slot or 0) end
    Advance(1)
end
assert(highest <= 1, "crits a second apart stay in the bottom two places (got " .. highest .. ")")
BT.db.sticky = false
clear()
log(hit("Claw", 16827, 100, "Physical", "(Critical)"))
assertEq(BT.areas.outgoing.active[1].sticky, false, "sticky off: crits scroll, still bigger")
assertEq(BT.areas.outgoing.active[1].text.__font[2], 30, "still bigger")
BT.db.sticky = true
clear()

step("heals and small hits")
log(real("heal on a friend"))
assertEq(last("outgoing"), "Rejuvenation +61", "a heal on someone else")
log(real("heal on a friend, overheal, crit"))
assertEq(last("outgoing"), "Flash Heal +1,034 |cffb0b0b0(200 over)|r", "overhealing is noted")
BT.db.minDamage = 30
log(swing(12))
assertEq(last("outgoing"), "Flash Heal +1,034 |cffb0b0b0(200 over)|r", "hits below the limit are hidden")
BT.db.minDamage = 0
BT.db.outHeals = false
log(real("heal on a friend"))
assertEq(#lines("outgoing"), 2, "heals turned off")
BT.db.outHeals = true
clear()

step("misses, when the Combat Log's filter includes them")
log(real("swing fails: DODGE"))
assertEq(last("outgoing"), "Dodge", "a dodged swing")
log(real("swing fails: MISS"))
assertEq(last("outgoing"), "Miss", "a plain miss")
log(real("swing fails: BLOCK"))
assertEq(last("outgoing"), "Block", "blocked")
log(real("spell fails: RESIST"))
assertEq(last("outgoing"), "Moonfire Resist", "a resisted spell")
log(real("spell fails: IMMUNE"))
assertEq(last("outgoing"), "Moonfire Immune", "immune")
log(real("tick fails: PARRY"))
assertEq(last("outgoing"), "Rend Parry", "a parried tick")
BT.db.outMisses = false
log(real("swing fails: DODGE"))
assertEq(last("outgoing"), "Rend Parry", "misses turned off")
BT.db.outMisses = true
clear()

---------------------------------------------------------------------------
step("what happens to you, without the combat log")
fire("UNIT_COMBAT", "player", "WOUND", "", 23, 1)
assertEq(last("incoming"), "-23", "a hit on you")
fire("UNIT_COMBAT", "player", "WOUND", "CRITICAL", 58, 1)
assertEq(BT.areas.incoming.active[2].sticky, true, "a crit on you holds")
fire("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
assertEq(last("incoming"), "Dodge", "you dodged")
fire("UNIT_COMBAT", "player", "WOUND", "ABSORB", 0, 1)
assertEq(last("incoming"), "Absorb", "a hit fully absorbed")
fire("UNIT_COMBAT", "player", "WOUND", "", 0, 1)
assertEq(last("incoming"), "Miss", "a hit for nothing")
fire("UNIT_COMBAT", "target", "WOUND", "", 99, 1)
assertEq(#lines("incoming"), 5, "other units are ignored")
fire("UNIT_COMBAT", "player", "WOUND", "", Secret(40), 1)
assertEq(last("incoming"), "<secret fmt>", "a hidden amount is still shown by the game")
clear()
fire("UNIT_COMBAT", "player", "HEAL", "", 120, 8)
Advance(0.3)
assertEq(last("incoming"), "+120", "a heal on you")
fire("UNIT_COMBAT", "player", "ENERGIZE", "", 10, 1)
assertEq(last("incoming"), "+120", "power gains are off by default")
BT.db.inPower = true
fire("UNIT_COMBAT", "player", "ENERGIZE", "", 10, 1)
assertEq(last("incoming"), "+10 Rage", "a power gain")
BT.db.inPower = false
BT.db.inMisses = false
fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
assertEq(last("incoming"), "+10 Rage", "avoids turned off")
BT.db.inMisses = true
clear()

step("your own heals aren't shown twice")
fire("UNIT_COMBAT", "player", "HEAL", "", 380, 8)
log(healMe("Healing Touch", 5185, 380, "(120 Overhealed)"))
Advance(0.3)
assertEq(#lines("incoming"), 1, "one line")
assertEq(last("incoming"), "+380 Healing Touch |cffb0b0b0(120 over)|r", "with the spell's name")
assertEq(#lines("outgoing"), 0, "and not in the outgoing area as well")
clear()
BT.db.inHeals = false
fire("UNIT_COMBAT", "player", "HEAL", "", 380, 8)
log(healMe("Healing Touch", 5185, 380))
Advance(0.3)
assertEq(#lines("incoming"), 0, "incoming heals off")
assertEq(last("outgoing"), "Healing Touch +380", "your own heal still counts as something you did")
BT.db.inHeals = true
clear()
log(real("heal on myself, all overheal"))
assertEq(#lines("incoming"), 0, "a heal that was all overhealing isn't shown")
Advance(1)

step("damage you do to yourself is shown once")
fire("UNIT_COMBAT", "player", "WOUND", "", 30, 4)
log(real("spell at myself"))
assertEq(#lines("incoming"), 1, "once, as damage taken")
assertEq(#lines("outgoing"), 0, "not as a hit")
clear()

step("what happens to you, when the combat log shows it")
-- The player picked a filter that includes it ("What happened to me?")
fire("UNIT_COMBAT", "player", "WOUND", "", 12, 1)
log(real("swing at me"))
assert(BT:LogDelivers("damage"), "the log covers damage you take")
fire("UNIT_COMBAT", "player", "WOUND", "", 84, 4)
log(hitMe("Fireball", 133, 84, "Fire"))
local inc = lines("incoming")
assertEq(inc[#inc], "-84 Fireball", "with the spell's name")
assertEq(#inc, 3, "the second hit is shown once")
-- That filter has no misses, so your dodges still come from UNIT_COMBAT
fire("UNIT_COMBAT", "player", "WOUND", "", 20, 1)
log(hitMe("Fireball", 133, 20, "Fire"))
fire("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
assertEq(last("incoming"), "Dodge", "a dodge between two hits isn't swallowed")
clear()
-- A filter that has misses too: then they come from the log, once
log(real("swing at me fails: PARRY"))
assertEq(last("incoming"), "Parry", "an avoided swing, from the log")
fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
assertEq(#lines("incoming"), 1, "and not again from UNIT_COMBAT")
log(real("spell at me fails: RESIST"))
assertEq(last("incoming"), "Resist Fireball", "a resisted spell, with its name")
-- The player switches back to "My actions": no more incoming lines in the log
for _ = 1, 4 do fire("UNIT_COMBAT", "player", "WOUND", "", 10, 1) end
assertEq(BT:LogDelivers("damage"), false, "noticed the log stopped covering it")
assertEq(last("incoming"), "-10", "UNIT_COMBAT takes over again")
for _ = 1, 4 do fire("UNIT_COMBAT", "player", "DODGE", "", 0, 1) end
assertEq(last("incoming"), "Dodge", "for avoids too")
clear()

---------------------------------------------------------------------------
step("old and hidden lines")
log(hit("Claw", 16827, 50), Enum.CombatLogMessageOrder.Oldest)
assertEq(#lines("outgoing"), 0, "replayed history isn't shown")
log(Secret(hit("Claw", 16827, 50)))
assertEq(last("outgoing"), "<secret fmt>", "hidden text is shown as it is")
clear()

step("lines scroll, keep their distance and go away")
log(hit("Claw", 16827, 50))
log(hit("Bite", 17253, 60))
log(hit("Rake", 1822, 70))
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
-- A burst of different things at once: nothing waits long, and no two lines
-- start closer together than a line's height
local function spacing(area)
    local a = BT.areas[area]
    local speed = BT:AreaHeight(a) / BT:ScrollTime(a)
    local starts = {}
    for _, o in ipairs(a.active) do if not o.sticky then starts[#starts + 1] = { o.start, o.size } end end
    table.sort(starts, function(x, y) return x[1] < y[1] end)
    local closest = math.huge
    for i = 2, #starts do
        closest = math.min(closest, (starts[i][1] - starts[i - 1][1]) * speed - math.max(starts[i][2], starts[i - 1][2]))
    end
    return closest, starts[#starts][1] - GetTime()
end
for i = 1, 12 do log(hit("Spell" .. i, 1000 + i, 5)) end
local closest, wait = spacing("outgoing")
assert(closest >= 1.9, "a burst never puts two lines on top of each other (gap " .. closest .. ")")
assert(wait <= 1.21, "and the newest never waits more than a moment (" .. wait .. ")")
clear()
BT.db.sticky = false
log(hit("Claw", 16827, 50))
log(hit("Bite", 17253, 100, "Physical", "(Critical)"))   -- taller text needs more room
log(hit("Rake", 1822, 70))
closest = spacing("outgoing")
assert(closest >= 1.9, "a bigger line gets a bigger gap on both sides (gap " .. closest .. ")")
BT.db.sticky = true
clear()

---------------------------------------------------------------------------
step("notifications")
fire("PLAYER_REGEN_DISABLED")
assertEq(last("notify"), "+Combat", "entering combat")
fire("PLAYER_REGEN_ENABLED")
assertEq(last("notify"), "-Combat", "leaving combat")
log(real("my kill"))
assertEq(last("notify"), "Killing blow!", "killing blow")
log(real("pet's kill"))
assertEq(#lines("notify"), 3, "the pet's kill isn't yours")
STATE.xp = 203
fire("PLAYER_XP_UPDATE")
assertEq(last("notify"), "+103 XP", "experience")
STATE.xp, STATE.xpMax = 50, 1200   -- levelled up: 797 to finish the level, 50 into the next
fire("PLAYER_XP_UPDATE")
assertEq(last("notify"), "+847 XP", "experience across a level")
clear()
fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:2589::::::::20:::::|h[Linen Cloth]|h|rx2.")
assertEq(last("notify"), "+2 |cffffffff|Hitem:2589::::::::20:::::|h[Linen Cloth]|h|r", "your loot")
fire("CHAT_MSG_LOOT", "You receive loot: |cnIQ1:|Hitem:2589::::::::20:::::|h[Linen Cloth]|h|r.")
assertEq(last("notify"), "+1 |cnIQ1:|Hitem:2589::::::::20:::::|h[Linen Cloth]|h|r", "the newer way the game colours item links")
fire("CHAT_MSG_LOOT", "You create: |cffffffff|Hitem:2840::::::::20:::::|h[Copper Bar]|h|r.")
assertEq(last("notify"), "+1 |cffffffff|Hitem:2840::::::::20:::::|h[Copper Bar]|h|r", "something you made")
fire("CHAT_MSG_LOOT", "Anduin receives loot: |cffffffff|Hitem:2589::::::::20:::::|h[Linen Cloth]|h|r.")
assertEq(#lines("notify"), 3, "someone else's loot isn't shown")
-- Six things looted at once all fit, one under the other
for i = 1, 6 do fire("CHAT_MSG_LOOT", "You receive loot: |cffffffff|Hitem:" .. i .. "::::|h[Thing " .. i .. "]|h|r.") end
closest = spacing("notify")
assert(closest >= 1.9, "a pile of loot doesn't land on one spot (gap " .. closest .. ")")
clear()
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
step("pet lines, when the Combat Log's filter includes your pet")
log(real("pet's spell"))
assertEq(#lines("outgoing"), 0, "no pet out: someone else's hit")
STATE.pet = true
log(real("pet's spell"))
assertEq(last("outgoing"), "Bite (Pet) 20", "your pet's hit")
log(real("pet's swing"))
assertEq(last("outgoing"), "(Pet) 20", "your pet's swing")
Advance(1)
log(real("swing at the pet"))
assertEq(#lines("outgoing"), 2, "a hit on your pet isn't your pet's hit")
assertEq(last("outgoing"), "(Pet) 20", "and isn't added to one either")
BT.db.outPet = false
log(real("pet's spell"))
assertEq(#lines("outgoing"), 2, "pet turned off")
BT.db.outPet = true
STATE.pet = false
clear()

step("debug: every line, exactly as the game sent it")
SlashCmdList.BATTLETEXTFOREVER("debug")
log(real("spell"))
log(real("cast"))
local sawRead, sawSkipped
for _, l in ipairs(LOG) do
    if l:find("BattleText read:", 1, true) and l:find("||Hspell:16827:0:SPELL_DAMAGE||h", 1, true) then sawRead = true end
    if l:find("BattleText skipped:", 1, true) and l:find("SPELL_CAST_SUCCESS", 1, true) then sawSkipped = true end
end
assert(sawRead, "a line that was shown is printed with its links readable")
assert(sawSkipped, "and so is one that wasn't")
SlashCmdList.BATTLETEXTFOREVER("debug")
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
assertEq(STATE.filteredEvents, false, "turned off: the lines are left the way the game has them")
Advance(3.1)
assertEq(STATE.filteredEvents, false, "and stay that way")
STATE.filteredEvents = true   -- (say you're looking at the Combat Log)
log(hit("Claw", 16827, 50))
assertEq(#lines("outgoing"), 0, "nothing while turned off")
assertEq(start:IsShown(), false, "no Start button while turned off")
BT.db.minDamage = 40
SlashCmdList.BATTLETEXTFOREVER("test")
Advance(2.6)
assert(#lines("outgoing") >= 4 and #lines("incoming") > 0 and #lines("notify") > 0,
    "sample text shows even when off, whatever \"Hide hits below\" says")
assertEq(BT.db.minDamage, 40, "and your settings are untouched")
BT.db.minDamage = 0
SlashCmdList.BATTLETEXTFOREVER("on")
assertEq(STATE.filteredEvents, true, "back on")
clear()

step("the game's own numbers")
BT.db.hideBlizzard = true
BT:ApplySettings()
assertEq(STATE.cvars.floatingCombatTextCombatDamage, "0", "turned off")
SlashCmdList.BATTLETEXTFOREVER("off")
assertEq(STATE.cvars.floatingCombatTextCombatDamage, "1", "BattleText off: the game's numbers come back")
SlashCmdList.BATTLETEXTFOREVER("on")
assertEq(STATE.cvars.floatingCombatTextCombatDamage, "0", "and go again")
fire("PLAYER_LOGOUT")
assertEq(STATE.cvars.floatingCombatTextCombatDamage, "1", "logging out leaves the game's setting as it was")
BT:ApplySettings()   -- (logging back in)
assertEq(STATE.cvars.floatingCombatTextCombatDamage, "0", "hidden again next time")
BT.db.hideBlizzard = false
BT:ApplySettings()
assertEq(STATE.cvars.floatingCombatTextCombatDamage, "1", "option off: put back as it was")
assertEq(BT.db.savedCVars, nil, "nothing left over")
STATE.cvars.enableFloatingCombatText = "0"   -- one of them was off already
BT.db.hideBlizzard = true
BT:ApplySettings()
BT.db.hideBlizzard = false
BT:ApplySettings()
assertEq(STATE.cvars.enableFloatingCombatText, "0", "one you had off stays off")
assertEq(STATE.cvars.floatingCombatTextCombatHealing, "1", "the others come back")
STATE.cvars.enableFloatingCombatText = "1"

step("combat lockdown")
-- As after a /reload: not started, and you're already fighting
BT.started = nil
STATE.filterApplied, STATE.filteredEvents = false, false
COMBAT, BLOCKED = true, {}
BT:UpdateStartButton()
BT:SetStartMacro()
BT:ApplySettings()
fire("UNIT_COMBAT", "player", "WOUND", "", 23, 1)
Advance(1)
assertEq(#BLOCKED, 0, "protected frame touched in combat: " .. table.concat(BLOCKED, ", "))
assertEq(start:IsShown(), false, "the Start button can't appear mid-fight")
COMBAT = false
fire("PLAYER_REGEN_ENABLED")
assertEq(start:IsShown(), true, "it appears when the fight ends")
-- With "act on key down" set, the click works on the press instead of the release
STATE.useKeyDown = true
ClickButton(start)
STATE.useKeyDown = false
assertEq(STATE.filterApplied, true, "the click works with key-down casting too")
assertEq(start:IsShown(), false, "started")
assertEq(log(swing(27)), true, "lines arrive")
-- Clicked in the middle of a fight: it works, and the button goes when the fight ends
BT.started = nil
STATE.filterApplied, STATE.filteredEvents = false, false
BT:UpdateStartButton()
assertEq(start:IsShown(), true, "shown again")
COMBAT, BLOCKED = true, {}
ClickButton(start)
assertEq(STATE.filterApplied, true, "the click works in combat")
assertEq(log(swing(27)), true, "lines arrive in combat")
assertEq(#BLOCKED, 0, "protected frame touched in combat: " .. table.concat(BLOCKED, ", "))
assertEq(start:IsShown(), true, "the button waits for the fight to end")
COMBAT = false
fire("PLAYER_REGEN_ENABLED")
assertEq(start:IsShown(), false, "then goes")
clear()

step("options window")
BT:OpenConfig()
assertEq(BT.config:IsShown(), true, "opens")
assertEq(UISpecialFrames[#UISpecialFrames], "BattleTextForeverOptions", "Escape closes it")
-- Click every checkbox twice: nothing errors, and the settings end where they began
local before = {}
for k, v in pairs(BT.db) do before[k] = v end
local boxes = 0
for _, f in ipairs(ALL_FRAMES) do
    if f.__kind == "CheckButton" and f.__scripts.OnClick then
        boxes = boxes + 1
        local changed = false
        f:SetChecked(not f:GetChecked()); f.__scripts.OnClick(f)
        for k, v in pairs(before) do
            if type(v) == "boolean" and BT.db[k] ~= v then changed = true end
        end
        assert(changed, "a checkbox that changes no setting")
        f:SetChecked(not f:GetChecked()); f.__scripts.OnClick(f)
    end
end
assert(boxes >= 20, "the checkboxes are there")
for k, v in pairs(before) do
    if type(v) ~= "table" then assertEq(BT.db[k], v, "setting unchanged: " .. k) end
end
-- Every slider writes the setting it's labelled with
local sliders = 0
for _, f in ipairs(ALL_FRAMES) do
    if f.__kind == "Slider" and f.__scripts.OnValueChanged then
        sliders = sliders + 1
        local snapshot = {}
        for k, v in pairs(BT.db) do snapshot[k] = v end
        f.__scripts.OnValueChanged(f, f.__max)
        local moved = {}
        for k, v in pairs(snapshot) do
            if type(v) == "number" and BT.db[k] ~= v then moved[#moved + 1] = k end
        end
        assertEq(#moved, 1, "a slider changes exactly one setting")
        do
            assertEq(BT.db[moved[1]], f.__max, "slider set " .. moved[1])
            assert(f.label and f.label:lower():find(({ fontSize = "text size", critScale = "crit size",
                scrollTime = "scroll time", height = "scroll distance", minDamage = "hide hits below" })[moved[1]], 1, true),
                "slider label matches its setting: " .. tostring(f.label) .. " -> " .. moved[1])
            f.__scripts.OnValueChanged(f, snapshot[moved[1]])
        end
    end
end
assertEq(sliders, 5, "five sliders")
for k, v in pairs(before) do
    if type(v) ~= "table" then assertEq(BT.db[k], v, "setting unchanged after the sliders: " .. k) end
end
BT:OpenConfig()
assertEq(BT.config:IsShown(), false, "closes")

assertClean("by the end")
print("ALL TESTS PASSED")
