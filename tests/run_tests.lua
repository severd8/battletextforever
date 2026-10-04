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
    BT:FlushHits(true)   -- (hits are worked out when their frame is over: looking is the end of the frame)
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
-- Other ways of writing big numbers (other languages)
for _, written in ipairs({ "1.234", "1 234", "1\194\160234", "1'234", "1234" }) do
    local line = real("spell"):gsub("|cffffffff50|r", "|cffffffff" .. written .. "|r")
    assertEq(Parser:Parse(line).amount, 1234, "amount written as " .. written)
    assertEq(Parser:Parse(line).unit, "Physical", "and what follows it")
end
Parser:AddSeparator("\239\188\140")   -- a separator the game might name that isn't built in
assertEq(Parser:Parse((real("spell"):gsub("|cffffffff50|r", "|cffffffff1\239\188\140234|r"))).amount, 1234, "the game's own separator")
-- Told apart by the link's GUID even if the word isn't "You"
local p0 = Parser:Parse((real("spell at me"):gsub("|hYou|h", "|hAbla|h")))
assertEq(p0.toMe, true, "at me, by GUID")
p0 = Parser:Parse((real("spell"):gsub("|hYour|h", "|hAbla's|h")))
assertEq(p0.fromMe, true, "mine, by GUID")
p0 = Parser:Parse((real("spell"):gsub("Claw", "Mob [Elite]")))
assertEq(p0.spell, "Mob [Elite]", "a bracket in a name is kept")
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

step("hidden values are never compared")
-- Comparing a hidden ("secret") value throws in game, even against nil. The
-- fake game here can't make that throw, so the code is checked by eye: these
-- may hold a hidden value and must only ever be tested with IsSecret.
for _, file in ipairs(tocFiles) do
    local n = 0
    for line in (read_file(ADDON_DIR .. "/" .. file) .. "\n"):gmatch("(.-)\n") do
        n = n + 1
        local code = line:gsub("%-%-.*$", "")
        local bad = code:find("opts%.secret%s*[~=]=")
            or code:find("[^%w_%.]amount%s*[~=]=") or code:find("[^%w_%.]amount%s*[<>]")
            or (code:find("[^%w_%.]order%s*[~=]=") and not code:find("IsSecret(order)", 1, true))
            or code:find("[^%w_%.]message%s*[~=]=")
        assert(not bad, file .. ":" .. n .. " compares a value that may be hidden: " .. line)
    end
end

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

ClickTab(ChatFrame3Tab)   -- you're on your Loot tab
ClickButton(start)
assertEq(STATE.filterApplied, true, "the click opened the Combat Log tab (the game loaded its filter)")
assertEq(SELECTED_DOCK_FRAME, ChatFrame3, "and went back to the tab you were on")
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
ClickTab(ChatFrame2Tab)   -- you look at the Combat Log yourself...
ClickTab(ChatFrame1Tab)   -- ...and go back
assertEq(STATE.filteredEvents, true, "still on after you close the Combat Log")
-- Logged in with the Combat Log tab already showing: the game hasn't loaded its
-- filter (that needs a click), so the button is still there, and its click
-- leaves the tab and comes back
ClickTab(ChatFrame2Tab)
BT.started = nil
STATE.filterApplied = false
BT:UpdateStartButton()
assertEq(start:IsShown(), true, "Start button shows with the Combat Log tab open")
ClickButton(start)
assertEq(STATE.filterApplied, true, "the click reopened the tab")
assertEq(SELECTED_DOCK_FRAME, ChatFrame2, "and you're still on it")
assertEq(start:IsShown(), false, "started")
ClickTab(ChatFrame1Tab)
assertClean("after starting from the Combat Log tab")

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
clear()
-- A steady stream doesn't pile onto one line forever: after a second, a new line
for _ = 1, 4 do
    log(hit("Swipe", 779, 10))
    Advance(0.4)
end
assertEq(#lines("outgoing"), 2, "a new line after a second of adding up")
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
log(real("damage shared out"))
assertEq(#lines("outgoing"), 2, "damage shared to your pet isn't a hit of yours")
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
fire("UNIT_COMBAT", "player", "HEAL", "", Secret(120), 8)
Advance(0.3)
assertEq(last("incoming"), "<secret fmt>", "a heal with a hidden amount")
BT.db.inPower = true
local shownBefore = #lines("incoming")
fire("UNIT_COMBAT", "player", "ENERGIZE", "", Secret(10), 1)
assertEq(#lines("incoming"), shownBefore + 1, "a power gain with a hidden amount is shown")
assertEq(last("incoming"), "<secret fmt>", "by the game itself")
BT.db.inPower = false
clear()
fire("UNIT_COMBAT", "player", "HEAL", "", 120, 8)
Advance(0.3)
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

step("a friend's heal isn't shown twice when the log starts covering heals")
fire("UNIT_COMBAT", "player", "HEAL", "", 300, 2)
log(real("a friend's heal on me"))
Advance(0.3)
assertEq(#lines("incoming"), 1, "one line")
assertEq(last("incoming"), "+300 Flash Heal", "the one with the spell's name")
for _ = 1, 4 do fire("UNIT_COMBAT", "player", "HEAL", "", 50, 2) end   -- (the filter is switched back)
Advance(0.3)
assertEq(BT:LogDelivers("heal"), false, "and UNIT_COMBAT takes over again when the log stops")
clear()

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
log(real("swing at me, crushing"))
assertEq(BT.areas.incoming.active[4].sticky, true, "a crushing blow stands out like a crit")
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
assertEq(#lines("outgoing"), 0, "a line whose text the game hides isn't shown")
clear()

---------------------------------------------------------------------------
-- The game hides the text of its combat log lines (each arrives as a token
-- like |Ky7|k). Your hits are then read from UNIT_COMBAT on the unit you hit.
---------------------------------------------------------------------------
step("your hits, when the game hides its combat log lines")
local C = BT.TEXT_COLORS
local function colorOf(line) return line.text.__color[1] .. " " .. line.text.__color[2] .. " " .. line.text.__color[3] end
local function isColor(line, c) return colorOf(line) == c[1] .. " " .. c[2] .. " " .. c[3] end
local function newest() BT:FlushHits(true) local a = BT.areas.outgoing.active return a[#a] end
local function hidden(n) return log("|Ky" .. (n or 7) .. "|k") end
STATE.unit.mobA = { enemy = true, guid = "Creature-0-1-2-3-100-00000A", target = "me" }
STATE.unit.mobB = { enemy = true, guid = "Creature-0-1-2-3-100-00000B", target = "friend" }
STATE.unit.friend = { enemy = false, guid = "Player-5555-0FRIEND1" }
STATE.who.target, STATE.who.nameplate1, STATE.who.nameplate2, STATE.who.mouseover = "mobA", "mobA", "mobB", "friend"
STATE.who.targettarget = "me"
BT.hiddenSeen = nil
assertEq(hidden(), true, "a hidden line arrives")
assertEq(#lines("outgoing"), 0, "it can't be read, so it isn't shown")
assertEq(BT.hiddenSeen, true, "but it's noticed")
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(last("outgoing"), "27", "your hit on your target")
assert(isColor(newest(), C.melee), "a physical hit is white")
fire("UNIT_COMBAT", "nameplate1", "WOUND", "", 27, 1)
assertEq(#lines("outgoing"), 1, "the same hit under the unit's other name is counted once")
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(#lines("outgoing"), 2, "a second hit in the same moment is a second hit")
Advance(0.1)
fire("UNIT_COMBAT", "nameplate1", "WOUND", "", 31, 1)
fire("UNIT_COMBAT", "target", "WOUND", "", 31, 1)
assertEq(#lines("outgoing"), 3, "whichever name arrives first is the one that counts")
assertEq(last("outgoing"), "31", "with its amount")
clear()
STATE.unit.mobA.guid = nil   -- a unit whose GUID the game won't give
fire("UNIT_COMBAT", "nameplate1", "WOUND", "", 27, 1)
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(#lines("outgoing"), 1, "still once: your target counts as \"target\"")
STATE.unit.mobA.guid = Secret("Creature-0-1-2-3-100-00000A")
Advance(0.1)
fire("UNIT_COMBAT", "nameplate1", "WOUND", "", 27, 1)
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(#lines("outgoing"), 2, "and with a hidden GUID")
STATE.unit.mobA.guid = "Creature-0-1-2-3-100-00000A"
clear()
fire("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 80, 1)
assertEq(newest().sticky, true, "a crit holds")
fire("UNIT_COMBAT", "target", "WOUND", "", 44, 4)
assert(isColor(newest(), BT:SchoolColor("Fire")), "a fire hit is tinted fire")
fire("UNIT_COMBAT", "target", "WOUND", "", 44, 6)
assert(isColor(newest(), C.spell), "a hit of two schools is spell-colored")
fire("UNIT_COMBAT", "target", "WOUND", "", 44, Secret(4))
assert(isColor(newest(), C.melee), "a hidden school isn't looked at")
fire("UNIT_COMBAT", "target", "WOUND", "GLANCING", 12, 1)
assertEq(last("outgoing"), "12 |cffb0b0b0(glancing)|r", "a glancing blow says so")
fire("UNIT_COMBAT", "target", "WOUND", "", Secret(40), 1)
assertEq(last("outgoing"), "<secret fmt>", "a hidden amount is still shown by the game")
clear()
fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
assertEq(last("outgoing"), "Dodge", "your attack was dodged")
fire("UNIT_COMBAT", "target", "WOUND", "", 0, 1)
assertEq(last("outgoing"), "Miss", "a hit for nothing is a miss")
fire("UNIT_COMBAT", "target", "WOUND", "ABSORB", 0, 1)
assertEq(last("outgoing"), "Absorb", "or says what stopped it")
BT.db.outMisses = false
fire("UNIT_COMBAT", "target", "PARRY", "", 0, 1)
assertEq(#lines("outgoing"), 3, "misses turned off")
BT.db.outMisses = true
BT.db.minDamage = 40
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(#lines("outgoing"), 3, "hits below \"Hide hits below\" are hidden")
BT.db.minDamage = 0
BT.db.outDamage = false
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(#lines("outgoing"), 3, "damage turned off")
BT.db.outDamage = true
fire("UNIT_COMBAT", "target", "ENERGIZE", "", 10, 1)
assertEq(#lines("outgoing"), 3, "a mob gaining power is nothing of yours")
clear()

-- Whose fight it is
local incomingBefore = #lines("incoming")
fire("UNIT_COMBAT", "targettarget", "WOUND", "", 50, 1)
assertEq(#lines("outgoing") + #lines("incoming"), incomingBefore, "you, under another name, aren't your own target")
fire("UNIT_COMBAT", "mouseover", "WOUND", "", 50, 1)
assertEq(#lines("outgoing"), 0, "a friend being hit isn't your hit")
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 50, 1)
assertEq(#lines("outgoing"), 0, "nor is a mob that's fighting someone else")
STATE.unit.mobB.target = "me"
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 50, 1)
assertEq(last("outgoing"), "50", "a mob that's after you is your fight")
STATE.unit.mobB.target, STATE.pet = "pet", true
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 51, 1)
assertEq(last("outgoing"), "51", "so is one that's after your pet")
STATE.unit.mobB.target = "friend"
STATE.unit.pet = { target = "mobB" }
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 52, 1)
assertEq(last("outgoing"), "52", "and the one your pet is on")
STATE.unit.pet, STATE.pet = nil, false
clear()
STATE.who.target = "friend"
fire("UNIT_COMBAT", "target", "HEAL", "CRITICAL", 120, 2)
assertEq(last("outgoing"), "+120", "a heal on the friend you're targeting")
assert(isColor(newest(), C.heal), "in the heal color")
assertEq(newest().sticky, true, "a crit heal holds")
fire("UNIT_COMBAT", "target", "HEAL", "", Secret(90), 2)
assertEq(last("outgoing"), "<secret fmt>", "with a hidden amount too")
BT.db.outHeals = false
fire("UNIT_COMBAT", "target", "HEAL", "", 120, 2)
assertEq(#lines("outgoing"), 2, "heals turned off")
BT.db.outHeals = true
fire("UNIT_COMBAT", "target", "HEAL", "", 0, 2)
assertEq(#lines("outgoing"), 2, "a heal for nothing isn't shown")
STATE.who.target = "mobA"
Advance(0.1)
fire("UNIT_COMBAT", "mouseover", "HEAL", "", 120, 2)
assertEq(#lines("outgoing"), 2, "a heal on a friend you aren't targeting could be anyone's")
fire("UNIT_COMBAT", "target", "HEAL", "", 300, 2)
assertEq(#lines("outgoing"), 2, "a mob healing itself isn't your heal")
STATE.who.target = "me"
fire("UNIT_COMBAT", "target", "HEAL", "", 120, 2)
assertEq(#lines("outgoing"), 2, "a heal on yourself is shown with what happens to you, not here")
STATE.pet, STATE.who.target = true, "pet"
fire("UNIT_COMBAT", "target", "HEAL", "", 75, 2)
assertEq(#lines("outgoing"), 2, "your pet under another name is left to its own event")
STATE.who.target = "mobA"
fire("UNIT_COMBAT", "pet", "HEAL", "", 75, 2)
assertEq(last("outgoing"), "+75", "a heal on your pet")
fire("UNIT_COMBAT", "pet", "WOUND", "", 30, 1)
assertEq(#lines("outgoing"), 3, "a hit on your pet isn't your hit")
STATE.pet = false
clear()

-- The spell: a cast of yours that finishes in the very frame the hit lands
BT.db.icons = true
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1", 16827)
fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
assertEq(last("outgoing"), "|T132140:0|t Claw 100 |cffb0b0b0(x2)|r", "named, with its icon, and rapid hits of it add up")
assert(isColor(newest(), C.spell), "and spell-colored")
clear()
-- A hit of another school in that frame isn't the cast's (your damage shield answering a blow)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1b", 16827)
fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
fire("UNIT_COMBAT", "target", "WOUND", "", 3, 8)
assertEq(table.concat(lines("outgoing"), " / "), "|T132140:0|t Claw 50 / 3", "only the hit of the spell's school is named")
Advance(1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-1c", 16827)
fire("UNIT_COMBAT", "target", "WOUND", "", 4, 8)
assertEq(last("outgoing"), "4", "and next time the spell's school is remembered")
clear()
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(last("outgoing"), "27", "a hit a moment later is just a hit")
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(#lines("outgoing"), 2, "hits without a spell don't add up (they may be different things)")
Advance(0.1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-2", 16827)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-3", 8921)
fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
assertEq(last("outgoing"), "50", "two casts in one frame: no telling which it was")
Advance(0.1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-4", Secret(16827))
fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
assertEq(last("outgoing"), "50", "a hidden spell isn't named")
Advance(0.1)
BT.db.spellNames, BT.db.icons = false, false
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-5", 16827)
fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
assertEq(last("outgoing"), "Dodge", "names and icons turned off")
BT.db.spellNames, BT.db.icons = true, true
Advance(0.1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-6", 16827)
fire("UNIT_COMBAT", "target", "PARRY", "", 0, 1)
assertEq(last("outgoing"), "|T132140:0|t Claw Parry", "a named miss")
BT.db.icons = false
clear()

-- A line that can be read is shown from the line, not a second time from the unit
log(hit("Claw", 16827, 50))
fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
assertEq(#lines("outgoing"), 1, "a readable line's hit isn't shown twice")
Advance(1)
fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
assertEq(#lines("outgoing"), 1, "even when the unit reports it a second later")
Advance(0.3)
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(last("outgoing"), "27", "after that, the unit's hits show again")
clear()
log(hitMe("Fireball", 133, 84, "Fire"))
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(last("outgoing"), "27", "a readable line about someone else's hit doesn't stand in for yours")
clear()

-- In a group, anyone could have hit the mob. A hidden line says you did
-- something just then: each one vouches for one hit.
STATE.group = true
STATE.who.party1 = "friend"
BT.credits = nil
fire("UNIT_COMBAT", "target", "WOUND", "", 99, 1)
assertEq(#lines("outgoing"), 0, "in a group, a hit with no line of yours is someone else's")
Advance(0.1)
hidden(8)
Advance(0.5)
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(last("outgoing"), "27", "a hit after your line is yours (a swing lands with its animation)")
fire("UNIT_COMBAT", "target", "WOUND", "", 99, 1)
assertEq(#lines("outgoing"), 1, "one line, one hit")
Advance(0.1)
fire("UNIT_COMBAT", "target", "WOUND", "", 28, 1)
hidden(9)
assertEq(last("outgoing"), "28", "the line may arrive just after its hit, in the same frame")
assertEq(#lines("outgoing"), 2, "shown once")
fire("UNIT_COMBAT", "target", "WOUND", "", 99, 1)
assertEq(#lines("outgoing"), 2, "and the line is used up by it")
Advance(0.1)
fire("UNIT_COMBAT", "target", "WOUND", "", 29, 1)
hidden(14) hidden(15)
assertEq(#lines("outgoing"), 3, "a second line in that frame doesn't show the hit again")
fire("UNIT_COMBAT", "target", "WOUND", "", 30, 1)
assertEq(#lines("outgoing"), 4, "it vouches for the next hit instead")
clear()
BT.credits = nil
fire("UNIT_COMBAT", "target", "WOUND", "", 99, 1)
Advance(0.1)
hidden(10)
assertEq(#lines("outgoing"), 0, "a hit left waiting is forgotten by the next frame")
Advance(1.3)
fire("UNIT_COMBAT", "target", "WOUND", "", 99, 1)
assertEq(#lines("outgoing"), 0, "a line from long ago vouches for nothing")
Advance(0.1)
hidden(11) hidden(12)
fire("UNIT_COMBAT", "target", "WOUND", "", 30, 1)
fire("UNIT_COMBAT", "target", "WOUND", "", 31, 1)
fire("UNIT_COMBAT", "target", "WOUND", "", 99, 1)
assertEq(#lines("outgoing"), 2, "two lines, two hits")
assertEq(last("outgoing"), "31", "the first two")
Advance(0.1)
hidden(13)
fire("UNIT_COMBAT", "party1", "HEAL", "", 120, 2)
assertEq(last("outgoing"), "+120", "your heal on a party member you aren't targeting")
BT.hiddenSeen = nil
BT.credits, BT.waitingHits = nil, nil
fire("UNIT_COMBAT", "target", "WOUND", "", 33, 1)
assertEq(last("outgoing"), "33", "in a group before any line has arrived: hits on your target are shown")
STATE.group = false
STATE.who.party1 = nil
assertEq(BT:InGroup(), false, "not in a group")
STATE.who.party1 = "friend"
assertEq(BT:InGroup(), true, "a party member means a group, whatever the game says")
STATE.who = {}
clear()

---------------------------------------------------------------------------
step("ticks, and your damage shield")
STATE.unit.mobA = { enemy = true, guid = "Creature-0-1-2-3-100-00000A", target = "me" }
STATE.who.target, STATE.who.nameplate1 = "mobA", "mobA"
BT.hiddenSeen, BT.hiddenAt, BT.credits, BT.dots, BT.spellSchool = nil, nil, nil, nil, nil
local function cast(id) fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-x", id) end
local function wound(amount, school, flag) fire("UNIT_COMBAT", "target", "WOUND", flag or "", amount, school or 1) end
-- With the hidden lines arriving, a tick is the hit with a line right behind it, on its spell's beat
hidden(20)
cast(1822)   -- Rake: hits, then bleeds every 3 seconds
hidden(21)
wound(35)
assertEq(last("outgoing"), "Rake 35", "the cast's own hit")
Advance(2)
wound(28) hidden(22)
assertEq(last("outgoing"), "28", "off the beat: not a tick")
Advance(1)
hidden(23) wound(27)
assertEq(last("outgoing"), "27", "on the beat, but its line came first: a swing that landed with the next swing's line")
wound(14)
BT:FlushHits()   -- (a look in the middle of the frame works nothing out yet)
hidden(24)
assertEq(last("outgoing"), "Rake 14", "on the beat, with its line behind it: Rake's tick")
assert(isColor(newest(), C.spell), "spell-colored")
Advance(3)
wound(14) wound(27) hidden(124)
assertEq(table.concat(lines("outgoing"), " / "):match("Rake 14 / 27$"), "Rake 14 / 27", "one line vouches for one tick")
Advance(3)
wound(14, 8) hidden(25)
assertEq(last("outgoing"), "14", "a nature hit isn't a bleed's tick")
Advance(3)
STATE.who.target = "mobB"
STATE.unit.mobB = { enemy = true, guid = "Creature-0-1-2-3-100-00000B", target = "me" }
wound(14) hidden(26)
assertEq(last("outgoing"), "14", "another mob isn't bleeding")
STATE.who.target = "mobA"
Advance(3)
cast(1079)   -- Rip: only bleeds, every 2 seconds
hidden(27)
wound(30)
assertEq(last("outgoing"), "30", "a spell that only ticks doesn't name a hit in its cast's frame")
wound(13) hidden(28)
assertEq(last("outgoing"), "Rake 13", "(Rake still ticking, 15 seconds on)")
Advance(2)
wound(9) hidden(29)
assertEq(last("outgoing"), "Rip 9", "Rip's first tick, two seconds on")
Advance(1)
wound(13) hidden(30)
assertEq(last("outgoing"), "Rake 13", "two bleeds: the one whose beat it is")
Advance(30)
wound(13) hidden(31)
assertEq(last("outgoing"), "13", "a bleed is forgotten 45 seconds after its cast (48 on, and on Rake's beat)")
clear()
-- Two bleeds both near their beat: the nearer one
cast(1822) hidden(40) wound(35)
Advance(0.8)
cast(1079) hidden(41)
Advance(2.2)
wound(13) hidden(42)
assertEq(last("outgoing"), "Rake 13", "Rake dead on its beat, Rip a little off: Rake")
Advance(3)
cast(1822) hidden(43) wound(35)
Advance(3.8)
cast(1079) hidden(44)
Advance(2)
wound(9) hidden(45)
assertEq(last("outgoing"), "Rip 9", "Rip dead on its beat, Rake a little off: Rip")
BT.dots = nil
clear()
-- A cast that's parried put nothing on the mob
cast(1079)
fire("UNIT_COMBAT", "target", "PARRY", "", 0, 1)
hidden(32)
assertEq(last("outgoing"), "Rip Parry", "the miss is named")
Advance(2)
wound(9) hidden(33)
assertEq(last("outgoing"), "9", "and there's no tick to name")
clear()
-- Without the lines, a bleed's tick can't be told from a swing; another school's can
BT.hiddenSeen, BT.hiddenAt = nil, nil
cast(1822)
wound(35)
Advance(3)
wound(14)
assertEq(last("outgoing"), "14", "no lines: a physical hit on the beat is left unnamed")
cast(8921)   -- Moonfire: arcane, hits and then ticks every 3 seconds
wound(20, 64)
assertEq(last("outgoing"), "Moonfire 20", "Moonfire lands")
Advance(3)
wound(8, 64)
assertEq(last("outgoing"), "Moonfire 8", "no lines: an arcane hit on Moonfire's beat is its tick")
wound(8, Secret(64))
assertEq(last("outgoing"), "8", "a hidden school isn't guessed at")
clear()
-- No GUID for the mob: your target is still followed
STATE.unit.mobA.guid = nil
cast(8921)
wound(20, 64)
Advance(3)
wound(8, 64)
assertEq(last("outgoing"), "Moonfire 8", "ticks are followed on your target without a GUID")
STATE.unit.mobA.guid = "Creature-0-1-2-3-100-00000A"
clear()

-- Your damage shield: read from your buffs, learned from two answers to a blow
BT.db.shieldAmounts = {}
STATE.buffs = { { name = "Mark of the Wild", spellId = 1126 }, { name = "Thorns", spellId = 782 } }
fire("UNIT_AURA", "player")
assertEq(BT.shield and BT.shield.name, "Thorns", "Thorns is on you")
assertEq(BT.shield.id, 782, "the rank you're wearing (for its icon)")
wound(3, 8)
assertEq(last("outgoing"), "3", "the first answer isn't known yet")
Advance(0.6)
fire("UNIT_COMBAT", "player", "WOUND", "", 20, 1)   -- the blow it answered, shown a moment later
Advance(1)
wound(3, 8)
assertEq(last("outgoing"), "3", "nor the second")
Advance(0.6)
fire("UNIT_COMBAT", "player", "WOUND", "", 21, 1)
assertEq(BT.db.shieldAmounts.Thorns, 3, "two answers of the same size: learned, and kept")
Advance(1)
wound(3, 8)
assertEq(last("outgoing"), "Thorns 3", "from then on it's named")
assert(isColor(newest(), BT:SchoolColor("Nature")), "in its school's color")
wound(3, 8)
assertEq(last("outgoing"), "Thorns 6 |cffb0b0b0(x2)|r", "two mobs hitting you at once add up")
wound(45, 8)
assertEq(last("outgoing"), "45", "a nature hit of another size is something else (a spell of yours landing)")
wound(3, 4)
assertEq(last("outgoing"), "3", "and so is a hit of another school")
clear()
BT.db.outShields = false
wound(3, 8)
assertEq(#lines("outgoing"), 0, "Damage shields unticked: hidden")
wound(27)
assertEq(last("outgoing"), "27", "your own hits still show")
BT.db.outShields = true
clear()
-- In a fight the game hides your buffs: the last answer stands
STATE.buffsHidden = true
fire("UNIT_AURA", "player")
wound(3, 8)
assertEq(last("outgoing"), "Thorns 3", "buffs hidden: still known")
STATE.buffsHidden = false
STATE.buffs = { Secret({ name = "x" }) }
fire("UNIT_AURA", "player")
assertEq(BT.shield.name, "Thorns", "a hidden buff tells nothing")
STATE.buffs = { { name = Secret("Thorns") } }
fire("PLAYER_REGEN_DISABLED")
assertEq(BT.shield.name, "Thorns", "nor a hidden name")
STATE.buffs = { { name = "Lightning Shield", spellId = 324 } }
fire("PLAYER_REGEN_DISABLED")
assertEq(BT.shield.name, "Lightning Shield", "your buffs are looked at as a fight starts")
STATE.buffs = { { name = "Mark of the Wild", spellId = 1126 } }
fire("PLAYER_ENTERING_WORLD")
assertEq(BT.shield, nil, "it wore off")
Advance(1)
wound(3, 8)
assertEq(last("outgoing"), "3", "no shield on you: just a hit")
cast(324)   -- Lightning Shield, put up mid-fight
assertEq(BT.shield.name, "Lightning Shield", "a shield you cast is known at once")
BT.db.shieldAmounts["Lightning Shield"] = 13
Advance(1)
wound(13, 8)
assertEq(last("outgoing"), "Lightning Shield 13", "and named")
-- A new rank hits for more: learned again, the same way
wound(16, 8)
Advance(0.5)
fire("UNIT_COMBAT", "player", "WOUND", "", 20, 1)
Advance(1)
wound(15, 8)
Advance(0.5)
fire("UNIT_COMBAT", "player", "WOUND", "", 20, 1)
assertEq(BT.db.shieldAmounts["Lightning Shield"], 13, "two answers of different sizes teach nothing")
Advance(1)
wound(16, 8)
Advance(1.5)
fire("UNIT_COMBAT", "player", "WOUND", "", 20, 1)
assertEq(BT.db.shieldAmounts["Lightning Shield"], 13, "nor does one with no blow behind it")
Advance(1)
wound(16, 8)
Advance(0.5)
fire("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
assertEq(BT.db.shieldAmounts["Lightning Shield"], 13, "a blow you dodged wasn't answered")
Advance(1)
wound(16, 8)
Advance(0.5)
fire("UNIT_COMBAT", "player", "WOUND", "", 20, 1)
assertEq(BT.db.shieldAmounts["Lightning Shield"], 13, "one answer isn't enough")
Advance(1)
wound(16, 8)
Advance(0.5)
fire("UNIT_COMBAT", "player", "WOUND", "", 20, 1)
assertEq(BT.db.shieldAmounts["Lightning Shield"], 16, "two of the new size in a row: learned")
wound(Secret(16), 8)
assertEq(last("outgoing"), "<secret fmt>", "a hidden amount can't be matched: just a hit")
BT.shield, BT.shieldPending, BT.shieldSeen, BT.dots = nil, nil, nil, nil
STATE.buffs = {}
clear()
-- The spell lists: by name, in English and in the game's language
local periodic, shields = BT:SpellLists()
assertEq(periodic.Rip.period, 2, "Rip ticks every two seconds")
assertEq(periodic.Rake.direct, true, "Rake's cast hits too")
assertEq(periodic.Rip.direct, false, "Rip's doesn't")
assertEq(shields.Thorns.school, 8, "Thorns is nature")
assertEq(periodic["Insect Swarm"] ~= nil, true, "listed by name even if this game has no such ID")
BT.periodic, BT.shields = nil, nil
STATE.locale, STATE.spellNames[1079], STATE.spellNames[1822] = "deDE", "Zerfetzen", "Mount Hyjal"
periodic = BT:SpellLists()
assertEq(periodic.Zerfetzen.period, 2, "another language: the ID's name is used as well")
STATE.locale = "enUS"
BT.periodic, BT.shields = nil, nil
periodic = BT:SpellLists()
assertEq(periodic["Mount Hyjal"], nil, "English: an ID this game gave to another spell is left out")
STATE.spellNames[1079], STATE.spellNames[1822] = "Rip", "Rake"
BT.periodic, BT.shields = nil, nil
-- A client with no timers works each hit out as it comes
local timers = C_Timer
WithoutTimers(function()
    cast(16827)
    fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
    assertEq(BT.areas.outgoing.active[#BT.areas.outgoing.active].text:GetText(), "Claw 50", "no timers: shown at once")
end)
assert(C_Timer == timers, "(timers are back)")
STATE.who = {}
clear()

---------------------------------------------------------------------------
-- tests/real_fight.txt is a real /btf copy: a cat druid wearing Thorns kills
-- three mobs with Claw, Rake and Rip. Each line is replayed at its own time.
step("a real fight, as the game sent it")
BT.hiddenSeen, BT.hiddenAt, BT.credits, BT.dots, BT.spellSchool = nil, nil, nil, nil, nil
BT.db.shieldAmounts = {}
BT.db.merge = false
STATE.buffs = { { name = "Thorns", spellId = 467 } }
fire("UNIT_AURA", "player")
local out = {}
local realEmit = BT.Emit
BT.Emit = function(self, area, text, ...)
    if area == "outgoing" then out[#out + 1] = text end
    return realEmit(self, area, text, ...)
end
local base, frameTime = FAKE_TIME + 10, nil
local fights = 0
for line in read_file(ADDON_DIR .. "/tests/real_fight.txt"):gmatch("[^\r\n]+") do
    local time, what = line:match("^%s*([%d%.]+)%s%s(.*)$")
    assert(time, "a line of the recording: " .. line)
    if time ~= frameTime then
        -- A new frame: the one before is over (its timer runs)
        frameTime = time
        FAKE_TIME = base + tonumber(time) - 600
        for i = #TIMERS, 1, -1 do
            if TIMERS[i].at <= FAKE_TIME then table.remove(TIMERS, i).fn() end
        end
    end
    local unit, action, flag, amount, school = what:match("^UNIT_COMBAT (%S+) (%S+) (%S*) (%S+) school (%d+)")
    if what:find("^hidden") then
        assertEq(log(what:match("(|K.-|k)")), true, "the line arrives")
    elseif what:find("^CAST") then
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-r", tonumber(what:match("^CAST (%d+)")))
    elseif unit then
        if unit ~= "target" and STATE.who[unit] == nil then
            -- The next mob: it's your target, it has a nameplate, and it's after you
            fights = fights + 1
            local id = "fight" .. fights
            STATE.unit[id] = { enemy = true, guid = "Creature-0-1-2-3-200-00000" .. fights, target = "me" }
            STATE.who = { target = id, [unit] = id }
        end
        fire("UNIT_COMBAT", unit, action, flag, tonumber(amount), tonumber(school))
    else
        action, flag, amount = what:match("^UNIT_COMBAT player (%S+) (%S*) (%S+)$")
        assert(action, "what happened to you: " .. what)
        fire("UNIT_COMBAT", "player", action, flag, tonumber(amount), 1)
    end
end
BT:FlushHits(true)
BT.Emit = realEmit
assertEq(fights, 3, "three mobs")
local expect = {
    -- first mob: Thorns is learned from its first two answers
    "Claw 56", "27", "32", "1", "Rake 35", "29", "1", "31", "Thorns 1", "Rake 28", "28", "32", "Thorns 1",
    "Rip 16", "56", "Thorns 1", "29",
    -- second mob: the first Rip is parried, the second ticks three times (the last one a crit)
    "Claw 111", "Thorns 1", "60", "Thorns 1", "28", "Rip Parry", "Thorns 1", "27", "29", "31", "Thorns 1",
    "Rip 10", "56", "Thorns 1", "Rip 10", "Thorns 1", "Rip 19",
    -- third mob: Thorns answers in the very frame of the opening Claw; Rip ticks six times
    "Claw 108", "Thorns 1", "64", "Thorns 1", "30", "Thorns 1", "30", "Rip 10", "Thorns 1", "Thorns 1", "Rip 9",
    "Thorns 1", "Rip 9", "Thorns 1", "Thorns 1", "Rip 9", "Thorns 1", "Rip 9", "Thorns 1", "Rip 9", "Thorns 1",
    "Claw 59",
}
for i = 1, math.max(#expect, #out) do
    assertEq(out[i], expect[i], "hit " .. i .. " of the fight")
end
assertEq(BT.db.shieldAmounts.Thorns, 1, "Thorns was learned on the way")
BT.db.merge = true
BT.db.shieldAmounts = {}
BT.shield, BT.shieldPending, BT.shieldSeen, BT.dots, BT.spellSchool = nil, nil, nil, nil, nil
STATE.buffs, STATE.who = {}, {}
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

step("debug: what the game sent, in a box it can be copied from")
SlashCmdList.BATTLETEXTFOREVER("copy")
assert(BT.copyWindow.edit:GetText():find("Nothing recorded yet", 1, true), "nothing to copy before debug is on")
SlashCmdList.BATTLETEXTFOREVER("debug")
log(real("spell"))
log(real("cast"))
fire("UNIT_COMBAT", "player", "WOUND", "CRITICAL", 58, 1)
fire("UNIT_COMBAT", "player", "WOUND", "", Secret(40), 1)
SlashCmdList.BATTLETEXTFOREVER("copy")
local copied = BT.copyWindow.edit:GetText()
assertEq(BT.copyWindow:IsShown(), true, "the window opens")
assert(copied:find("read    ||Hunit:Player-5555-0ABCDEF1:Abla||hYour||h ||Hspell:16827:0:SPELL_DAMAGE||h", 1, true),
    "a line that was shown, with its links readable")
assert(copied:find("skipped ", 1, true) and copied:find("SPELL_CAST_SUCCESS", 1, true), "and one that wasn't")
assert(copied:find("UNIT_COMBAT player WOUND CRITICAL 58", 1, true), "what happened to you")
assert(copied:find("UNIT_COMBAT player WOUND  (hidden amount)", 1, true), "a hidden amount is named, not read")
local _, newlines = copied:gsub("\n", "")
assertEq(newlines, 3, "one line each")
-- With the text hidden: the token, your casts, and each unit's hit with what became of it
STATE.who.target, STATE.who.nameplate1, STATE.who.party1 = "mobA", "mobA", "friend"
Advance(2)
BT.recorded = {}
log("|Ky7|k")
log(Secret("x"))
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-9", 16827)
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
fire("UNIT_COMBAT", "nameplate1", "WOUND", "", 27, 1)
fire("UNIT_COMBAT", "party1", "WOUND", "CRITICAL", Secret(9), Secret(1))
fire("UNIT_COMBAT", "target", "ENERGIZE", "", 5, 1)
STATE.group = true
Advance(2)
fire("UNIT_COMBAT", "target", "WOUND", "", 28, 1)
log("|Ky8|k")
fire("UNIT_COMBAT", "target", "WOUND", "", 29, 1)
Advance(0.1)
log("|Ky9|k")
fire("UNIT_COMBAT", "target", "WOUND", "", Secret(31), 1)
BT:FlushHits(true)
STATE.group, STATE.who.party1 = false, nil
BT.db.outDamage = false
fire("UNIT_COMBAT", "target", "WOUND", "", 30, 1)
BT:FlushHits(true)
BT.db.outDamage = true
SlashCmdList.BATTLETEXTFOREVER("copy")
copied = BT.copyWindow.edit:GetText()
for _, expect in ipairs({
    "hidden  ||Ky7||k",
    "hidden  (a hidden value)",
    "CAST 16827 Claw",
    "UNIT_COMBAT target WOUND  27 school 1\n",
    "  target 27: cast of Claw",
    "UNIT_COMBAT nameplate1 WOUND  27 school 1: same hit, under another name",
    "UNIT_COMBAT party1 WOUND CRITICAL (hidden amount) school (hidden): not an enemy",
    "UNIT_COMBAT target ENERGIZE  5 school 1: not a hit",
    "UNIT_COMBAT target WOUND  28 school 1\n",
    "  target 28: shown",
    "  target 29: no line of yours with it",
    "  target (hidden amount): shown",
    "  target 30: damage is turned off",
}) do
    assert(copied:find(expect, 1, true), "recorded: " .. expect)
end
STATE.who = {}
SlashCmdList.BATTLETEXTFOREVER("debug")
local recordedSoFar = #BT.recorded
log(real("spell"))
fire("UNIT_COMBAT", "player", "WOUND", "", 5, 1)
assertEq(#BT.recorded, recordedSoFar, "nothing is recorded once debug is off")
for i = 1, 400 do BT:Record("line " .. i) end
assertEq(#BT.recorded, 300, "only the last 300 are kept")
assertEq(BT.recorded[300]:match("line %d+"), "line 400", "the newest ones")
BT.recorded = {}
BT.copyWindow:Hide()
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
COMBAT = true   -- even when you leave mid-fight
fire("PLAYER_LOGOUT")
COMBAT = false
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
ClickTab(ChatFrame3Tab)   -- you change chat tab mid-fight: the button can't be told until the fight ends
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
-- Fonts: every one in the list is a file that ships (or one of the game's own)
local bundled = 0
for i, font in ipairs(BT.FONTS) do
    if i == 1 then
        assertEq(font.name, "Default", "the game's own font comes first")
        assertEq(font.path, nil, "and has no file")
    elseif font.path:find("^Fonts\\") then
        assert(i <= 5, "the game's fonts come before the bundled ones")
    else
        bundled = bundled + 1
        local file = font.path:match("^Interface\\AddOns\\BattleTextForever\\(Fonts\\[%w%-]+%.ttf)$")
        assert(file, "a bundled font's path is inside the addon: " .. font.path)
        local fh = assert(io.open(ADDON_DIR .. "/" .. file:gsub("\\", "/"), "rb"), "font file is missing: " .. file)
        local head = fh:read(4) fh:close()
        assertEq(head, "\0\1\0\0", "a TrueType file: " .. file)
        local family = file:match("\\([%a%d]+)%-")
        assert(io.open(ADDON_DIR .. "/Fonts/Licenses/" .. family .. "-OFL.txt")
            or io.open(ADDON_DIR .. "/Fonts/Licenses/" .. family .. "-UFL.txt")
            or io.open(ADDON_DIR .. "/Fonts/Licenses/" .. family .. "-Apache.txt"), "its licence ships with it: " .. family)
    end
end
assertEq(bundled, 15, "fifteen bundled fonts")
assertEq(#BT.FONTS, 20, "twenty fonts to choose from")
local names = {}
for _, font in ipairs(BT.FONTS) do
    assert(not names[font.name], "font listed twice: " .. font.name)
    names[font.name] = true
end
local pkgmeta = read_file(ADDON_DIR .. "/.pkgmeta")
assert(not pkgmeta:find("Fonts", 1, true), "the Fonts folder isn't left out of the download")

-- The font dropdown: the game's own, listing every font with the current one ticked
local dropdown = BT.config.fontDropdown
assertEq(dropdown.__kind, "DropdownButton", "the game's dropdown")
assertEq(dropdown.__template, "WowStyle1DropdownTemplate", "in its usual style")
assertEq(dropdown:GetText(), "Default", "it shows the font in use")
assertEq(#dropdown.__menu, 20, "every font is in the list")
assertEq(dropdown.__menu.scroll, 240, "a long list scrolls")
for i, row in ipairs(dropdown.__menu) do
    assertEq(row.text, BT.FONTS[i].name, "in order")
    assertEq(row.isSelected(), i == 1, "only the font in use is ticked")
end
clear()
dropdown.__menu[12].pick()
assertEq(BT.db.font, "Lato", "picking one sets the font")
assertEq(BT:FontPath(), "Interface\\AddOns\\BattleTextForever\\Fonts\\Lato-Bold.ttf", "its file")
assertEq(last("notify"), "Lato", "and shows a line in it straight away")
assertEq(BT.areas.notify.active[1].text.__font[1], BT:FontPath(), "in that font")
assertEq(dropdown.__menu[12].isSelected(), true, "it's the ticked one now")
assertEq(dropdown.__menu[1].isSelected(), false, "and the old one isn't")
SlashCmdList.BATTLETEXTFOREVER("off")
dropdown.__menu[2].pick()
assertEq(last("notify"), "Friz Quadrata", "the sample shows even with BattleText turned off")
SlashCmdList.BATTLETEXTFOREVER("on")
BT.db.font = "Morpheus"
BT:RefreshConfig()
assertEq(dropdown:GetText(), "Morpheus", "it follows the setting")
BT.db.font = "A font that's gone"
assertEq(BT:FontPath(), STANDARD_TEXT_FONT, "an unknown font falls back to the game's")
BT.db.font = "Default"
BT:RefreshConfig()
clear()

-- Closing the window locks the text areas again
local moveBox
for _, f in ipairs(ALL_FRAMES) do
    if f.__kind == "CheckButton" and f.label and f.label:GetText() == "Move the text areas" then moveBox = f end
end
assert(moveBox, "the Move the text areas box")
moveBox:SetChecked(true); moveBox.__scripts.OnClick(moveBox)
assertEq(BT.db.locked, false, "ticked: unlocked")
assertEq(BT.areas.outgoing.mover:IsShown(), true, "with boxes to drag")
BT:OpenConfig()
assertEq(BT.config:IsShown(), false, "closes")
assertEq(BT.db.locked, true, "closing the window locks the text areas")
assertEq(BT.areas.outgoing.mover:IsShown(), false, "the boxes go")
BT:OpenConfig()
assertEq(moveBox:GetChecked(), false, "and the box is unticked when it opens again")
moveBox:SetChecked(true); moveBox.__scripts.OnClick(moveBox)
BT.config:Hide()   -- Escape, or the X
assertEq(BT.db.locked, true, "however it's closed")
SlashCmdList.BATTLETEXTFOREVER("unlock")
assertEq(BT.db.locked, false, "/btf unlock still works with the window closed")
SlashCmdList.BATTLETEXTFOREVER("lock")

-- A client without the game's dropdown: a button that opens the same list...
local realConfig = BT.config
STATE.noDropdown = true
BT:BuildConfig()
BT:RefreshConfig()
local plain = BT.config.fontDropdown
assertEq(plain.__kind, "Button", "a plain button instead")
assertEq(plain:GetText(), "Default", "showing the font in use")
MENU_OPENED = nil
plain.__scripts.OnClick(plain)
assertEq(#MENU_OPENED, 20, "its menu lists every font")
MENU_OPENED[7].pick()
assertEq(BT.db.font, "Archivo Black", "picking one sets the font")
assertEq(plain:GetText(), "Archivo Black", "and the button says so")
-- ...and with no menus at all, each click moves to the next font
WithoutMenus(function()
    plain.__scripts.OnClick(plain)
    assertEq(BT.db.font, "Bangers", "the next font")
    BT.db.font = "Ubuntu"
    plain.__scripts.OnClick(plain)
    assertEq(BT.db.font, "Default", "round to the start")
    assertEq(plain:GetText(), "Default", "shown on the button")
end)
STATE.noDropdown = false
BT.config:Hide()
BT.config = realConfig
clear()

assertClean("by the end")
print("ALL TESTS PASSED")
