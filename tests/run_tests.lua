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
    if not line:find("^#") and line:find("%S") then tocFiles[#tocFiles + 1] = line:match("^%s*(.-)%s*$"):gsub("\\", "/") end
end
assertEq(table.concat(tocFiles, " "), "Theme.lua Locales/Locales.lua Locales/deDE.lua Locales/esES.lua Locales/esMX.lua Locales/frFR.lua "
    .. "Locales/itIT.lua Locales/koKR.lua Locales/ptBR.lua Locales/ruRU.lua Locales/zhCN.lua Locales/zhTW.lua Parse.lua "
    .. "Core.lua Display.lua Incoming.lua Spells.lua Alerts.lua Attribution.lua Notices.lua Settings.lua Options.lua",
    "the files the game loads, in order")
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

-- What the packager ships: everything at the top of the repo that .pkgmeta doesn't leave out
-- (the packager itself skips names starting with a dot). Nothing else, and no access tokens in it.
do
    local pkgmeta = read_file(ADDON_DIR .. "/.pkgmeta")
    local ignored = {}
    for name in pkgmeta:match("ignore:(.*)$"):gmatch("%-%s*(%S+)") do ignored[name] = true end
    local SHIPPED = { ["BattleTextForever.toc"] = true, ["Theme.lua"] = true, ["Parse.lua"] = true, ["Core.lua"] = true, ["Display.lua"] = true, ["Incoming.lua"] = true, ["Spells.lua"] = true, ["Alerts.lua"] = true, ["Attribution.lua"] = true, ["Notices.lua"] = true, ["Settings.lua"] = true,
        ["Options.lua"] = true, ["Bindings.xml"] = true, ["CHANGELOG.md"] = true, ["README.md"] = true, ["LICENSE"] = true,
        Fonts = true, Media = true, Locales = true }
    local listing = io.popen('ls -A "' .. ADDON_DIR .. '"')
    for name in listing:lines() do
        if not name:find("^%.") and not ignored[name] then
            assert(SHIPPED[name], "this would ship in the addon download: " .. name .. " (add it to .pkgmeta's ignore list)")
        end
    end
    listing:close()
    local files = io.popen('find "' .. ADDON_DIR .. '" -type f -not -path "*/.git/*" -not -name "*.ttf" -not -name "*.tga" -not -name "*.png"')
    for path in files:lines() do
        local text = read_file(path)
        assert(not text:find("gh[pousr]_%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w%w") and not text:find("github_pat_%w"),
            "an access token is written in " .. path .. ": revoke it and keep it in the repository's secrets instead")
    end
    files:close()
end

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
-- Icons and spell names, in every section of the options at once
local function SetIcons(on) BT.db.outIcons, BT.db.inIcons, BT.db.healIcons, BT.db.nIcons = on, on, on, on end
local function SetNames(on) BT.db.outNames, BT.db.inNames, BT.db.healNames = on, on, on end

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
    "periodic", "split", "blocked", "absorbed", "resisted", "overkill", "overheal", "missType",
    "extraSpell", "extraSpellId", "aura", "stolen" }
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
assertEq(BT.DEFAULTS.loginMessage, true, "the login message is on to start with")
local loadedLine = false
for _, line in ipairs(LOG) do if line:find("loaded. Type /btf", 1, true) then loadedLine = true end end
assert(loadedLine, "the login message is in chat")
assertEq(BT.areas.outgoing.mover:IsShown(), false, "areas are locked by default")
for _, name in ipairs(bindingNames) do
    local button = name:match("^CLICK (%S+):LeftButton$")
    if button then assert(_G[button] and _G[button].__protected, "the keybinding's button exists and is secure: " .. button) end
end
assertClean("after logging in")
assert(BT.areas.heal, "and a fourth for heals")
assertEq(BT:HealArea("outgoing") .. "," .. BT:HealArea("incoming"), "heal,heal", "heals have their own area by default")
-- The older checks read heals where they were before the Healing area: on the
-- left (on you) and on the right (yours). The Healing area has its own steps.
BT.db.healArea = false

-- A combat log line reaches addons only when the game is writing them: its
-- filter is loaded and the lines are turned on
local function flowing() return STATE.filterApplied and STATE.filteredEvents and not STATE.logBroken end
local function log(line, order)
    if not flowing() then return false end
    fire("COMBAT_LOG_MESSAGE", line, 1, 1, 1, order or Enum.CombatLogMessageOrder.Newest)
    return true
end

step("starting by itself")
-- As in the game: its Combat Log code loaded the filter at login, and turned the
-- lines off because its window is hidden. BattleText turns them on, no click needed.
do
    local was = { STATE.filterApplied, STATE.filteredEvents }
    STATE.filterApplied, STATE.filteredEvents = true, false
    BT.started = nil
    LOG = {}
    fire("PLAYER_ENTERING_WORLD")
    assertEq(STATE.filteredEvents, true, "BattleText turned the lines on at login")
    assertEq(BT.startButton:IsShown(), false, "no Start button at login")
    fire("PLAYER_REGEN_DISABLED")
    assertEq(log(swing(27)), true, "lines arrive in the first fight")
    assertEq(BT.started, true, "started by itself")
    fire("PLAYER_REGEN_ENABLED")
    assertEq(BT.startButton:IsShown(), false, "and no Start button after it")
    -- The game turns them off whenever its Combat Log window hides; they come back
    STATE.filteredEvents = false
    Advance(3.1)
    assertEq(STATE.filteredEvents, true, "kept on")
    for _, line in ipairs(LOG) do assert(not line:find("Start BattleText", 1, true), "no reminder: " .. line) end
    clear()
    BT.started, BT.startNeeded = nil, nil
    STATE.filterApplied, STATE.filteredEvents = was[1], was[2]
end
assertClean("after starting by itself")

step("a reminder in chat when a fight ends and no line came")
local function reminders()
    local found = {}
    for _, line in ipairs(LOG) do
        if line:find("Start BattleText", 1, true) and line:find("click", 1, true) then found[#found + 1] = line end
    end
    return found
end
LOG = {}
Advance(30)
assertEq(#reminders(), 0, "nothing before a fight")
assertEq(BT.startButton:IsShown(), false, "and no Start button")
-- A fight where you only got hit (you did nothing): "My actions" has no line for that
fire("PLAYER_REGEN_DISABLED")
fire("PLAYER_REGEN_ENABLED")
assertEq(#reminders(), 0, "a fight you didn't act in proves nothing: no reminder")
assertEq(BT.startButton:IsShown(), false, "and no Start button")
fire("PLAYER_REGEN_DISABLED")
fire("PLAYER_SWING", 2.6, 0)   -- (you swung)
BT.swungAt, BT.meleeAt, BT.hands, BT.swings = nil, nil, nil, nil
assertEq(log(swing(27)), false, "the game isn't writing lines (its filter didn't load)")
fire("PLAYER_REGEN_ENABLED")
assertEq(#reminders(), 1, "one reminder when the fight ends")
assertEq(BT.startButton:IsShown(), true, "and the Start button shows")
assert(reminders()[1]:find("|cffe8a040BattleText Forever|r: click", 1, true), "it comes from BattleText, with the shared chat prefix: " .. reminders()[1])
assert(not reminders()[1]:find("press", 1, true), "no key is named when none is bound")
fire("PLAYER_REGEN_DISABLED")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-again", 6603)   -- (a cast counts as acting too)
fire("PLAYER_REGEN_ENABLED")
assertEq(#reminders(), 1, "and only the one")
-- With a key bound to Start, the reminder names it
LOG = {}
STATE.bindingKeys = { ["CLICK BattleTextForeverStart:LeftButton"] = "F9" }
BT:RemindStart()
assert(reminders()[1] and reminders()[1]:find("(or press F9)", 1, true), "the bound key is named: " .. tostring(reminders()[1]))
STATE.bindingKeys = nil
-- Not when it's turned off, when BattleText is off, or once Start has been clicked
LOG = {}
BT.db.startReminder = false
BT:RemindStart()
assertEq(#reminders(), 0, "no reminder when the setting is off")
BT.db.startReminder = true
BT.db.enabled = false
BT:RemindStart()
assertEq(#reminders(), 0, "no reminder when BattleText is off")
BT.db.enabled = true
BT.started = true
BT:RemindStart()
assertEq(#reminders(), 0, "no reminder once it's started")
BT.started = nil
BT:RemindStart()
assertEq(#reminders(), 1, "and one when it isn't")
LOG = {}
assertClean("after the reminder")

step("start button: the combat log needs opening once")
do   -- (the Combat Log window is ChatFrame2 before Blizzard's Combat Log code names it, too)
    local was = COMBATLOG
    rawset(_G, "COMBATLOG", nil)
    assertEq(BT:CombatLogFrame(), ChatFrame2, "the Combat Log window, before COMBATLOG is set")
    rawset(_G, "COMBATLOG", was)
end
local start = BT.startButton
assertEq(start:IsShown(), true, "Start button shows after that fight")
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
-- A chat addon (like Chattynator) that replaced the game's chat window: its tabs are
-- hidden, so clicking the Combat Log tab opens nothing
local wasApplied = STATE.filterApplied
BT.started, BT.startFailSaid = nil, nil
STATE.filterApplied = false
BT:UpdateStartButton()
local realTab = ChatFrame2Tab.__scripts.OnClick
ChatFrame2Tab.__scripts.OnClick = function() end
-- (the tab is there to see: the click reached it, so a chat addon isn't why; nothing is said)
local said = #LOG
ClickButton(start)
Advance(0.5)
assertEq(#LOG, said, "with the game's Combat Log tab in sight, no chat-addon warning")
ChatFrame2Tab:Hide()
ClickButton(start)
Advance(0.5)
assertEq(start:IsShown(), true, "the click opened nothing: the button stays")
assert(#LOG > said and LOG[#LOG]:find("couldn't open the game's Combat Log tab", 1, true),
    "and chat says why, and what to do")
said = #LOG
ClickButton(start)
Advance(0.5)
assertEq(#LOG, said, "said once, not on every click")
ClickButton(start, "RightButton")
assertEq(start:IsShown(), false, "right-click hides it")
assertEq(STATE.filterApplied, false, "without running the click's macro")
BT:RemindStart()
assertEq(#LOG, said, "and no reminder about it")
ChatFrame2Tab.__scripts.OnClick = realTab
ChatFrame2Tab:Show()
STATE.filterApplied = wasApplied
BT.started, BT.startHidden = true, nil
BT:UpdateStartButton()
assertClean("after a chat addon hid the Combat Log tab")
-- Started from your own macro: /click BattleTextForeverStart only sends the release,
-- and it works with "act on key down" on (the game's default) or off
for _, keyDown in ipairs({ true, false }) do
    STATE.useKeyDown = keyDown
    BT.started = nil
    STATE.filterApplied, STATE.filteredEvents = false, false
    BT:UpdateStartButton()
    ClickTab(ChatFrame3Tab)
    ClickButton(start, "LeftButton", true)
    assertEq(STATE.filterApplied, true, "a /click in a macro starts it (key down " .. tostring(keyDown) .. ")")
    assertEq(SELECTED_DOCK_FRAME, ChatFrame3, "and goes back to your tab")
    assertEq(BT.started, true, "started from the macro")
    assertEq(start:IsShown(), false, "the button goes")
    -- Pressed again and again with that macro: nothing happens to your chat tabs
    local opened = 0
    local realShow = ChatFrame2.__scripts.OnShow
    ChatFrame2.__scripts.OnShow = function(...) opened = opened + 1 if realShow then return realShow(...) end end
    ClickButton(start, "LeftButton", true)
    ClickButton(start)
    ChatFrame2.__scripts.OnShow = realShow
    assertEq(opened, 0, "once started, the click doesn't open the Combat Log again")
    assertEq(SELECTED_DOCK_FRAME, ChatFrame3, "you stay on your tab")
    assertEq(STATE.filteredEvents, true, "and the lines stay on")
end
STATE.useKeyDown = false
ClickTab(ChatFrame1Tab)
assertClean("after starting from a macro")

---------------------------------------------------------------------------
step("your hits")
SetIcons(false)
log(swing(27))
assertEq(last("outgoing"), "27", "a swing shows its number")
Advance(1)
log(hit("Claw", 16827, 50, "Physical", "(1 Blocked)"))
assertEq(last("outgoing"), "Claw 50 |cffb0b0b0(1 blocked)|r", "a spell shows its name, number and what was blocked")
assertEq(#lines("incoming"), 0, "nothing in the incoming area")
SetNames(false)
Advance(1)
log(hit("Claw", 16827, 50))
assertEq(last("outgoing"), "50", "spell names off")
SetNames(true); SetIcons(true)
Advance(1)
log(hit("Claw", 16827, 51))
assertEq(last("outgoing"), "|T132140:0|t Claw 51", "spell icon, found by the spell's ID")
BT.db.iconZoom = true
Advance(1)
log(hit("Claw", 16827, 52))
assertEq(last("outgoing"), "|T132140:0:0:0:0:64:64:5:59:5:59|t Claw 52", "Icon zoom: the icon's edge cropped")
BT.db.iconZoom = false
SetIcons(false)
Advance(1)
log(hit("Fireball", 133, 1234, "Fire"))
assertEq(last("outgoing"), "Fireball 1,234", "thousands")
assertEq(BT.areas.outgoing.active[#BT.areas.outgoing.active].text.__color[2], 0.5, "tinted by its school (fire)")
-- A damage shield's readable line ("Your Thorns damages <mob> 11 Nature.") obeys "Damage shields"
local thornsLine = ME .. "Your|h |Hspell:467:0:DAMAGE_SHIELD|h|cffffffffThorns|r|h |Haction:DAMAGE_SHIELD|hdamages|h "
    .. MOB .. " |cffffffff11|r |cffffffffNature|r. "
Advance(1)
log(thornsLine)
assertEq(last("outgoing"), "Thorns 11", "a damage shield's line")
clear()
BT.db.outShields = false
Advance(1)
log(thornsLine)
assertEq(#lines("outgoing"), 0, "\"Damage shields\" off: its line is hidden too")
BT.db.outShields = true
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

step("ticks and area hits add up for longer")
local function tick(spell, id, amount, school)   -- the same line, from a damage-over-time spell
    return (hit(spell, id, amount, school):gsub("SPELL_DAMAGE", "SPELL_PERIODIC_DAMAGE"))
end
assertEq(BT.DEFAULTS.tickMerge, 0, "off to start with: ticks add up as quickly as other hits")
BT.db.outTicks = false
log(tick("Rake", 1822, 12))
log(hit("Rake", 1822, 30))
assertEq(table.concat(lines("outgoing"), " / "), "Rake 30", "DoTs off: a tick from the log is hidden, the spell's own hit isn't")
BT.db.outTicks = true
clear()
log(tick("Rake", 1822, 12))
Advance(0.9)
log(tick("Rake", 1822, 12))
assertEq(#lines("outgoing"), 2, "ticks 0.9 seconds apart are two lines")
clear()
BT.db.tickMerge = 1.5
log(tick("Rake", 1822, 12))
Advance(0.9)
log(tick("Rake", 1822, 13))
assertEq(lines("outgoing")[1], "Rake 25 |cffb0b0b0(x2)|r", "with the window, they add up")
assertEq(#lines("outgoing"), 1, "on one line")
log(hit("Rake", 1822, 30))
assertEq(#lines("outgoing"), 2, "the spell's own hit isn't a tick")
Advance(0.8)
log(tick("Rake", 1822, 12))
assertEq(lines("outgoing")[1], "Rake 37 |cffb0b0b0(x3)|r", "a third tick, still adding up")
Advance(1.0)
log(tick("Rake", 1822, 12))
assertEq(lines("outgoing")[1], "Rake 37 |cffb0b0b0(x3)|r", "a line most of the way across takes no more")
BT.db.tickMerge = 0
clear()

step("auto attacks can be hidden")
assertEq(BT.DEFAULTS.outSwings, true, "shown to start with")
BT.db.outSwings = false
log(swing(27))
assertEq(#lines("outgoing"), 0, "a swing is hidden")
log(hit("Claw", 16827, 50))
assertEq(last("outgoing"), "Claw 50", "a spell still shows")
BT.db.outSwings = true
log(swing(27))
assertEq(last("outgoing"), "27", "shown again")
clear()

step("size by hit")
assertEq(BT.DEFAULTS.sizeByHit, false, "off to start with")
BT.db.sizeByHit = true
BT.areas.outgoing.usualHit = nil
log(hit("Claw", 16827, 50))
assertEq(BT.areas.outgoing.active[1].text.__font[2], 20, "the first hit is the usual size")
Advance(1)
log(hit("Wrath", 5176, 500, "Nature"))
local big = BT.areas.outgoing.active[2].text.__font[2]
assert(big > 20 and big <= 30, "a much bigger hit shows bigger, at most half again: " .. big)
Advance(1)
log(hit("Claw", 16827, 5))
local small = BT.areas.outgoing.active[3].text.__font[2]
assert(small < 20 and small >= 15, "a small one shows smaller, at least three quarters: " .. small)
BT.db.sizeByHit = false
Advance(1)
log(hit("Wrath", 5176, 5000, "Nature"))
assertEq(BT.areas.outgoing.active[4].text.__font[2], 20, "turned off: every hit the same size")
clear()

step("sounds on crits and killing blows")
assertEq(BT.DEFAULTS.soundCrit or BT.DEFAULTS.soundKill, false, "off to start with")
STATE.sounds = {}
log(hit("Claw", 16827, 100, "Physical", "(Critical)"))
BT:ShowCombat({ kind = "kill", fromMe = true })
assertEq(#STATE.sounds, 0, "no sounds while they're off")
clear()
BT.db.soundCrit, BT.db.soundKill = true, true
log(hit("Claw", 16827, 100, "Physical", "(Critical)"))
assertEq(STATE.sounds[1], 208810, "the crit sound on a crit")
log(hit("Claw", 16827, 100, "Physical", "(Critical)"))
assertEq(#STATE.sounds, 1, "not twice at once")
log(hit("Claw", 16827, 40))
assertEq(#STATE.sounds, 1, "not on a normal hit")
BT:ShowCombat({ kind = "kill", fromMe = true })
assertEq(STATE.sounds[2], 50111, "the kill sound on a killing blow")
-- Picking one in the options plays it
assertEq(#BT.SOUNDS >= 15, true, "plenty to pick from")
BT:SetAlertSound("crit", "UI_EPICLOOT_TOAST")
assertEq(BT.db.critSound, "UI_EPICLOOT_TOAST", "picked")
assertEq(STATE.sounds[3], 31578, "and heard straight away")
-- One this game doesn't have: said so, and the fallback plays in a fight
STATE.missingSounds = { [31578] = true }
local printed = #LOG
BT:SetAlertSound("crit", "UI_EPICLOOT_TOAST")
assert(LOG[#LOG] and #LOG > printed and LOG[#LOG]:find("Epic loot isn't in this game's sounds", 1, true),
    "a sound the game lacks is named in chat")
Advance(1)
log(hit("Claw", 16827, 100, "Physical", "(Critical)"))
assertEq(STATE.sounds[#STATE.sounds], 3175, "a crit then plays the ping instead")
STATE.missingSounds = nil
BT.db.critSound = BT.DEFAULTS.critSound
-- Turned off (/btf off): no sounds, and the fight around you isn't worked out at all
do
Advance(1)
BT.db.enabled = false
local heard = #STATE.sounds
local savedWho, savedUnits = STATE.who.target, STATE.unit.offMob
STATE.unit.offMob = { enemy = true, guid = "Creature-0-1-2-3-4-000321", target = "me" }
STATE.who.target = "offMob"
BT.seq = nil
fire("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 99, 1)
assertEq(BT.seq == nil or #BT.seq == 0, true, "nothing is queued to work out while BattleText is turned off")
BT:FlushHits(true)
BT:ShowCombat({ kind = "kill", fromMe = true })
assertEq(#STATE.sounds, heard, "and no sounds")
STATE.xp = STATE.xp + 30
fire("PLAYER_XP_UPDATE", "player")
assertEq(BT.lastXP, STATE.xp, "your experience is still followed, so turning it on later doesn't show it all at once")
BT.db.enabled = true
STATE.xp = STATE.xp - 30
BT.lastXP = STATE.xp
STATE.who.target, STATE.unit.offMob = savedWho, savedUnits
end
BT.db.soundCrit, BT.db.soundKill = false, false
clear()

step("low health and low mana warnings")
do
local function says() return table.concat(lines("notify"), " / ") end
local edges = LowHealthFrame
assertEq(BT.DEFAULTS.warnHealth or BT.DEFAULTS.warnMana, false, "off to start with")
assertEq(BT.healthLow, false, "where your health is, noted at login")
STATE.sounds = {}
-- Off: nothing
edges:Show()
fire("UNIT_HEALTH", "player")
assertEq(says(), "", "no warning while it's off")
assertEq(#STATE.sounds, 0, "and no sound")
edges:Hide()
-- Your health is hidden from addons: the game's red screen edges say it's low
BT.db.warnHealth = true
edges:Show()
assertEq(says(), "Low health!", "the red edges coming up warn")
assertEq(STATE.sounds[1], 8959, "with its sound (the raid warning)")
fire("UNIT_HEALTH", "player")
fire("UNIT_HEALTH", "player")
assertEq(#lines("notify"), 1, "once, while they stay up")
assertEq(#STATE.sounds, 1, "one sound")
-- Healed back up, then low again: it warns again (but not twice in a few seconds)
edges:Hide()
fire("UNIT_HEALTH", "player")
edges:Show()
assertEq(#lines("notify"), 1, "not again straight away")
edges:Hide()
Advance(6)
edges:Show()
assertEq(last("notify"), "Low health!", "again after healing back up")
assertEq(#STATE.sounds, 2, "with its sound")
edges:Hide()
clear()
-- In a fight the edges also flash while the map is open: that says nothing about your health
STATE.fullscreenPanel = UIParent
edges:Show()
assertEq(says(), "", "the map open in a fight isn't low health")
edges:Hide()
STATE.fullscreenPanel = nil
-- A game that lets addons read your health: worked out here, at the same 35%
STATE.healthReadable = true
STATE.health = 360
fire("UNIT_HEALTH", "player")
assertEq(says(), "", "36% isn't low")
STATE.health = 350
fire("UNIT_HEALTH", "player")
assertEq(says(), "Low health!", "35% is, read as it is")
STATE.health = 900
fire("UNIT_HEALTH", "player")
Advance(6)
-- Dead isn't low
STATE.health, STATE.dead = 0, true
fire("UNIT_HEALTH", "player")
assertEq(says(), "", "no warning as you die")
STATE.dead = false
STATE.health, STATE.healthReadable = 1000, nil
fire("UNIT_HEALTH", "player")
clear()
-- Low mana: read as it is, at the line you pick
BT.db.warnMana = true
assertEq(BT.db.lowManaAt, 35, "35% to start with")
local heard = #STATE.sounds
STATE.mana = 360
fire("UNIT_POWER_UPDATE", "player", "MANA")
assertEq(says(), "", "36% mana isn't low")
STATE.mana = 340
fire("UNIT_POWER_UPDATE", "player", "MANA")
assertEq(says(), "Low mana!", "34% is")
assertEq(STATE.sounds[heard + 1], 8960, "with its own sound (the ready check)")
-- Mana coming back a little and going again (drinking, a tick of regen) doesn't warn again
Advance(6)
heard = #STATE.sounds
STATE.mana = 420
fire("UNIT_POWER_UPDATE", "player", "MANA")
STATE.mana = 330
fire("UNIT_POWER_UPDATE", "player", "MANA")
assertEq(#STATE.sounds, heard, "not again until 10% over the line")
STATE.mana = 450
fire("UNIT_POWER_UPDATE", "player", "MANA")
STATE.mana = 300
fire("UNIT_POWER_UPDATE", "player", "MANA")
assertEq(last("notify"), "Low mana!", "again once it's been back up")
assertEq(#STATE.sounds, heard + 1, "a second time")
-- Hidden mana, or none (a warrior): nothing
STATE.mana = 1000
fire("UNIT_POWER_UPDATE", "player", "MANA")
Advance(6)
STATE.mana, STATE.manaHidden = 100, true
fire("UNIT_POWER_UPDATE", "player", "MANA")
assertEq(#STATE.sounds, heard + 1, "nothing while the game hides your mana")
-- ...but a steady "Low mana" above the notifications, shown by the game's own percent: the addon
-- hands it a curve and gives the hidden answer straight to SetAlpha (issue #26: Forever hides it)
local sign = BT.manaSign
assert(sign and sign:IsShown(), "a sign while your mana is hidden")
assertEq(sign.text:GetText(), "Low mana", "that says so")
assert(issecretvalue(sign.__alpha), "its see-through-ness is the game's hidden answer, never read")
assertEq(sign.__alpha.v, 1, "seen at 10% (line 35%)")
assertEq(BT.manaLow, false, "the addon still can't tell")
STATE.mana = 360
fire("UNIT_POWER_UPDATE", "player", "MANA")
assertEq(sign.__alpha.v, 0, "see-through at 36%")
STATE.mana = 350
fire("UNIT_POWER_UPDATE", "player", "MANA")
assertEq(sign.__alpha.v, 1, "the line itself is low, as when it's read")
BT.db.lowManaAt = 30
BT:ApplyAreas()   -- (what the slider does)
assertEq(sign.__alpha.v, 0, "a lower line moves it")
BT.db.lowManaAt = 35
BT:ApplyAreas()
assertEq(sign.__alpha.v, 1, "and back")
assertEq(#STATE.sounds, heard + 1, "no sound: the addon can't tell when to play one")
BT.db.warnMana = false
BT:ApplyAreas()
assert(not sign:IsShown(), "gone with the warning off")
BT.db.warnMana = true
BT:ApplyAreas()
assert(sign:IsShown(), "back with it on")
STATE.dead = true
fire("UNIT_POWER_UPDATE", "player", "MANA")
assert(not sign:IsShown(), "not while dead")
STATE.dead = false
fire("UNIT_POWER_UPDATE", "player", "MANA")
assert(sign:IsShown(), "back once alive")
STATE.mana, STATE.manaHidden = 1000, nil
fire("UNIT_POWER_UPDATE", "player", "MANA")
assert(not sign:IsShown(), "mana the addon can read: the usual warning instead")
STATE.manaHidden = true
local GAME = getmetatable(_G).__index
local keepPercent = GAME.UnitPowerPercent
GAME.UnitPowerPercent = nil
fire("UNIT_POWER_UPDATE", "player", "MANA")
assert(not sign:IsShown(), "a game without the percent: nothing")
GAME.UnitPowerPercent = keepPercent
STATE.manaHidden = nil
STATE.mana, STATE.manaMax = 0, 0
fire("UNIT_POWER_UPDATE", "player", "MANA")
assertEq(#STATE.sounds, heard + 1, "nothing with no mana at all")
STATE.mana, STATE.manaMax = 1000, 1000
fire("UNIT_POWER_UPDATE", "player", "MANA")
clear()
-- Logging in while low: noted, not warned
BT.healthLow, BT.manaLow = nil, nil
edges:Show()
STATE.mana = 100
fire("PLAYER_ENTERING_WORLD")
assertEq(says(), "", "no warning for where you already are when you log in")
assertEq(BT.healthLow and BT.manaLow, true, "but it's noted")
edges:Hide()
STATE.mana = 1000
fire("UNIT_POWER_UPDATE", "player", "MANA")
fire("UNIT_HEALTH", "player")
-- Turned off (/btf off): nothing
Advance(6)
BT.db.enabled = false
edges:Show()
STATE.mana = 100
fire("UNIT_POWER_UPDATE", "player", "MANA")
assertEq(says(), "", "nothing while BattleText is turned off")
BT.db.enabled = true
edges:Hide()
STATE.mana = 1000
fire("UNIT_POWER_UPDATE", "player", "MANA")
-- Picking a sound plays it
heard = #STATE.sounds
BT:SetAlertSound("lowMana", "RAID_WARNING")
assertEq(BT.db.lowManaSound, "RAID_WARNING", "picked")
assertEq(STATE.sounds[heard + 1], 8959, "and heard")
assertEq(BT:Choices("lowManaSound").RAID_WARNING, true, "a sound shared settings text can carry")
BT.db.lowManaSound = BT.DEFAULTS.lowManaSound
BT.db.warnHealth, BT.db.warnMana = false, false
clear()
end

step("fight summary")
assertEq(BT.DEFAULTS.nSummary, true, "on to start with")
fire("PLAYER_REGEN_DISABLED")
log(hit("Claw", 16827, 300))
Advance(1)
log(swing(100))
log(healMe("Healing Touch", 5185, 250))
Advance(19)
fire("PLAYER_REGEN_ENABLED")
assertEq(last("notify"), "400 damage (20 DPS), 250 healed in 20s", "damage, DPS and healing when the fight ends")
clear()
fire("PLAYER_REGEN_DISABLED")
Advance(5)
fire("PLAYER_REGEN_ENABLED")
assertEq(last("notify"), "-Combat", "nothing done: no summary")
clear()
BT.db.nSummary = false
fire("PLAYER_REGEN_DISABLED")
log(hit("Claw", 16827, 300))
fire("PLAYER_REGEN_ENABLED")
assertEq(last("notify"), "-Combat", "turned off")
BT.db.nSummary = true
clear()

step("movement: scroll, pop, fountain, horizontal")
assertEq(BT.DEFAULTS.outStyle, "scroll", "scroll to start with")
for _, style in ipairs({ "pop", "fountain", "horizontal" }) do
    BT.db.outStyle = style
    BT:Emit("outgoing", "a", { 1, 1, 1 })
    BT:Emit("outgoing", "b", { 1, 1, 1 })
    local a, b = BT.areas.outgoing.active[1], BT.areas.outgoing.active[2]
    assertEq(a.style, style, style .. ": the line moves that way")
    assertEq(b.start, a.start, style .. ": no waiting for room")
    Advance(BT:ScrollTime(BT.areas.outgoing) / 2)
    assertEq(a:IsShown() and BT.areas.outgoing.active[1] == a, true, style .. ": still there halfway")
    clear()
end
BT.db.outStyle = "something odd"
BT:Emit("outgoing", "a", { 1, 1, 1 })
assertEq(BT.areas.outgoing.active[1].style, nil, "an unknown style scrolls")
BT.db.outStyle = "scroll"
clear()

step("keep Pop numbers apart")
assertEq(BT.DEFAULTS.popApart, false, "off to start with")
local realRandom = math.random
math.random = function() return 0.5 end   -- every Pop line picks the same spot
local function boxes(area)
    local out = {}
    for _, o in ipairs(BT.areas[area].active) do
        local w = o.boxW
        local left = (o.anchor == "LEFT" and o.px) or (o.anchor == "RIGHT" and o.px - w) or o.px - w / 2
        out[#out + 1] = { left, left + w, o.py + o.size / 2, o.py - o.size / 2, o }
    end
    return out
end
local function overlapping(area)
    local b, n = boxes(area), 0
    for i = 1, #b do
        for j = i + 1, #b do
            local p, q = b[i], b[j]
            if p[1] < q[2] and q[1] < p[2] and p[4] < q[3] and q[4] < p[3] then n = n + 1 end
        end
    end
    return n
end
for _, area in ipairs({ "outgoing", "incoming", "notify", "heal" }) do
    local prefix = BT.AREAS[area].prefix
    BT.db[prefix .. "Style"] = "pop"
    BT.db.popApart = false
    for i = 1, 4 do BT:Emit(area, tostring(1000 + i), { 1, 1, 1 }) end
    assert(overlapping(area) > 0, area .. ": without it, four hits at once land on one another")
    clear()
    BT.db.popApart = true
    for i = 1, 4 do BT:Emit(area, tostring(1000 + i), { 1, 1, 1 }) end
    assertEq(overlapping(area), 0, area .. ": with it, four hits at once all readable")
    local first = BT.areas[area].active[1]
    -- (the random spot: the middle, or halfway into the box from a Left or Right edge)
    local want = first.inward * 0.5 * (BT.AREAS[area].dir == 0 and 120 or 50)
    assertEq(first.px == want and first.py == -BT:AreaHeight(BT.areas[area]) * 0.475, true,
        area .. ": the first keeps its own spot")
    for _, o in ipairs(BT.areas[area].active) do
        local h = BT:AreaHeight(BT.areas[area])
        assert(o.py < 0 and o.py > -h, area .. ": moved, but still in the area")
    end
    -- Gone ones leave room: once they've faded, the next lands on its own spot again
    Advance(BT.areas[area].active[1].duration + 0.1)
    BT:Emit(area, "2000", { 1, 1, 1 })
    assertEq(BT.areas[area].active[1].py, -BT:AreaHeight(BT.areas[area]) * 0.475, area .. ": room again")
    clear()
    BT.db[prefix .. "Style"] = "scroll"
end
-- A crit holding in place counts as taken too (centered Outgoing text: they'd share the middle)
BT.db.outStyle, BT.db.popApart, BT.db.outAlign = "pop", true, "CENTER"
BT:Emit("outgoing", "999", { 1, 1, 1 }, { crit = true })
BT:Emit("outgoing", "123", { 1, 1, 1 })
local crit, pop = BT.areas.outgoing.active[1], BT.areas.outgoing.active[2]
assertEq(crit.sticky and pop.style == "pop", true, "a crit and a Pop line")
local h = BT:AreaHeight(BT.areas.outgoing)
local apartUp = math.abs(pop.py - -h / 2) >= (crit.size + pop.size) / 2
local apartSide = math.abs(pop.px - -14) >= (crit.boxW + pop.boxW) / 2
assert(apartUp or apartSide, "the Pop line keeps off the crit")
BT.db.outAlign = "LEFT"
-- A crowd: more than fit still all show, none lost
clear()
for i = 1, 40 do BT:Emit("outgoing", tostring(i), { 1, 1, 1 }) end
assertEq(#BT.areas.outgoing.active, 40, "a crowd: every line still shows")
assert(BT.freeSpotChecks <= 121, "and finding a spot for one stays a small job (BT-023): " .. BT.freeSpotChecks .. " checks")
math.random = realRandom
BT.db.outStyle, BT.db.popApart = "scroll", false
clear()

step("share settings")
local saved = {}
for k, v in pairs(BT.db) do saved[k] = v end
BT.db.fontSize, BT.db.outline, BT.db.nStyle, BT.db.tickMerge = 27, "SHADOW", "pop", 1.5
BT.db.colors = { melee = { 0.5, 0.25, 1 } }
local text = BT:ExportSettings()
assertEq(text:sub(1, 5), "BTF1:", "marked as BattleText's")
assert(not text:find("shieldAmounts", 1, true), "nothing learned in fights goes in")
assert(not text:find("enabled", 1, true), "nor whether it's turned on")
BT.db.fontSize, BT.db.outline, BT.db.nStyle, BT.db.tickMerge, BT.db.colors = 20, "OUTLINE", "scroll", 0, {}
local count = BT:ImportSettings("  " .. text .. "\n")
assert(count and count > 20, "read back: " .. tostring(count))
assertEq(BT.db.fontSize, 27, "a number")
assertEq(BT.db.outline, "SHADOW", "a word")
assertEq(BT.db.nStyle, "pop", "a style")
assertEq(BT.db.tickMerge, 1.5, "a half")
assertEq(BT.db.colors.melee[2], 0.25, "a color")
assertEq(select(2, BT:ImportSettings("hello")), "that isn't BattleText settings text", "not settings")
assertEq(BT:ImportSettings(text:sub(1, 40)), nil, "cut short")
assertEq(BT:ImportSettings('BTF1:{fontSize="big",nothing=t,colors={melee=t}}'), nil, "wrong kinds are left out")
assertEq(BT.db.fontSize, 27, "and change nothing")
assertEq(BT:ImportSettings('BTF1:{fontSize=os.exit()}'), nil, "code is never run")
-- Out of range or not in its list: kept in range, or left as it was
BT:ImportSettings('BTF1:{fontSize=1000,scrollTime=0,nSize=5,font="Comic Sans",outline="SHADOW",outStyle="spin",'
    .. 'critSound="NOPE",colors={melee={1=2,2=-1,3=0.5}}}')
assertEq(BT.db.fontSize, 40, "a size too big becomes the biggest the slider has")
assertEq(BT.db.scrollTime, 1, "a time of 0 becomes the shortest")
assertEq(BT.db.nSize, 50, "an area size too small, the smallest")
assertEq(BT.db.font, saved.font, "a font that isn't in the list is left as it was")
assertEq(BT.db.outline, "SHADOW", "one that is, taken")
assertEq(BT.db.outStyle, saved.outStyle, "a movement that doesn't exist, left")
assertEq(BT.db.critSound, saved.critSound, "a sound that doesn't exist, left")
assertEq(BT.db.colors.melee[1] .. "," .. BT.db.colors.melee[2], "1,0", "colors kept between 0 and 1")
-- Where the text areas are only changes when asked
BT.db.areas.outgoing.x = 230
BT:ImportSettings('BTF1:{areas={outgoing={x=-500,y=40}}}')
assertEq(BT.db.areas.outgoing.x, 230, "your text areas stay where they are")
BT:ImportSettings('BTF1:{areas={outgoing={x=-500,y=40}}}', true)
assertEq(BT.db.areas.outgoing.x, -500, "unless you ask for their places too")
BT.db.areas.outgoing.x, BT.db.areas.outgoing.y = 305, 20
BT:ImportSettings(text)
assertEq(BT.Deserialize('{a="x\\"y",b={1=2,2=-3.5}}').a, 'x"y', "quotes inside words")
SlashCmdList.BATTLETEXTFOREVER("export")
assertEq(BT.copyWindow.edit:GetText():sub(1, 5), "BTF1:", "/btf export shows it to copy")
SlashCmdList.BATTLETEXTFOREVER("import")
assertEq(BT.copyWindow.edit:GetText(), "", "/btf import: an empty box")
BT.copyWindow.edit:SetText("not settings")
BT.copyWindow.action.__scripts.OnClick(BT.copyWindow.action)
assert(not (BT.confirmWindow and BT.confirmWindow:IsShown()), "text that isn't settings asks nothing")
assert(LOG[#LOG]:find("couldn't import", 1, true), "and says why in chat")
BT.copyWindow.edit:SetText(text)
BT.db.fontSize = 20
BT.copyWindow.action.__scripts.OnClick(BT.copyWindow.action)
assertEq(BT.db.fontSize, 20, "Import asks first")
assertEq(BT.confirmWindow:IsShown(), true, "in a small window")
assert(BT.confirmWindow.text:GetText():find("settings every character shares", 1, true), "saying whose settings change")
BT.confirmWindow.no.__scripts.OnClick(BT.confirmWindow.no)
assertEq(BT.db.fontSize, 20, "Cancel changes nothing")
BT.copyWindow.action.__scripts.OnClick(BT.copyWindow.action)
BT.confirmWindow.yes.__scripts.OnClick(BT.confirmWindow.yes)
assertEq(BT.db.fontSize, 27, "Import reads the box")
assertEq(BT.copyWindow:IsShown(), false, "and closes it")
for k in pairs(BT.db) do BT.db[k] = nil end
for k, v in pairs(saved) do BT.db[k] = v end
BT.db.colors = {}
BT:ApplySettings()
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
-- A burst of area crits: no more held than fit in the area (BT-008)
do
    clear()
    local a = BT.areas.outgoing
    local most = math.floor(BT:AreaHeight(a) / (30 + 4))
    local top = 0
    for i = 1, most + 6 do
        log(hit("Blizzard", 10, 100 + i, "Frost", "(Critical)"))
        for _, o in ipairs(a.active) do top = math.max(top, o.slot or 0) end
    end
    assert(top < most, "crits stay inside the area (top place " .. top .. " of " .. most .. ")")
    Advance(0.1)
    local held = 0
    for _, o in ipairs(a.active) do if o.sticky then held = held + 1 end end
    assertEq(held, most, "the oldest made way for the newest")
    clear()
end
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
-- A hit you partly blocked: the game says so, not by how much (a CurseForge request)
do
fire("UNIT_COMBAT", "player", "WOUND", "BLOCK_REDUCED", 230, 1)
assertEq(last("incoming"), "-230 |cffb0b0b0(blocked)|r", "partly blocked: marked")
fire("UNIT_COMBAT", "player", "WOUND", "", 233, 1)
assertEq(last("incoming"), "-233", "not blocked: no mark")
local realEmit = BT.Emit
local gotAfter
BT.Emit = function(self, area, text, color, opts) gotAfter = opts and opts.after return realEmit(self, area, text, color, opts) end
fire("UNIT_COMBAT", "player", "WOUND", "BLOCK_REDUCED", Secret(230), 1)
assertEq(gotAfter, " |cffb0b0b0(blocked)|r", "a hidden amount is marked too")
BT.Emit = realEmit
BT.db.inBlocked = false
fire("UNIT_COMBAT", "player", "WOUND", "BLOCK_REDUCED", 231, 1)
assertEq(last("incoming"), "-231", "\"Show blocked\" off: just the number")
local blockedLine = MOB .. " |Haction:SWING_DAMAGE|h|cffff1313Melee|r|h |Haction:SWING_DAMAGE|hhit|h " .. ME
    .. "You|h |cffff1313232|r |cffff1313Physical|r. (150 Blocked) "
log(blockedLine)
assertEq(last("incoming"), "-232", "off: a readable line leaves its blocked amount out too")
BT.db.inBlocked = true
log(blockedLine)
assertEq(last("incoming"), "-232 |cffb0b0b0(150 blocked)|r", "on: a readable line has the amount")
Advance(4)
fire("UNIT_COMBAT", "player", "WOUND", "", 241, 1)
assertEq(last("incoming"), "-241", "the log's last line 4 seconds ago: a hit on you shows from UNIT_COMBAT")
-- GitHub #33: a magic hit on you is in its school's color, with the school's name; physical stays red
do
    local function colorIs(c)
        local a = BT.areas.incoming.active
        local got = a[#a].text.__color
        return got[1] == c[1] and got[2] == c[2] and got[3] == c[3]
    end
    local SHADOW, FIRE, FROST = ns.S.MASK_COLORS[32], ns.S.MASK_COLORS[4], ns.S.MASK_COLORS[16]
    assertEq(BT.DEFAULTS.inSchools, true, "schools on to start with")
    fire("UNIT_COMBAT", "player", "WOUND", "", 120, 32)
    assertEq(last("incoming"), "-120 Shadow", "a shadow hit names its school")
    assert(colorIs(SHADOW), "in shadow's color")
    fire("UNIT_COMBAT", "player", "WOUND", "", 121, 1)
    assertEq(last("incoming"), "-121", "a physical hit: just the number")
    assert(colorIs(BT.TEXT_COLORS.inDamage), "in the damage color")
    fire("UNIT_COMBAT", "player", "WOUND", "", 122, 48)
    assertEq(last("incoming"), "-122 Frost", "a mix of schools (Frost and Shadow) goes by its first")
    assert(colorIs(FROST), "in its color")
    fire("UNIT_COMBAT", "player", "WOUND", "BLOCK_REDUCED", 123, 4)
    assertEq(last("incoming"), "-123 Fire |cffb0b0b0(blocked)|r", "the school goes before the blocked note")
    local realEmit = BT.Emit
    local gotAfter, gotColor
    BT.Emit = function(self, area, text, color, opts)
        gotAfter, gotColor = opts and opts.after, color
        return realEmit(self, area, text, color, opts)
    end
    fire("UNIT_COMBAT", "player", "WOUND", "", Secret(124), 4)
    assertEq(gotAfter, " Fire", "a hidden amount still has its school (the school isn't hidden)")
    assertEq(gotColor, FIRE, "and its color")
    fire("UNIT_COMBAT", "player", "WOUND", "", Secret(125), Secret(4))
    assertEq(gotAfter, nil, "a hidden school: no word")
    assertEq(gotColor, BT.TEXT_COLORS.inDamage, "and the damage color")
    BT.Emit = realEmit
    BT.db.inSchools = false
    fire("UNIT_COMBAT", "player", "WOUND", "", 126, 32)
    assertEq(last("incoming"), "-126", "\"Damage schools\" off: just the number")
    assert(colorIs(BT.TEXT_COLORS.inDamage), "off: the damage color")
    BT.db.inSchools = true
    -- From a readable log line: its school word, left out when the spell's name says it
    log(hitMe("Shadow Bolt", 686, 84, "Shadow"))
    assertEq(last("incoming"), "-84 Shadow Bolt", "the name says the school: not twice")
    assert(colorIs(SHADOW), "in shadow's color")
    log(hitMe("Curse of Agony", 980, 15, "Shadow"))
    assertEq(last("incoming"), "-15 Shadow Curse of Agony", "a name that doesn't: the school before it")
    log(hitMe("Rend", 772, 9, "Physical"))
    assertEq(last("incoming"), "-9 Rend", "physical: no word")
    assert(colorIs(BT.TEXT_COLORS.inDamage), "in the damage color")
    clear()
    Advance(4)
end
BT.fromLog = nil   -- (the log stops delivering)
end
clear()
-- A mob's special attack arrives in two parts, one of them for nothing: that's no miss
Advance(0.1)
local incomingSoFar = #lines("incoming")
fire("UNIT_COMBAT", "player", "WOUND", "", 0, 1)
fire("UNIT_COMBAT", "player", "WOUND", "", 33, 1)
assertEq(#lines("incoming"), incomingSoFar + 1, "a hit for nothing beside a blow that landed isn't shown")
assertEq(last("incoming"), "-33", "only the blow")
Advance(0.1)
fire("UNIT_COMBAT", "player", "WOUND", "", 34, 1)
fire("UNIT_COMBAT", "player", "WOUND", "", 0, 1)
assertEq(last("incoming"), "-34", "whichever part comes first")
Advance(0.1)
fire("UNIT_COMBAT", "player", "WOUND", "", 0, 1)
Advance(0.1)
fire("UNIT_COMBAT", "player", "WOUND", "", 35, 1)
assertEq(table.concat(lines("incoming"), " "):match("Miss %-35$"), "Miss -35", "in different frames they're two attacks")
Advance(0.1)
fire("UNIT_COMBAT", "player", "WOUND", "ABSORB", 0, 1)
fire("UNIT_COMBAT", "player", "WOUND", "", 36, 1)
assertEq(table.concat(lines("incoming"), " "):match("Absorb %-36$"), "Absorb -36", "a hit that says what stopped it is its own attack")
WithoutTimers(function()
    fire("UNIT_COMBAT", "player", "WOUND", "", 0, 1)
    assertEq(BT.areas.incoming.active[#BT.areas.incoming.active].text:GetText(), "Miss", "no timers: shown at once")
end)
BT.db.inMisses = false
Advance(0.1)
local shownBefore2 = #lines("incoming")
fire("UNIT_COMBAT", "player", "WOUND", "", 0, 1)
assertEq(#lines("incoming"), shownBefore2, "avoids turned off: not shown")
BT.db.inMisses = true
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
assertEq(last("incoming"), "+10", "a druid's power gain: no word, the game doesn't say which power (BT-017)")
STATE.class = "WARRIOR"
fire("UNIT_COMBAT", "player", "ENERGIZE", "", 10, 1)
assertEq(last("incoming"), "+10 Rage", "a warrior's says what it is")
-- Shield Specialization (1.35.0, CurseForge): a paladin with the talent gets 4% mana back on a
-- block, once every 3 seconds. The mana comes with no spell; next to a block it's named.
do
    local GAME = getmetatable(_G).__index
    local powerType = GAME.UnitPowerType
    GAME.UnitPowerType = function() return 0, "MANA" end
    STATE.class = "PALADIN"
    STATE.spellNames[20150] = "Shield Specialization"
    STATE.spellIcons[20150] = 134952
    BT.lastBlock, BT.shieldSpecAt = nil, nil
    local function lastMana()
        local l = lines("incoming")
        for i = #l, 1, -1 do
            if l[i]:find("Mana", 1, true) or l[i]:find("<secret", 1, true) then return l[i] end
        end
    end
    Advance(5)
    clear()
    fire("UNIT_COMBAT", "player", "ENERGIZE", "", 40, 1)
    assertEq(lastMana(), "+40 Mana", "without the talent, mana is plain mana")
    STATE.knownSpells[20150] = true
    fire("UNIT_COMBAT", "player", "BLOCK", "", 0, 1)
    fire("UNIT_COMBAT", "player", "ENERGIZE", "", 40, 1)
    Advance(0.3)
    assertEq(lastMana(), "+40 Mana Shield Specialization", "mana with a block: Shield Specialization's")
    Advance(4)
    fire("UNIT_COMBAT", "player", "ENERGIZE", "", 41, 1)
    Advance(0.1)
    fire("UNIT_COMBAT", "player", "WOUND", "BLOCK_REDUCED", 20, 1)
    Advance(0.2)
    assertEq(lastMana(), "+41 Mana Shield Specialization", "the block can come just after the mana")
    Advance(1)
    fire("UNIT_COMBAT", "player", "BLOCK", "", 0, 1)
    fire("UNIT_COMBAT", "player", "ENERGIZE", "", 42, 1)
    Advance(0.3)
    assertEq(lastMana(), "+42 Mana", "within 3 seconds of the last one: something else")
    Advance(4)
    fire("UNIT_COMBAT", "player", "ENERGIZE", "", 43, 1)
    Advance(0.3)
    assertEq(lastMana(), "+43 Mana", "no block: plain mana")
    fire("UNIT_COMBAT", "player", "BLOCK", "", 0, 1)
    fire("UNIT_COMBAT", "player", "ENERGIZE", "", Secret(44), 1)
    Advance(0.3)
    assertEq(lastMana(), "<secret fmt>", "a hidden amount is named too")
    SetIcons(true)
    Advance(4)
    fire("UNIT_COMBAT", "player", "BLOCK", "", 0, 1)
    fire("UNIT_COMBAT", "player", "ENERGIZE", "", 45, 1)
    Advance(0.3)
    assertEq(lastMana(), "+45 Mana |T134952:0|t Shield Specialization", "with its icon when icons are on")
    SetIcons(false)
    STATE.knownSpells[20150] = nil
    GAME.UnitPowerType = powerType
    BT.lastBlock, BT.shieldSpecAt = nil, nil
    clear()
    STATE.class = "WARRIOR"
    fire("UNIT_COMBAT", "player", "ENERGIZE", "", 10, 1)   -- (the line the next part expects)
end
STATE.class = "DRUID"
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
-- Someone else's heal landing at the same moment as yours still shows (only your
-- heal's own amount is taken for the log's line)
fire("UNIT_COMBAT", "player", "HEAL", "", 380, 8)
fire("UNIT_COMBAT", "player", "HEAL", "", 120, 8)
log(healMe("Healing Touch", 5185, 380))
Advance(0.3)
local healed = table.concat(lines("incoming"), " / ")
assertEq(healed, "+380 Healing Touch / +120", "yours once, with its name, and the other heal too")
clear()
-- An amount the game hides can't be compared: a heal of yours just then is taken for it
fire("UNIT_COMBAT", "player", "HEAL", "", Secret(380), 8)
log(healMe("Healing Touch", 5185, 380))
Advance(0.3)
assertEq(#lines("incoming"), 1, "a hidden amount isn't shown twice either")
clear()

step("a heal you cast on yourself is named, though UNIT_COMBAT has no name")
-- (a player's report: Holy Light on yourself showed only "+number")
STATE.spellNames[635], STATE.spellIcons[635] = "Holy Light", 135920
STATE.helpful = { [635] = true }
SetIcons(true)
local savedTarget = STATE.who.target
STATE.who.target = nil
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hl", 635)
fire("UNIT_COMBAT", "player", "HEAL", "", 250, 2)
Advance(0.3)
assertEq(last("incoming"), "+250 |T135920:0|t Holy Light", "with its icon and name")
fire("UNIT_COMBAT", "player", "HEAL", "", 90, 2)
Advance(0.3)
assertEq(last("incoming"), "+90", "only that one heal: the next one is someone else's")
clear()
fire("UNIT_COMBAT", "player", "HEAL", "", 260, 2)   -- (the heal first, then the cast, in one frame)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hl2", 635)
Advance(0.3)
assertEq(last("incoming"), "+260 |T135920:0|t Holy Light", "either way round")
clear()
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hl3", 635)
Advance(1)
fire("UNIT_COMBAT", "player", "HEAL", "", 70, 2)
Advance(0.3)
assertEq(last("incoming"), "+70", "a heal a second after your cast isn't it")
clear()
STATE.unit.healTestMob = { enemy = true }
STATE.who.target = "healTestMob"   -- an enemy targeted: the heal goes on you
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hl4", 635)
fire("UNIT_COMBAT", "player", "HEAL", "", 240, 2)
Advance(0.3)
assertEq(last("incoming"), "+240 |T135920:0|t Holy Light", "with an enemy targeted")
clear()
STATE.unit.friendA = STATE.unit.friendA or { enemy = false }
STATE.who.party1 = "friendA"
STATE.who.target = "friendA"   -- a friend targeted: it went to them
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hl5", 635)
fire("UNIT_COMBAT", "player", "HEAL", "", 120, 2)
Advance(0.3)
assertEq(last("incoming"), "+120", "a heal on you while you heal a friend isn't your spell")
STATE.who.party1 = nil
clear()
STATE.unit.vendor = { enemy = false, npc = true }
STATE.who.target = "vendor"   -- a vendor can't be healed: the game casts it on you
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hl6", 635)
fire("UNIT_COMBAT", "player", "HEAL", "", 230, 2)
Advance(0.3)
assertEq(last("incoming"), "+230 |T135920:0|t Holy Light", "with a vendor targeted, the heal is on you and named")
STATE.unit.vendor = nil
clear()
STATE.who.target = nil
STATE.helpful = {}
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-x", 635)
fire("UNIT_COMBAT", "player", "HEAL", "", 120, 2)
Advance(0.3)
assertEq(last("incoming"), "+120", "a spell that isn't helpful never names a heal")
clear()
STATE.helpful = { [635] = true }
SetIcons(false)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hl6", 635)
fire("UNIT_COMBAT", "player", "HEAL", "", 250, 2)
Advance(0.3)
assertEq(last("incoming"), "+250 Holy Light", "the name alone with icons off")
SetIcons(true)
clear()
-- Hidden by a setting, a heal of yours still counts in the fight (BT-010)
do
    BT.fight = { start = GetTime(), damage = 0, heal = 0 }
    BT.db.inHeals = false
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hl7", 635)
    fire("UNIT_COMBAT", "player", "HEAL", "", 200, 2)
    Advance(0.3)
    assertEq(#lines("incoming") + #lines("heal"), 0, "\"Heals you get\" off: not shown")
    assertEq(BT.fight.heal, 200, "but counted in the fight")
    BT.db.inHeals = true
    BT.db.spellRules, BT.rulesByName = { { name = "Holy Light", hide = true } }, nil
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hl8", 635)
    fire("UNIT_COMBAT", "player", "HEAL", "", 100, 2)
    Advance(0.3)
    assertEq(#lines("incoming") + #lines("heal"), 0, "a hidden spell: not shown")
    assertEq(BT.fight.heal, 300, "but counted too")
    BT.db.spellRules, BT.rulesByName = {}, nil
    BT.db.inHeals = false
    fire("UNIT_COMBAT", "player", "HEAL", "", 80, 2)
    Advance(0.3)
    assertEq(#lines("incoming") + #lines("heal"), 0, "someone else's heal with \"Heals you get\" off: not shown")
    BT.db.inHeals = true
    BT.fight = nil
    clear()
end
-- A heal over time on yourself: its ticks are heals on you with no name (a player's report:
-- a druid's HoT ticks had no icon)
STATE.spellNames[774], STATE.spellIcons[774] = "Rejuvenation", 136081
BT.iconCache = nil
STATE.helpful[774] = true
STATE.who.target = "healTestMob"   -- (an enemy targeted: it goes on you)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-rj", 774)
Advance(3)
fire("UNIT_COMBAT", "player", "HEAL", "", 30, 8)
Advance(0.3)
assertEq(last("incoming"), "+30 |T136081:0|t Rejuvenation", "a tick of your heal over time on you")
Advance(1.2)
fire("UNIT_COMBAT", "player", "HEAL", "", 90, 8)
Advance(0.3)
assertEq(last("incoming"), "+90", "a heal off its beat is someone else's")
Advance(1.2)   -- (6s after the cast: on its beat)
fire("UNIT_COMBAT", "player", "HEAL", "", 30, 2)
Advance(0.3)
assertEq(last("incoming"), "+30", "a heal of another school isn't it")
Advance(2.7)   -- (9s after the cast)
fire("UNIT_COMBAT", "player", "HEAL", "", 30, 8)
Advance(0.3)
assertEq(last("incoming"), "+30 |T136081:0|t Rejuvenation", "the next tick on its beat")
local onEnemy = false
for _, list in pairs(BT.dots or {}) do if list.Rejuvenation then onEnemy = true end end
assertEq(onEnemy, false, "and it isn't taken for a tick on the enemy you had targeted")
Advance(30)
fire("UNIT_COMBAT", "player", "HEAL", "", 30, 8)
Advance(0.3)
assertEq(last("incoming"), "+30", "long after it ran out: not it")
-- A player's debug log (Regrowth then Rejuvenation on themself, at full health): every
-- tick on its beat, but the game doesn't give a heal on you its spell's school. A tick
-- with Physical or no school is still named; another magic school still isn't (above).
clear()
BT.selfHots = nil
STATE.spellNames[8938], STATE.spellIcons[8938] = "Regrowth", 136085
STATE.spellNames[2090], STATE.spellIcons[2090] = "Rejuvenation", 136081
BT.iconCache = nil
STATE.helpful[8938], STATE.helpful[2090] = true, true
do
    local now = 315.05
    local function at(t) Advance(t - now) now = t end
    fire("UNIT_COMBAT", "player", "HEAL", "", 150, 1)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-rg-log", 8938)
    at(315.69)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-rj-log", 2090)
    local named = {}
    for i, t in ipairs({ 317.99, 318.73, 320.98, 321.71, 324.03, 324.67 }) do
        at(t)
        fire("UNIT_COMBAT", "player", "HEAL", "", 20 + i, i % 2 == 1 and 1 or 0)
        Advance(0.3) now = now + 0.3
        named[#named + 1] = last("incoming")
    end
    assertEq(named[1], "+21 |T136085:0|t Regrowth", "Regrowth's tick with Physical as its school, from the log")
    assertEq(named[2], "+22 |T136081:0|t Rejuvenation", "Rejuvenation's tick with no school")
    assertEq(named[5], "+25 |T136085:0|t Regrowth", "Regrowth's third tick")
    assertEq(named[6], "+26 |T136081:0|t Rejuvenation", "Rejuvenation's third tick")
end
-- Regrowth's own heal as it lands (the same player: its ticks were named, it wasn't).
-- Its buff on you is learned as a buff of yours, yet the cast still names its heal;
-- Rejuvenation (no heal as it lands) still names nothing.
clear()
BT.selfHots = nil
BT.db.learnedBuffs = { Regrowth = true, Rejuvenation = true }
fire("UNIT_COMBAT", "player", "HEAL", "", 185, 1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-rg-buff", 8938)
Advance(0.3)
assertEq(last("incoming"), "+185 |T136085:0|t Regrowth", "Regrowth's heal as it lands, though it leaves a buff")
Advance(1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-rj-buff", 2090)
fire("UNIT_COMBAT", "player", "HEAL", "", 99, 1)
Advance(0.3)
assertEq(last("incoming"), "+99", "Rejuvenation lands with no heal of its own: a heal then isn't it")
BT.db.learnedBuffs = nil
BT.selfHots = nil
clear()
STATE.who.party1 = "friendA"
STATE.who.target = "friendA"
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-rj2", 774)
Advance(3)
fire("UNIT_COMBAT", "player", "HEAL", "", 30, 8)
Advance(0.3)
assertEq(last("incoming"), "+30", "cast on a friend: its ticks aren't on you")
STATE.who.party1 = nil
clear()
-- Heals the game doesn't name, with their number hidden, can't be held to "Hide heals below"
-- (a player's report: Thrill of Adventure's small heals kept showing): a switch hides them
BT.db.minHeal = 50
fire("UNIT_COMBAT", "player", "HEAL", "", Secret(12), 8)
Advance(0.3)
assertEq(#lines("incoming"), 1, "a hidden number always shows, whatever \"Hide heals below\" says")
BT.db.inOtherHeals = false
fire("UNIT_COMBAT", "player", "HEAL", "", Secret(12), 8)
Advance(0.3)
assertEq(#lines("incoming"), 1, "\"Unnamed heals on you\" off: hidden")
fire("UNIT_COMBAT", "player", "HEAL", "", 120, 8)
Advance(0.3)
assertEq(#lines("incoming"), 1, "readable ones too")
STATE.who.target = nil
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-rj3", 774)
fire("UNIT_COMBAT", "player", "HEAL", "", Secret(300), 8)
Advance(0.3)
assertEq(#lines("incoming"), 2, "your own heal still shows: it has a name")
BT.db.inOtherHeals, BT.db.minHeal = true, 0
clear()
-- Thrill of Adventure (Tyler's druid logs, 1.40.3): after your killing blow, five unnamed heals on
-- you 2s apart, the first ~2s after your last hit. The kill can't be read: the last hit of yours
-- on a mob (NoteFought) and the beat name them. Not in dungeons.
-- (kept short: the group steps later on lean on spells cast earlier, within 45s)
do
local thrillFought = BT.fought
BT.selfHots, BT.thrill, BT.fought = nil, nil, nil
BT:NoteFought("Creature-thrill", GetTime())
Advance(1.06)   -- (the first heal 1.06s after the killing hit, Tyler's second log)
local thrillDebug = BT.db.debug
BT.db.debug, BT.recorded = true, {}
fire("UNIT_COMBAT", "player", "HEAL", "", Secret(20), 1)
Advance(0.3)
assert(table.concat(BT.recorded, "\n"):find("player heal: named Thrill of Adventure", 1, true), "a hidden one: named too")
BT.db.debug = thrillDebug
Advance(1.7)
for k = 2, 5 do
    fire("UNIT_COMBAT", "player", "HEAL", "", 20, 1)
    Advance(0.3)
    assert(last("incoming"):find("Thrill of Adventure", 1, true), "Thrill of Adventure's heal " .. k)
    Advance(k == 2 and 1.75 or 1.7)
end
fire("UNIT_COMBAT", "player", "HEAL", "", 20, 1)
Advance(0.3)
assert(not last("incoming"):find("Thrill", 1, true), "a sixth heal on its beat isn't it")
Advance(3)
BT.thrill, BT.fought = nil, nil
BT:NoteFought("Creature-thrill", GetTime())
Advance(0.5)
fire("UNIT_COMBAT", "player", "HEAL", "", 20, 1)
Advance(0.3)
assert(not last("incoming"):find("Thrill", 1, true), "a heal 0.5s after your last hit isn't it")
Advance(3)
BT.thrill, BT.fought = nil, nil
BT:NoteFought("Creature-thrill", GetTime())
Advance(2)
STATE.instance = "party"
fire("UNIT_COMBAT", "player", "HEAL", "", 20, 1)
Advance(0.3)
assert(not last("incoming"):find("Thrill", 1, true), "not in a dungeon")
STATE.instance = nil
BT.thrill, BT.fought = nil, thrillFought
clear()
end
BT.selfHots, BT.iconCache = nil, nil
STATE.spellIcons[774] = nil
STATE.helpful = nil
STATE.unit.healTestMob = nil
STATE.who.target = savedTarget
clear()

step("the Healing area")
BT.db.healArea = true
log(real("heal on a friend"))
assertEq(last("heal"), "Rejuvenation +61", "a heal you do")
assertEq(#lines("outgoing"), 0, "isn't with your hits")
fire("UNIT_COMBAT", "player", "HEAL", "", 120, 8)
Advance(0.3)
assertEq(last("heal"), "+120", "a heal you get")
assertEq(#lines("incoming"), 0, "isn't with the damage you take")
log(real("heal on a friend, overheal, crit"))
assertEq(last("heal"), "Flash Heal +1,034 |cffb0b0b0(200 over)|r", "overhealing is noted")
BT.db.healOver = false
log(real("heal on a friend, overheal, crit"))
assertEq(last("heal"), "Flash Heal +1,034", "unless it's turned off")
BT.db.healOver = true
local before = #lines("heal")
BT.db.minHeal = 100
log(real("heal on a friend"))
fire("UNIT_COMBAT", "player", "HEAL", "", 50, 8)
Advance(0.3)
assertEq(#lines("heal"), before, "heals below \"Hide heals below\" are hidden, given or got")
BT.db.minHeal = 0
BT.db.inHeals = false
fire("UNIT_COMBAT", "player", "HEAL", "", 120, 8)
Advance(0.3)
assertEq(#lines("heal"), before, "heals you get can be turned off")
BT.db.inHeals = true
local area = BT.areas.heal
assertEq(BT:AreaHeight(area), math.floor(BT.db.height * 0.6), "a shorter area than the damage ones")
assertEq(BT:ScrollTime(area), BT.db.scrollTime, "scrolling at the usual pace")
BT.db.healArea = false
clear()

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
-- A spell with an icon shows it, on lines about you too
STATE.spellIcons[133], STATE.spellIcons[5185], BT.iconCache = 135812, 136041, nil
SetIcons(true)
fire("UNIT_COMBAT", "player", "WOUND", "", 84, 4)
log(hitMe("Fireball", 133, 84, "Fire"))
assertEq(last("incoming"), "-84 |T135812:0|t Fireball", "a spell that hits you, with its icon")
log(healMe("Healing Touch", 5185, 380))
assertEq(last("incoming"), "+380 |T136041:0|t Healing Touch", "a heal you get, with its icon")
SetNames(false)
fire("UNIT_COMBAT", "player", "WOUND", "", 84, 4)
log(hitMe("Fireball", 133, 84, "Fire"))
assertEq(last("incoming"), "-84 Fire |T135812:0|t", "names off: the icon alone, and the school (it was in the name)")
SetNames(true); SetIcons(false)
fire("UNIT_COMBAT", "player", "WOUND", "", 84, 4)
log(hitMe("Fireball", 133, 84, "Fire"))
assertEq(last("incoming"), "-84 Fireball", "icons off: no icon anywhere")
-- Each section has its own boxes
SetIcons(true)
BT.db.inIcons = false
fire("UNIT_COMBAT", "player", "WOUND", "", 84, 4)
log(hitMe("Fireball", 133, 84, "Fire"))
assertEq(last("incoming"), "-84 Fireball", "Incoming's icons off")
log(healMe("Healing Touch", 5185, 380))
assertEq(last("incoming"), "+380 |T136041:0|t Healing Touch", "a heal follows Healing's boxes, not Incoming's")
BT.db.inIcons, BT.db.healNames = true, false
log(healMe("Healing Touch", 5185, 380))
assertEq(last("incoming"), "+380 |T136041:0|t", "Healing's names off")
fire("UNIT_COMBAT", "player", "WOUND", "", 84, 4)
log(hitMe("Fireball", 133, 84, "Fire"))
assertEq(last("incoming"), "-84 |T135812:0|t Fireball", "and Incoming keeps its names")
BT.db.healNames = true
-- The old single boxes become the new ones they were split into
local old = { icons = false, spellNames = true, outNames = false }
BT:MoveOldSettings(old)
assertEq(old.outIcons, false, "icons off carries over to Outgoing")
assertEq(old.inIcons, false, "to Incoming")
assertEq(old.healIcons, false, "to Healing")
assertEq(old.nIcons, false, "and to Notifications")
assertEq(old.inNames, true, "names carry over")
assertEq(old.outNames, false, "but never over a new setting already made")
assertEq(old.icons, nil, "the old setting goes")
assertEq(old.spellNames, nil, "both of them")
STATE.spellIcons[133], STATE.spellIcons[5185], BT.iconCache = nil, nil, nil
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
assertEq(last("outgoing"), "27", "your hit on your target, with your line")
Advance(1.3)
fire("UNIT_COMBAT", "target", "WOUND", "", 99, 1)
assertEq(#lines("outgoing"), 1, "alone, once the lines arrive, a hit needs one of yours too: someone else's hit on your target")
-- (what follows is about how hits are shown, so as before Start BattleText is clicked: alone, every hit is yours)
BT.hiddenSeen, BT.credits, BT.hiddenAt = nil, nil, nil
clear()
Advance(0.1)
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
-- In another language the game's own word is used (GitHub #36: German "Streifschlag")
do local glanceWord, crushWord = TEXT_MODE_A_STRING_RESULT_GLANCING, TEXT_MODE_A_STRING_RESULT_CRUSHING
local function game(key, v) rawset(_G, "TEXT_MODE_A_STRING_RESULT_" .. key, v) end
STATE.locale = "deDE"
game("GLANCING", "(Streifschlag)")
fire("UNIT_COMBAT", "target", "WOUND", "GLANCING", 12, 1)
assertEq(last("outgoing"), "12 |cffb0b0b0(Streifschlag)|r", "German: a glancing blow in the game's word")
assertEq(BT:HitNote("glancing"), "Streifschlag", "the note itself")
game("CRUSHING", "(Schmetternd)")
assertEq(BT:HitNote("crushing"), "Schmetternd", "a crushing blow too")
game("GLANCING", Secret("(Streifschlag)"))
assertEq(BT:HitNote("glancing"), "glancing", "a hidden game word falls back to English")
game("GLANCING", "")
assertEq(BT:HitNote("glancing"), "glancing", "and so does an empty one")
assertEq(BT:HitNote("blocked"), "blocked", "a note the game has no word for stays English")
STATE.locale = "enUS"
game("GLANCING", glanceWord)
game("CRUSHING", crushWord) end
assertEq(BT:HitNote("glancing"), "glancing", "English: the addon's own lowercase word")
fire("UNIT_COMBAT", "target", "WOUND", "", Secret(40), 1)
assertEq(last("outgoing"), "<secret fmt>", "a hidden amount is still shown by the game")
clear()
fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
assertEq(last("outgoing"), "Dodge", "your attack was dodged")
fire("UNIT_COMBAT", "target", "WOUND", "", 0, 1)
assertEq(last("outgoing"), "Miss", "a hit for nothing is a miss")
fire("UNIT_COMBAT", "target", "WOUND", "ABSORB", 0, 1)
assertEq(last("outgoing"), "Absorb", "or says what stopped it")
-- The miss word: a translation in Locales wins, then the game's word, then English (GitHub #47)
do local L, blockWord = ns.L, rawget(_G, "BLOCK")
rawset(_G, "BLOCK", "Blocken")
fire("UNIT_COMBAT", "target", "BLOCK", "", 0, 1)
assertEq(last("outgoing"), "Blocken", "a block in the game's word")
L["Block"] = "방어"
fire("UNIT_COMBAT", "target", "BLOCK", "", 0, 1)
assertEq(last("outgoing"), "방어", "a translated miss word wins over the game's")
fire("UNIT_COMBAT", "target", "WOUND", "BLOCK", 0, 1)
assertEq(last("outgoing"), "방어", "also on a wound for nothing that was blocked")
rawset(L, "Block", nil)
rawset(_G, "BLOCK", Secret("Block"))
assertEq(BT.MissText("BLOCK"), "Block", "a hidden game word falls back to English")
rawset(_G, "BLOCK", "")
assertEq(BT.MissText("BLOCK"), "Block", "and so does an empty one")
rawset(_G, "BLOCK", blockWord)
assertEq(BT.MissText("SOMETHING_NEW"), "Miss", "an unknown way of missing is a miss") end
BT.db.outMisses = false
fire("UNIT_COMBAT", "target", "PARRY", "", 0, 1)
assertEq(#lines("outgoing"), 6, "misses turned off")
BT.db.outMisses = true
BT.db.minDamage = 40
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(#lines("outgoing"), 6, "hits below \"Hide hits below\" are hidden")
BT.db.minDamage = 0
BT.db.outDamage = false
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(#lines("outgoing"), 6, "damage turned off")
BT.db.outDamage = true
fire("UNIT_COMBAT", "target", "ENERGIZE", "", 10, 1)
assertEq(#lines("outgoing"), 6, "a mob gaining power is nothing of yours")
clear()
-- Someone else's fight: you target a mob another player tagged and is fighting
local mobA, wasSeen = STATE.unit[STATE.who.target], BT.hiddenSeen
local wasTarget, wasTT = mobA.target, STATE.who.targettarget
mobA.tapDenied, mobA.target, BT.hiddenSeen, STATE.who.targettarget = true, "friend", nil, nil
fire("UNIT_COMBAT", "target", "WOUND", "", 25, 32)
fire("UNIT_COMBAT", "target", "WOUND", "", 24, 32)
fire("UNIT_COMBAT", "target", "PARRY", "", 0, 1)
assertEq(#lines("outgoing"), 0, "their hits on your target aren't yours")
BT.hiddenSeen, BT.credits = true, nil
fire("UNIT_COMBAT", "target", "WOUND", "", 25, 32)
assertEq(#lines("outgoing"), 0, "with the combat lines arriving: still not, without a line of yours")
BT.hiddenSeen = nil
mobA.target = "me"
fire("UNIT_COMBAT", "target", "WOUND", "", 31, 1)
assertEq(last("outgoing"), "31", "unless it turns on you: then it's your fight too")
mobA.tapDenied, mobA.target, BT.hiddenSeen, STATE.who.targettarget = nil, wasTarget, wasSeen, wasTT
fire("UNIT_COMBAT", "target", "WOUND", "", 26, 1)
assertEq(last("outgoing"), "26", "a mob nobody else tagged: your target's hits are yours, as before")
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
-- Your heals land with your cast (names off here, to read the numbers)
local castN = 0
local function healed(...)
    castN = castN + 1
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-h-" .. castN, 5185)
    fire("UNIT_COMBAT", ...)
end
local namesWere, iconsWere = BT.db.healNames, BT.db.healIcons
BT.db.healNames, BT.db.healIcons = false, false
healed("target", "HEAL", "CRITICAL", 120, 2)
assertEq(last("outgoing"), "+120", "a heal on the friend you're targeting")
assert(isColor(newest(), C.heal), "in the heal color")
assertEq(newest().sticky, true, "a crit heal holds")
healed("target", "HEAL", "", Secret(90), 2)
assertEq(last("outgoing"), "<secret fmt>", "with a hidden amount too")
BT.db.outHeals = false
healed("target", "HEAL", "", 120, 2)
assertEq(#lines("outgoing"), 2, "heals turned off")
BT.db.outHeals = true
healed("target", "HEAL", "", 0, 2)
assertEq(#lines("outgoing"), 2, "a heal for nothing isn't shown")
BT.db.healArea = true
healed("target", "HEAL", "", 130, 2)
assertEq(last("heal"), "+130", "with the Healing area on, a heal on a friend goes there")
assertEq(#lines("outgoing"), 2, "and not with your hits")
BT.db.minHeal = 200
healed("target", "HEAL", "", 150, 2)
assertEq(#lines("heal"), 1, "heals below \"Hide heals below\" are hidden")
healed("target", "HEAL", "", Secret(90), 2)
assertEq(last("heal"), "<secret fmt>", "a hidden amount can't be compared, so it shows")
BT.db.healNames, BT.db.healIcons = namesWere, iconsWere
BT.db.minHeal, BT.db.healArea = 0, false
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
SetIcons(true)
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
SetNames(false); SetIcons(false)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-5", 16827)
fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
assertEq(last("outgoing"), "Dodge", "names and icons turned off")
SetNames(true); SetIcons(true)
Advance(0.1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-6", 16827)
fire("UNIT_COMBAT", "target", "PARRY", "", 0, 1)
assertEq(last("outgoing"), "|T132140:0|t Claw Parry", "a named miss")
SetIcons(false)
clear()

-- A line that can be read is shown from the line, not a second time from the unit
-- (the line's link names the mob: here the target is that mob)
do
local targetGuid = STATE.unit[STATE.who.target].guid
STATE.unit[STATE.who.target].guid = "Creature-0-1-2-3-4-000001"
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
-- Only that mob's: a hit on another mob at the same moment (its line hidden) still shows
STATE.unit.otherMob = { enemy = true, guid = "Creature-0-1-2-3-4-000777", target = "me" }
STATE.who.nameplate7 = "otherMob"
log(hit("Claw", 16827, 50))
fire("UNIT_COMBAT", "nameplate7", "WOUND", "", 31, 1)
assertEq(last("outgoing"), "31", "a readable line only stands in for the hits on the mob it names")
fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
assertEq(#lines("outgoing"), 2, "the named mob's hit is still left to the line")
STATE.unit[STATE.who.target].guid = nil
Advance(0.1)
fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
assertEq(#lines("outgoing"), 2, "a unit with no GUID to go by is left to the line too")
STATE.who.nameplate7, STATE.unit.otherMob = nil, nil
STATE.unit[STATE.who.target].guid = targetGuid
end
clear()
log(hitMe("Fireball", 133, 84, "Fire"))
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(last("outgoing"), "27", "a readable line about someone else's hit doesn't stand in for yours")
clear()

-- Dungeons and raids (addon-restricted maps): the game hides "is nameplate5's target me?".
-- The threat table says it instead, so a mob after you is still your fight.
STATE.restrictedMap = true
STATE.unit.packMob = { enemy = true, guid = "Creature-0-1-2-3-4-000555", target = "me" }
STATE.who.nameplate5 = "packMob"
fire("UNIT_COMBAT", "nameplate5", "DODGE", "", 0, 1)
assertEq(last("outgoing"), "Dodge", "on a restricted map, a mob after you (not targeted) is still your fight")
Advance(0.1)
STATE.unit.packMob.target = "friend"
fire("UNIT_COMBAT", "nameplate5", "PARRY", "", 0, 1)
assertEq(last("outgoing"), "Dodge", "and one after someone else isn't")
STATE.restrictedMap, STATE.who.nameplate5, STATE.unit.packMob = nil, nil, nil
clear()

-- In a group, anyone could have hit the mob. A hidden line says you did
-- something just then: each one vouches for one hit.
STATE.group = true
STATE.who.party1 = "friend"
BT.credits, BT.hiddenSeen = nil, true
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
assertEq(last("outgoing"), "31", "a heal on a party member with no heal of yours going is someone else's")
assertEq(#BT.credits, 1, "and it leaves your line for your own hit")
Advance(0.1)
hidden(14)
STATE.helpful = STATE.helpful or {}
STATE.helpful[5185] = true   -- (the game says Healing Touch is helpful)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-9-1", 5185)
fire("UNIT_COMBAT", "party1", "HEAL", "", 120, 2)
assertEq(last("outgoing"), "Healing Touch +120", "your heal on a party member you aren't targeting")
-- The "My actions" lines don't come for every swing (issues #15, #16: white hits in a group
-- went missing). The game's swing timer event says when you swing: each vouches for one
-- physical hit or miss on your target.
clear()
BT.credits, BT.swings = nil, nil
fire("PLAYER_SWING", 2.6, 0)
Advance(0.6)
fire("UNIT_COMBAT", "target", "WOUND", "", 41, 1)
assertEq(last("outgoing"), "41", "a swing of yours vouches for the white hit after it")
fire("UNIT_COMBAT", "target", "WOUND", "", 99, 1)
assertEq(#lines("outgoing"), 1, "one swing, one hit")
Advance(0.1)
fire("PLAYER_SWING", 1.8, 1)
Advance(0.5)
fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
assertEq(last("outgoing"), "Dodge", "and for the mob dodging it")
Advance(0.1)
fire("PLAYER_SWING", 2.6, 0)
Advance(0.1)
fire("UNIT_COMBAT", "target", "WOUND", "", 99, 32)
assertEq(last("outgoing"), "Dodge", "not for a spell's hit (someone's Shadow Bolt)")
Advance(0.1)
STATE.unit.swingMob = { enemy = true, guid = "Creature-0-1-2-3-100-0000C1", target = "me" }
STATE.who.nameplate7 = "swingMob"   -- another mob, after you
fire("UNIT_COMBAT", "nameplate7", "WOUND", "", 99, 1)
fire("UNIT_COMBAT", "nameplate7", "MISS", "", 0, 1)
assertEq(last("outgoing"), "Dodge", "nor for a hit on another mob (you only swing at your target)")
STATE.who.nameplate7, STATE.unit.swingMob = nil, nil
Advance(1.3)
fire("UNIT_COMBAT", "target", "WOUND", "", 99, 1)
assertEq(last("outgoing"), "Dodge", "a swing from long ago vouches for nothing")
clear()
-- A cast's miss has no line ("My actions" leaves misses out): the cast in its frame is enough
STATE.spellNames[6572] = "Revenge"
BT.credits, BT.swings = nil, nil
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-rev", 6572)
fire("UNIT_COMBAT", "target", "MISS", "", 0, 1)
assertEq(last("outgoing"), "Revenge Miss", "your cast missing, in a group")
clear()
-- Issue #16 (a protection warrior's party): a party member's wand hits and white hits on your
-- target showed as yours. Your lines that vouched for nothing in their own frame (Sunder Armor,
-- Shield Block, and the line of a swing PLAYER_SWING already vouched for) were left over, and
-- any hit within 1.2s took one. A line now vouches for a hit in its own frame (or just ahead of
-- it); only a white hit may take an earlier one, and not on your target while your swings are
-- vouched for by PLAYER_SWING.
STATE.spellNames[7405] = "Sunder Armor"
BT.credits, BT.swings, BT.swungAt = nil, nil, nil
fire("PLAYER_SWING", 2.6, 0)
hidden(5441)   -- (your swing's line)
Advance(0.6)
fire("UNIT_COMBAT", "target", "WOUND", "", 41, 1)
assertEq(last("outgoing"), "41", "your white hit, after your swing and its line")
Advance(0.2)
fire("UNIT_COMBAT", "target", "WOUND", "", 98, 1)
assertEq(last("outgoing"), "41", "a party member's white hit doesn't take your swing's line")
Advance(0.1)
fire("UNIT_COMBAT", "target", "WOUND", "", 97, 64)
assertEq(last("outgoing"), "41", "nor does their wand's hit")
Advance(0.1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-sunder", 7405)
hidden(5432)   -- (Sunder Armor's line: it does no damage)
Advance(0.4)
fire("UNIT_COMBAT", "target", "WOUND", "", 96, 64)
assertEq(last("outgoing"), "41", "Sunder Armor's line doesn't vouch for a wand's hit after it")
Advance(0.2)
fire("UNIT_COMBAT", "target", "PARRY", "", 0, 1)
assertEq(last("outgoing"), "41", "nor for someone's white hit being parried")
Advance(0.1)
fire("UNIT_COMBAT", "target", "WOUND", "", 52, 4)
hidden(77)
assertEq(last("outgoing"), "52", "a spell's hit with its line in its frame is still yours")
Advance(0.1)
hidden(78)
Advance(0.11)
fire("UNIT_COMBAT", "target", "WOUND", "", 53, 32)
assertEq(last("outgoing"), "53", "and with its line just ahead of it (a warlock's bolt, real_fight5)")
-- Your pet's lines (with Pet ticked under "Done By") come ahead of its swings too
Advance(0.3)
STATE.pet, STATE.unit.pet = true, { target = STATE.who.target }
hidden(79)
Advance(0.6)
fire("UNIT_COMBAT", "target", "WOUND", "", 19, 1)
assertEq(last("outgoing"), "19", "your pet on your target: a white hit may take an earlier line")
STATE.pet, STATE.unit.pet = false, nil
-- Not swinging (no PLAYER_SWING for a while): an earlier line still vouches for a white hit
Advance(6.5)
hidden(80)
Advance(0.6)
fire("UNIT_COMBAT", "target", "WOUND", "", 27, 1)
assertEq(last("outgoing"), "27", "with no swing of yours lately, a line ahead of a white hit vouches for it")
clear()
BT.hiddenSeen = nil
BT.credits, BT.waitingHits = nil, nil
fire("UNIT_COMBAT", "target", "WOUND", "", 33, 1)
assertEq(last("outgoing"), "33", "in a group before any line has arrived: hits on your target are shown")
STATE.group = false
STATE.who.party1 = nil
fire("GROUP_ROSTER_UPDATE")   -- (the game says so when the group changes; the answer is kept for the frame)
assertEq(BT:InGroup(), false, "not in a group")
STATE.who.party1 = "friend"
fire("GROUP_ROSTER_UPDATE")
assertEq(BT:InGroup(), true, "a party member means a group, whatever the game says")
STATE.who = {}
clear()

-- Alone, once the lines arrive (Start BattleText clicked), the same goes: a player outside your
-- group hitting your target showed as your numbers (a CurseForge comment, 1.18.4)
STATE.group = false
STATE.unit.soloMob = { enemy = true, guid = "Creature-0-1-2-3-100-0000D1", target = "me" }
STATE.who.target = "soloMob"
BT.hiddenSeen, BT.hiddenAt, BT.credits, BT.swings = true, nil, nil, nil
Advance(2)
fire("UNIT_COMBAT", "target", "WOUND", "", 99, 4)
fire("UNIT_COMBAT", "target", "WOUND", "", 98, 1)
fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
assertEq(#lines("outgoing"), 0, "alone, with the lines arriving: someone else's hits on your target aren't yours")
Advance(0.1)
hidden(50)
fire("UNIT_COMBAT", "target", "WOUND", "", 44, 4)
assertEq(last("outgoing"), "44", "a hit with a line of yours is")
Advance(0.1)
fire("PLAYER_SWING", 2.6, 0)
Advance(0.5)
fire("UNIT_COMBAT", "target", "WOUND", "", 37, 1)
assertEq(last("outgoing"), "37", "and so is a white hit with your swing")
STATE.unit.soloPlayer = { enemy = true, guid = "Player-5555-0ENEMY01", target = "me" }
STATE.who.target = "soloPlayer"
Advance(1.3)
fire("UNIT_COMBAT", "target", "WOUND", "", 97, 32)
assertEq(last("outgoing"), "37", "an enemy player you're fighting: someone else's Shadow Bolt on them isn't yours")
-- Your pet's hits have no line in "My actions": on a unit your pet is on, hits show as before
STATE.who.target = "soloMob"
STATE.pet, STATE.unit.pet = true, { target = "soloMob" }
Advance(1.3)
fire("UNIT_COMBAT", "target", "WOUND", "", 21, 1)
assertEq(last("outgoing"), "21", "your pet on your target: its hits (and so any) still show")
STATE.pet, STATE.unit.pet = false, nil
Advance(1.3)
fire("UNIT_COMBAT", "target", "WOUND", "", 96, 1)
assertEq(last("outgoing"), "21", "pet gone: back to needing a line or a swing")
-- Before any line has arrived (Start not clicked), alone, every hit on your target is yours, as before
BT.hiddenSeen, BT.hiddenAt, BT.credits, BT.swings = nil, nil, nil, nil
Advance(1.3)
fire("UNIT_COMBAT", "target", "WOUND", "", 22, 1)
assertEq(last("outgoing"), "22", "no lines yet: alone, your target's hits are yours")
STATE.who, STATE.unit.soloMob, STATE.unit.soloPlayer = {}, nil, nil
clear()

-- GitHub #27 (a shaman's log): Windfury Weapon's extra attacks after a Stormstrike. They come with
-- no PLAYER_SWING and no line in their own frame, and showed nowhere ("no line of yours with it").
STATE.spellNames[17364] = "Stormstrike"
STATE.unit.wfMob = { enemy = true, guid = "Creature-0-1-2-3-100-0000E1", target = "me" }
STATE.who.target = "wfMob"
BT.hiddenSeen, BT.hiddenAt, BT.credits, BT.swings, BT.extra = true, nil, nil, nil, nil
fire("PLAYER_SWING", 2.6, 0)
Advance(0.5)
fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
Advance(1.5)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-ss", 17364)
hidden(2020)
fire("UNIT_COMBAT", "target", "WOUND", "", 60, 1)
hidden(2021)
hidden(2022)
Advance(0.22)
fire("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 81, 1)
Advance(0.28)
fire("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 82, 1)
assertEq(table.concat(lines("outgoing"), " / "), "Dodge / Stormstrike 60 / 81 / 82",
    "alone: Windfury's two hits after your Stormstrike show")
Advance(0.1)
fire("UNIT_COMBAT", "target", "WOUND", "", 83, 1)
assertEq(#lines("outgoing"), 4, "but no third")
clear()
-- (after a white hit of yours too; but not long after it)
fire("PLAYER_SWING", 2.6, 0)
Advance(0.5)
fire("UNIT_COMBAT", "target", "WOUND", "", 40, 1)
Advance(0.3)
fire("UNIT_COMBAT", "target", "WOUND", "", 41, 1)
Advance(0.9)
fire("UNIT_COMBAT", "target", "WOUND", "", 42, 1)
assertEq(table.concat(lines("outgoing"), " / "), "40 / 41",
    "alone: Windfury's hit after your white hit shows; a hit a second later doesn't")
clear()
-- GitHub #25 (1.29.0, a shaman's log): Stormstrike and a swing in one frame, the swing's hit 0.4s
-- later, then Windfury's two hits 0.36s and 0.94s after it. The second was "no line of yours with it".
Advance(2)
fire("PLAYER_SWING", 2.6, 0)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-ss2", 17364)
hidden(2030)
fire("UNIT_COMBAT", "target", "WOUND", "", 62, 1)
hidden(2031)
hidden(2032)
Advance(0.4)
fire("UNIT_COMBAT", "target", "WOUND", "", 44, 1)
Advance(0.36)
fire("UNIT_COMBAT", "target", "WOUND", "", 87, 1)
Advance(0.58)
fire("UNIT_COMBAT", "target", "WOUND", "", 88, 1)
assertEq(table.concat(lines("outgoing"), " / "), "Stormstrike 62 / 44 / 87 / 88",
    "alone: Windfury's second hit, 0.94s after your swing's, shows")
clear()
-- In a group a party member's white hit can follow your blow: an extra attack also takes a spare
-- line of yours from the blow's own frame (Windfury's lines come with it)
STATE.group = true
Advance(2)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-ss", 17364)
hidden(2025)
fire("UNIT_COMBAT", "target", "WOUND", "", 61, 1)
hidden(2026)
hidden(2027)
Advance(0.22)
fire("UNIT_COMBAT", "target", "WOUND", "CRITICAL", 84, 1)
Advance(0.28)
fire("UNIT_COMBAT", "target", "WOUND", "", 85, 1)
assertEq(table.concat(lines("outgoing"), " / "), "Stormstrike 61 / 84 / 85",
    "in a group: Windfury's hits take the Stormstrike frame's spare lines")
clear()
Advance(2)
fire("PLAYER_SWING", 2.6, 0)
hidden(5441)
Advance(0.5)
fire("UNIT_COMBAT", "target", "WOUND", "", 43, 1)
Advance(0.2)
fire("UNIT_COMBAT", "target", "WOUND", "", 86, 1)
assertEq(table.concat(lines("outgoing"), " / "), "43",
    "in a group: a hit after your white hit with no spare line of yours with it isn't yours")
STATE.group = false
STATE.who, STATE.unit.wfMob, BT.extra = {}, nil, nil
clear()

---------------------------------------------------------------------------
step("ticks, and your damage shield")
STATE.unit.mobA = { enemy = true, guid = "Creature-0-1-2-3-100-00000A", target = "me" }
STATE.who.target, STATE.who.nameplate1 = "mobA", "mobA"
BT.hiddenSeen, BT.hiddenAt, BT.credits, BT.dots, BT.spellSchool = nil, nil, nil, nil, nil
    BT.schoolSeen = nil
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
fire("PLAYER_SWING", 2.6, 0)   -- (alone with the lines, the white hit needs your swing too)
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
-- Rip's ticks come with no line at all (GitHub, a ptBR druid's /btf debug), while Rake's and
-- Thorns' lines keep arriving: its beat vouches for it, six ticks over its 12 seconds
BT.dots, BT.credits, BT.swings, BT.swungAt = nil, nil, nil, nil
hidden(60)
cast(1079) hidden(61)
for k = 1, 5 do
    Advance(2)
    BT.hiddenAt = GetTime()   -- (other lines of yours still arriving)
    wound(20 + k, 1, k == 1 and "CRITICAL" or nil)
    assertEq(last("outgoing"), "Rip " .. (20 + k), "Rip's tick " .. k .. " with no line: named by its beat")
end
-- (GitHub #30, after 1.32.2) Rip's 6th tick lands between your swing and the swing's own hit:
-- the tick on the beat is Rip's, and the swing keeps its credit for its own (glancing) hit
Advance(1.73)
BT.hiddenAt = GetTime()
fire("PLAYER_SWING", 2.6, 0)
Advance(0.27)
wound(26, 1, "CRITICAL")
assertEq(last("outgoing"), "Rip 26", "a tick right on Rip's beat, with a swing of yours pending, is Rip's")
Advance(0.17)
wound(30, 1, "GLANCING")
assertEq(last("outgoing"):match("^30"), "30", "and the swing's own hit after it is the swing's")
BT.swings, BT.swungAt = nil, nil
cast(1079) hidden(62)
Advance(2)
BT.hiddenAt = GetTime()
wound(27, 1, "GLANCING")
assert(not table.concat(lines("outgoing"), " / "):find("Rip 27", 1, true), "a glancing blow on the beat is a swing, not Rip")
Advance(2)
BT.hiddenAt = GetTime()
wound(28)
assertEq(last("outgoing"), "Rip 28", "the next tick is still named")
Advance(10)
BT.hiddenAt = GetTime()
wound(29)
assert(last("outgoing") ~= "Rip 29", "past its 12 seconds: not Rip")
BT.dots = nil
clear()
-- A Rip tick and a Rake tick in the same frame, neither with a line: one is Rip's
BT.dots, BT.swings, BT.swungAt = nil, nil, nil
cast(1822) hidden(63) wound(35)
Advance(1)
cast(1079) hidden(64)
Advance(2)
BT.hiddenAt = GetTime()
wound(15)
wound(9, 1, "CRITICAL")
do
    local both = table.concat(lines("outgoing"), " / ")
    assert(both:find("Rip 15", 1, true), "the first of the two hits on both beats is Rip's (got " .. both .. ")")
    assert(not both:find("Rip 9", 1, true), "and only one: Rip ticks once a beat")
end
BT.dots = nil
clear()
-- Tyler's druid log (1.40.2): Rake's three ticks came with no line, 3s apart from the cast, while
-- Thorns' lines kept coming. They showed as plain white hits; its beat names them now, no more
-- than three, and not past its 9 seconds
BT.dots, BT.swings, BT.swungAt, BT.tickLines = nil, nil, nil, nil
hidden(70)
cast(1822) wound(30)   -- (the cast's own hit)
for k = 1, 3 do
    Advance(k == 1 and 3.03 or 3)
    BT.hiddenAt = GetTime()   -- (Thorns' lines still arriving)
    wound(10 + k, 1, k == 3 and "CRITICAL" or nil)
    assertEq(last("outgoing"), "Rake " .. (10 + k), "Rake's tick " .. k .. " with no line: named by its beat")
end
Advance(3)
BT.hiddenAt = GetTime()
wound(19)
assert(last("outgoing") ~= "Rake 19", "a fourth hit on the beat, past its 9 seconds: not Rake")
BT.dots = nil
clear()
-- On a game that sends Rake's ticks their lines (the ptBR log), two ticks named by their lines
-- stop its beat alone from naming a hit: a swing on the beat with no line behind stays a swing
BT.dots, BT.swings, BT.swungAt, BT.tickLines = nil, nil, nil, nil
cast(1822) hidden(71) wound(35)
Advance(3)
wound(14) hidden(72)
assertEq(last("outgoing"), "Rake 14", "a tick with its line")
Advance(3)
wound(15) hidden(73)
assertEq(last("outgoing"), "Rake 15", "and another")
cast(1822) hidden(74) wound(35)
Advance(3)
BT.hiddenAt = GetTime()
wound(27)
Advance(1.5)
do
    local out = table.concat(lines("outgoing"), " / ")
    assert(not out:find("Rake 27", 1, true), "then a hit on the beat with no line isn't Rake's (" .. out .. ")")
end
BT.dots, BT.tickLines = nil, nil
clear()
-- Deep Wounds (GitHub #44): a warrior's melee crit makes the mob bleed, cast by the game, not you.
-- Its ticks showed as swings with your weapon's icon; your crit now starts the bleed, named by
-- its beat (no line) or by the line behind it, at most four ticks over its 12 seconds
do
STATE.spellNames[12162], STATE.spellIcons[12162] = "Deep Wounds", 132090
STATE.knownSpells[12834] = true
local function dwFresh() BT.dots, BT.swings, BT.swungAt, BT.tickLines = nil, nil, nil, nil clear() end
dwFresh()
hidden(80)
fire("PLAYER_SWING", 3.6, 0) wound(60, 1, "CRITICAL")
assertEq(last("outgoing"), "60", "your white crit")
for k = 1, 4 do
    Advance(3)
    BT.hiddenAt = GetTime()   -- (other lines of yours still arriving)
    wound(7)
    assertEq(last("outgoing"), "Deep Wounds 7", "Deep Wounds' tick " .. k .. " with no line: named by its beat")
end
SetIcons(true)
dwFresh()
fire("PLAYER_SWING", 3.6, 0) wound(60, 1, "CRITICAL")
Advance(3)
BT.hiddenAt = GetTime()
wound(7)
assert(last("outgoing"):find("132090", 1, true), "with its own icon, not the weapon's (" .. last("outgoing") .. ")")
SetIcons(false)
Advance(3)
BT.hiddenAt = GetTime()
fire("PLAYER_SWING", 3.6, 0) wound(41)
assert(not last("outgoing"):find("Deep Wounds", 1, true), "a swing on its beat for another amount stays a swing")
Advance(3)
BT.hiddenAt = GetTime()
wound(7)
assertEq(last("outgoing"), "Deep Wounds 7", "the next tick is still named")
Advance(6)
BT.hiddenAt = GetTime()
wound(7)
assert(not (last("outgoing") or ""):find("Deep Wounds", 1, true), "past its 12 seconds: not Deep Wounds")
-- A crit starts it over (its ticks counted from the new crit); a cast blow's crit (Mortal Strike) too
dwFresh()
STATE.spellNames[12294] = "Mortal Strike"
cast(12294) hidden(81) wound(90, 1, "CRITICAL")
assertEq(last("outgoing"), "Mortal Strike 90", "your blow crits")
Advance(3)
wound(9) hidden(82)
assertEq(last("outgoing"), "Deep Wounds 9", "a cast blow's crit starts it too")
Advance(1)
fire("PLAYER_SWING", 3.6, 0) hidden(83) wound(55, 1, "CRITICAL")
Advance(2)
BT.hiddenAt = GetTime()
wound(9)
assert(not (last("outgoing") or ""):find("Deep Wounds", 1, true), "on the old crit's beat, after a new crit: not a tick")
Advance(1)
wound(9) hidden(84)
assertEq(last("outgoing"), "Deep Wounds 9", "on the new crit's beat, with its line behind it: Deep Wounds")
-- Not without the talent, not from a plain hit, not from a shot
dwFresh()
STATE.knownSpells[12834] = nil
fire("PLAYER_SWING", 3.6, 0) hidden(85) wound(60, 1, "CRITICAL")
Advance(3)
BT.hiddenAt = GetTime()
wound(7)
assert(not (last("outgoing") or ""):find("Deep Wounds", 1, true), "no Deep Wounds talent: no bleed")
STATE.knownSpells[12834] = true
dwFresh()
fire("PLAYER_SWING", 3.6, 0) hidden(86) wound(60)
Advance(3)
BT.hiddenAt = GetTime()
wound(7)
assert(not (last("outgoing") or ""):find("Deep Wounds", 1, true), "a hit that isn't a crit starts no bleed")
dwFresh()
STATE.spellNames[2764] = "Throw"
cast(2764) hidden(87) wound(60, 1, "CRITICAL")
Advance(3)
BT.hiddenAt = GetTime()
wound(7)
assert(not (last("outgoing") or ""):find("Deep Wounds", 1, true), "a thrown weapon's crit starts no bleed (melee only)")
dwFresh()
STATE.knownSpells[12834] = nil
BT.dots = nil
clear()
end
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

-- Damage shields: what hurts whoever strikes you. An item's is read from its tooltip.
local function blow() fire("UNIT_COMBAT", "player", "WOUND", "", 20, 1) end
local function reset()
    BT.db.shieldAmounts = {}
    BT.shieldCounts, BT.shieldPending = nil, nil
    clear()
end
reset()
STATE.equipped[15] = { name = "Sporid Cape", icon = 133762, lines = { "Soulbound", "Back", "+6 Stamina",
    "Equip: When struck in combat, inflicts 1 Nature damage to the attacker.", "Requires Level 17" } }
STATE.equipped[16] = { name = "Staff of the Grove", icon = 135145,
    lines = { "Equip: Increases damage done by Nature spells and effects by up to 11." } }
fire("PLAYER_EQUIPMENT_CHANGED", 15, true)
assertEq(#BT.itemShields, 1, "one item of yours stings back (the staff's line is no shield)")
assertEq(BT.itemShields[1].name, "Sporid Cape", "the cape")
assertEq(BT.itemShields[1].amount .. " " .. BT.itemShields[1].school, "1 8", "for 1 Nature")
SetIcons(true)
wound(1, 8)
assertEq(last("outgoing"), "|T133762:0|t Sporid Cape 1", "its hit is named after the item, with the item's icon")
SetIcons(false)
wound(1, 4)
assertEq(last("outgoing"), "1", "a hit of another school isn't the cape's")
wound(2, 8)
assertEq(last("outgoing"), "2", "nor one of another size")
clear()
BT.db.outShields = false
wound(1, 8)
assertEq(#lines("outgoing"), 0, "Damage shields unticked: the cape's hit is hidden")
wound(27)
assertEq(last("outgoing"), "27", "your own hits still show")
BT.db.outShields = true
clear()
-- Gear can't be read in a fight: what was read before stands, and it's read again after
COMBAT = true
STATE.equipped[15] = nil
fire("PLAYER_EQUIPMENT_CHANGED", 15, false)
assertEq(#BT.itemShields, 1, "in a fight: not read")
COMBAT = false
fire("PLAYER_REGEN_ENABLED")
assertEq(#BT.itemShields, 0, "after it: the cape is off")
STATE.equipped[15] = { name = "Sporid Cape", hidden = true }
fire("PLAYER_REGEN_DISABLED")
assertEq(#BT.itemShields, 0, "a tooltip the game hides tells nothing")
STATE.equipped[15] = nil
STATE.equipped[13] = { name = "Essence of the Pure Flame", icon = 135805,
    lines = { "Equip: When struck in combat inflicts 13 Fire damage to the attacker." } }
STATE.equipped[11] = { name = "Ring of Riddles", lines = { "Equip: When struck in combat inflicts 3 Chaos damage to the attacker." } }
fire("PLAYER_EQUIPMENT_CHANGED", 13, true)
assertEq(#BT.itemShields, 1, "a trinket that burns back (a school the game doesn't have isn't guessed at)")
assertEq(BT.itemShields[1].amount .. " " .. BT.itemShields[1].school, "13 4", "for 13 Fire")
STATE.equipped[13], STATE.equipped[11] = nil, nil
STATE.equipped[2] = { name = "Naglering", icon = 133345, oldShape = true,
    lines = { "Equip: When struck in combat inflicts 3 Arcane damage to the attacker." } }
fire("PLAYER_EQUIPMENT_CHANGED", 2, true)
assertEq(BT.itemShields[1] and BT.itemShields[1].name .. " " .. BT.itemShields[1].school, "Naglering 64",
    "the tooltip's older shape is read too")
STATE.equipped[2] = nil
fire("PLAYER_EQUIPMENT_CHANGED", 2, false)
clear()

-- A buff's is learned: the hit, then the blow it answered (shown a moment later), twice
STATE.buffs = { { name = "Mark of the Wild", spellId = 1126 }, { name = "Thorns", spellId = 782 } }
fire("UNIT_AURA", "player")
assertEq(BT.buffShields.Thorns.id, 782, "Thorns is on you (the rank you're wearing, for its icon)")
wound(3, 8)
assertEq(#lines("outgoing"), 0, "the first answer waits for the blow it answers")
Advance(0.6)
blow()
assertEq(last("outgoing"), "Thorns 3", "and is named when the blow lands (amounts are often hidden: see below)")
assertEq(BT.db.shieldAmounts.Thorns, nil, "one answer isn't enough to learn its amount")
Advance(1)
wound(3, 8)
Advance(0.6)
blow()
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
assertEq(#lines("outgoing"), 0, "Damage shields unticked: Thorns is hidden")
BT.db.outShields = true
-- What doesn't teach: no blow behind it, a blow you dodged, a frame with a combat log line in it
reset()
wound(3, 8)
Advance(1.5)
blow()
for _ = 1, 2 do
    Advance(1)
    wound(3, 8)
    Advance(0.5)
    fire("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
end
Advance(1)
hidden(50)
wound(3, 8)
Advance(0.5)
blow()
Advance(1)
hidden(51)
wound(3, 8)
Advance(0.5)
blow()
assertEq(BT.db.shieldAmounts.Thorns, nil, "nothing learned from those")
Advance(1)
wound(3, 8)
Advance(0.5)
blow()
Advance(1)
wound(3, 8)
Advance(0.5)
blow()
assertEq(BT.db.shieldAmounts.Thorns, 3, "two clean answers: learned")
BT.hiddenSeen, BT.hiddenAt = nil, nil
-- A new rank hits for more: the old amount gives way after three answers
for i = 1, 3 do
    assertEq(BT.db.shieldAmounts.Thorns, 3, "not yet (" .. i .. ")")
    Advance(1)
    wound(6, 8)
    Advance(0.5)
    blow()
end
assertEq(BT.db.shieldAmounts.Thorns, 6, "three answers of the new size: learned again")
clear()

-- Two shields at once: Thorns and the cape, answering the same blow
reset()
STATE.equipped[15] = { name = "Sporid Cape", icon = 133762,
    lines = { "Equip: When struck in combat, inflicts 1 Nature damage to the attacker." } }
fire("PLAYER_EQUIPMENT_CHANGED", 15, true)
for _ = 1, 2 do
    wound(11, 8) wound(1, 8)
    Advance(0.5)
    blow()
    Advance(1)
end
assertEq(BT.db.shieldAmounts.Thorns, 11, "the cape's 1 is the cape's, so the 11 is Thorns'")
wound(1, 8) wound(11, 8)
assertEq(table.concat(lines("outgoing"), " / "):match("Sporid Cape 1 / Thorns 11$"), "Sporid Cape 1 / Thorns 11", "each is named")
-- The same on a client that can't read the cape (another language): two amounts, one buff.
-- Thorns' own description says which is its.
reset()
STATE.equipped[15].lines = { "Anlegen: Fügt dem Angreifer 1 Naturschaden zu." }
fire("PLAYER_EQUIPMENT_CHANGED", 15, true)
assertEq(#BT.itemShields, 0, "the cape isn't recognised")
for _ = 1, 3 do
    wound(11, 8) wound(1, 8)
    Advance(0.5)
    blow()
    Advance(1)
end
assertEq(BT.db.shieldAmounts.Thorns, nil, "two amounts and no telling which is Thorns': neither is taken")
STATE.spellDescriptions[782] = "Thorns sprout from the friendly target causing 11 Nature damage to attackers when hit. Lasts 10 min."
wound(11, 8) wound(1, 8)
Advance(0.5)
blow()
assertEq(BT.db.shieldAmounts.Thorns, 11, "the description names 11")
Advance(1)
wound(11, 8) wound(1, 8)
assertEq(table.concat(lines("outgoing"), " / "):match("Thorns 11 / 1$"), "Thorns 11 / 1", "Thorns is named; the other is just a hit")
STATE.spellDescriptions[782] = nil
STATE.equipped[15] = nil
fire("PLAYER_EQUIPMENT_CHANGED", 15, false)
-- Two buffs of one school (a druid's Thorns on a shaman): the descriptions say whose is whose
reset()
STATE.buffs = { { name = "Thorns", spellId = 782 }, { name = "Lightning Shield", spellId = 324 } }
STATE.spellDescriptions[782] = "causing 11 Nature damage to attackers when hit."
STATE.spellDescriptions[324] = "struck in combat, the attacker takes 13 Nature damage. Lasts 10 min."
fire("UNIT_AURA", "player")
for _ = 1, 2 do
    wound(13, 8) wound(11, 8)
    Advance(0.5)
    blow()
    Advance(1)
end
assertEq(BT.db.shieldAmounts.Thorns .. " " .. BT.db.shieldAmounts["Lightning Shield"], "11 13", "each buff gets its own amount")
-- A description is read for whole numbers: a 1 isn't the "11" in it
reset()
STATE.spellDescriptions[324] = "the attacker takes 23 Nature damage."
for _ = 1, 3 do
    wound(1, 8)
    Advance(0.5)
    blow()
    Advance(1)
end
assertEq(next(BT.db.shieldAmounts), nil, "neither description says 1")
STATE.spellDescriptions[782], STATE.spellDescriptions[324] = nil, nil
reset()
for _ = 1, 3 do
    wound(13, 8)
    Advance(0.5)
    blow()
    Advance(1)
end
assertEq(next(BT.db.shieldAmounts), nil, "two buffs it could be, and no description: not taken")
clear()

-- In a fight the game hides your buffs: the last answer stands
STATE.buffs = { { name = "Thorns", spellId = 782 } }
fire("UNIT_AURA", "player")
BT.db.shieldAmounts = { Thorns = 3 }
STATE.buffsHidden = true
fire("UNIT_AURA", "player")
wound(3, 8)
assertEq(last("outgoing"), "Thorns 3", "buffs hidden: still known")
STATE.buffsHidden = false
STATE.buffs = { Secret({ name = "x" }) }
fire("UNIT_AURA", "player")
assertEq(BT.buffShields.Thorns ~= nil, true, "a hidden buff tells nothing")
STATE.buffs = { { name = Secret("Thorns") } }
fire("PLAYER_REGEN_DISABLED")
assertEq(BT.buffShields.Thorns ~= nil, true, "nor a hidden name")
STATE.buffs = { { name = "Lightning Shield", spellId = 324 } }
fire("PLAYER_REGEN_DISABLED")
assertEq(BT.buffShields["Lightning Shield"] ~= nil and BT.buffShields.Thorns == nil, true,
    "your buffs are looked at as a fight starts")
STATE.buffs = { { name = "Mark of the Wild", spellId = 1126 } }
fire("PLAYER_ENTERING_WORLD")
assertEq(next(BT.buffShields), nil, "it wore off")
Advance(1)
wound(3, 8)
assertEq(last("outgoing"), "3", "no shield on you: just a hit")
STATE.buffs = { { name = "Thorns", spellId = 782 } }
fire("PLAYER_REGEN_ENABLED")
assertEq(BT.buffShields.Thorns ~= nil, true, "and they're looked at again when a fight ends")
fire("PLAYER_ENTERING_WORLD", false, false)
cast(324)   -- Lightning Shield, put up mid-fight
assertEq(BT.buffShields["Lightning Shield"].id, 324, "a shield you cast is known at once")
assertEq(BT.buffShields.Thorns ~= nil, true, "beside the one you had")
BT.db.shieldAmounts = { ["Lightning Shield"] = 13, Thorns = 3 }
Advance(1)
wound(13, 8)
assertEq(last("outgoing"), "Lightning Shield 13", "and named")
wound(Secret(13), 8)
Advance(1.3)
assertEq(last("outgoing"), "<secret fmt>", "a hidden amount can't be matched, and no blow came: just a hit")
-- Amounts are often hidden (players' logs), so they can't be learned: a hit of the shield's
-- school on a mob after you is the shield's when the blow it answered lands on you (a player's
-- report: Retribution Aura showed no icon)
clear()
-- (the game draws a hidden amount itself: the line's name is read from the debug record)
local function lastNamed()
    local list = BT.recorded or {}
    for i = #list, 1, -1 do
        local what = list[i]:match(": (shield of .+)$") or list[i]:match(": (nothing came for it: shown)$")
        if what then return what end
    end
end
BT.db.debug, BT.recorded = true, {}
wound(Secret(13), 8)
assertEq(#lines("outgoing"), 0, "a hidden amount waits for a blow on you")
Advance(0.6)
blow()
assertEq(#lines("outgoing"), 1, "and is shown when one lands")
assertEq(lastNamed(), "shield of Lightning Shield", "as the shield's")
Advance(1)
blow()
Advance(0.2)
BT.recorded = {}
wound(Secret(13), 8)
assertEq(#lines("outgoing"), 2, "a blow just before counts too: shown at once")
assertEq(lastNamed(), "shield of Lightning Shield", "as the shield's")
Advance(1)
BT.recorded = {}
wound(Secret(13), 8)
Advance(1.3)
assertEq(lastNamed(), "nothing came for it: shown", "no blow: shown as it is")
-- Named, it can be hidden (a player's report: Retribution Aura stayed on screen with "Damage
-- shields" off and a Hide rule for it, because it had no name)
BT.recorded = {}
clear()
BT.db.outShields = false
wound(Secret(13), 8)
Advance(0.6)
blow()
Advance(1)
assertEq(#lines("outgoing"), 0, "\"Damage shields\" off: hidden")
BT.db.outShields = true
BT:AddSpellRule("Lightning Shield")
BT:SetSpellRule(BT.db.spellRules[#BT.db.spellRules], "hide", true)
wound(Secret(13), 8)
Advance(0.6)
blow()
Advance(1)
assertEq(#lines("outgoing"), 0, "hidden on the Spells tab: hidden")
BT:RemoveSpellRule(#BT.db.spellRules)
BT.db.debug, BT.recorded = false, nil
Advance(1)
wound(Secret(14), 4)
Advance(0.5)
blow()
Advance(1)
assertEq(last("outgoing"), "<secret fmt>", "not a hit of another school than your shields'")
-- Two damage shields answer one blow (a CurseForge comment: a paladin with Retribution Aura
-- and a druid's Thorns; one blow named only one of them, and the other showed unnamed, even
-- with "Damage shields" off)
do
    clear()
    BT.db.debug, BT.recorded = true, {}
    STATE.buffs = { { name = "Thorns", spellId = 782 }, { name = "Retribution Aura", spellId = 10301 } }
    fire("PLAYER_REGEN_ENABLED")
    BT.db.shieldAmounts = {}
    Advance(2)
    wound(Secret(11), 8) wound(Secret(9), 2)
    Advance(0.6) blow() Advance(1.5)
    local named = {}
    for _, r in ipairs(BT.recorded) do
        local what = r:match(": (shield of .+)$") or r:match(": (nothing came for it: shown)$")
        if what then named[#named + 1] = what end
    end
    table.sort(named)
    assertEq(table.concat(named, " / "), "shield of Retribution Aura / shield of Thorns",
        "one blow: each shield's answer is named")
    clear()
    BT.db.outShields = false
    Advance(2)
    wound(Secret(11), 8) wound(Secret(9), 2)
    Advance(0.6) blow() Advance(1.5)
    assertEq(#lines("outgoing"), 0, "\"Damage shields\" off: both hidden")
    -- but one shield answers a blow only once: two Thorns hits and one blow leave one unnamed
    BT.db.outShields = true
    BT.recorded = {}
    Advance(2)
    wound(Secret(11), 8) Advance(0.1) wound(Secret(11), 8)
    Advance(0.5) blow() Advance(1.5)
    named = {}
    for _, r in ipairs(BT.recorded) do
        local what = r:match(": (shield of .+)$") or r:match(": (nothing came for it: shown)$")
        if what then named[#named + 1] = what end
    end
    table.sort(named)
    assertEq(table.concat(named, " / "), "nothing came for it: shown / shield of Thorns",
        "the same shield twice for one blow: the second isn't its answer")
    -- Thorns and a ring that stings back, both Nature, both hidden (Tyler's debug log, 1.25.1:
    -- every blow had two Nature hits; the Spiked Shell Band's 2 showed unnamed beside Thorns)
    STATE.buffs = { { name = "Thorns", spellId = 782 } }
    fire("PLAYER_REGEN_ENABLED")
    STATE.equipped[11] = { name = "Spiked Shell Band", icon = 133345,
        lines = { "Equip: When struck in combat, inflicts 2 Nature damage to the attacker." } }
    fire("PLAYER_EQUIPMENT_CHANGED", 11, true)
    local function shieldsNamed()
        local list = {}
        for _, r in ipairs(BT.recorded) do
            local what = r:match(": (shield of .+)$") or r:match(": (nothing came for it: shown)$")
            if what then list[#list + 1] = what end
        end
        return table.concat(list, " / ")
    end
    BT.recorded = {}
    Advance(2)
    wound(Secret(9), 8) wound(Secret(2), 8)
    Advance(0.6) blow() Advance(1.5)
    assertEq(shieldsNamed(), "shield of Thorns / shield of Spiked Shell Band", "the blow names both: Thorns, then the ring")
    -- the blow just before: the same
    BT.recorded = {}
    Advance(2)
    blow() Advance(0.1)
    wound(Secret(9), 8) wound(Secret(2), 8)
    Advance(1.5)
    assertEq(shieldsNamed(), "shield of Thorns / shield of Spiked Shell Band", "a blow just before names both too")
    -- Tyler's second log (1.28.2): the blow came 0.57s before, or only as a miss
    BT.recorded = {}
    Advance(2)
    blow() Advance(0.57)
    wound(Secret(9), 8) wound(Secret(2), 8)
    Advance(1.5)
    assertEq(shieldsNamed(), "shield of Thorns / shield of Spiked Shell Band", "a blow 0.57s before names both")
    BT.recorded = {}
    Advance(2)
    wound(Secret(9), 8) wound(Secret(2), 8)
    Advance(0.3) fire("UNIT_COMBAT", "player", "MISS", "", 0, 1)
    Advance(1.5)
    assertEq(shieldsNamed(), "shield of Thorns (with the others) / shield of Spiked Shell Band (with the others)",
        "no blow, but one Nature hit for each Nature shield at once: theirs")
    BT.recorded = {}
    Advance(2)
    wound(Secret(9), 8)
    Advance(1.5)
    assertEq(shieldsNamed(), "nothing came for it: shown", "one Nature hit alone, no blow: just a hit")
    BT.recorded = {}
    Advance(2)
    wound(Secret(9), 8) Advance(0.1) wound(Secret(2), 8)
    Advance(1.5)
    assertEq(shieldsNamed(), "nothing came for it: shown / nothing came for it: shown", "not at the same moment: just hits")
    -- a readable 2 is the ring's, whichever comes first
    BT.db.shieldAmounts = { Thorns = 9 }
    BT.recorded = {}
    Advance(2)
    wound(2, 8) wound(9, 8)
    Advance(0.6) blow() Advance(1.5)
    local shown = table.concat(lines("outgoing"), " / ")
    assert(shown:find("Spiked Shell Band 2", 1, true) and shown:find("Thorns 9", 1, true), "readable: each by its amount (" .. shown .. ")")
    -- Tyler's druid log (1.40.2): the ring hidden on the Spells tab. Each blow's two hidden Nature
    -- hits: Thorns' is shown, the ring's hidden, and the debug log says which one was hidden
    BT.db.shieldAmounts = {}
    BT:AddSpellRule("Spiked Shell Band")
    BT:SetSpellRule(BT:SpellRule("Spiked Shell Band"), "hide", true)
    clear()
    BT.recorded = {}
    Advance(2)
    wound(Secret(9), 8) wound(Secret(2), 8)
    Advance(0.39) blow() Advance(1.5)
    do
        local rec = table.concat(BT.recorded, "\n")
        assert(rec:find(": shield of Thorns", 1, true), "Thorns' hit is named and shown")
        assert(rec:find(": hidden on the Spells tab (Spiked Shell Band)", 1, true),
            "the ring's is the one hidden, and the log names it")
        assertEq(#lines("outgoing"), 1, "one of the two on screen")
    end
    for j, r in ipairs(BT.db.spellRules) do
        if r.name == "Spiked Shell Band" then BT:RemoveSpellRule(j) break end
    end
    STATE.equipped[11] = nil
    fire("PLAYER_EQUIPMENT_CHANGED", 11, false)
    BT.db.shieldAmounts = {}
    STATE.buffs = { { name = "Thorns", spellId = 782 }, { name = "Retribution Aura", spellId = 10301 } }
    fire("PLAYER_REGEN_ENABLED")
    clear()

    -- Unsealed Wrath (Forever's Retribution talent; same comment's author: it showed no damage).
    -- A Holy hit with your swing, no seal that hurts on you, is the talent's, not Retribution
    -- Aura's answer to the mob's blow (that was hidden with "Damage shields" off)
    BT.db.outShields = false
    STATE.knownSpells[1310735] = true
    STATE.spellNames[1310735] = "Unsealed Wrath"
    BT.recorded = {}
    clear()
    Advance(2)
    fire("PLAYER_SWING", 2.6, 0)
    wound(Secret(40), 1) wound(Secret(20), 2)
    Advance(0.3) blow() Advance(1.5)
    local uw
    for _, r in ipairs(BT.recorded) do uw = uw or r:match(": (seal of Unsealed Wrath)$") end
    assertEq(uw, "seal of Unsealed Wrath", "a Holy hit with your swing: Unsealed Wrath")
    assertEq(#lines("outgoing"), 2, "shown with \"Damage shields\" off (the swing and the talent)")
    -- its hit can come ahead of the swing's, just after a blow on you: it waits for the swing
    BT.recorded = {}
    clear()
    Advance(2)
    blow() Advance(0.2)
    wound(Secret(20), 2)
    Advance(0.3)
    fire("PLAYER_SWING", 2.6, 0)
    wound(Secret(40), 1)
    Advance(1.5)
    uw = nil
    for _, r in ipairs(BT.recorded) do uw = uw or r:match(": (seal of Unsealed Wrath)$") end
    assertEq(uw, "seal of Unsealed Wrath", "ahead of the swing, after a blow: still Unsealed Wrath")
    -- without the talent, it's Retribution Aura's as before
    STATE.knownSpells[1310735] = nil
    BT.db.outShields = true
    BT.recorded = {}
    clear()
    Advance(2)
    fire("PLAYER_SWING", 2.6, 0)
    wound(Secret(40), 1) wound(Secret(20), 2)
    Advance(0.3) blow() Advance(1.5)
    uw = nil
    for _, r in ipairs(BT.recorded) do uw = uw or r:match(": (shield of Retribution Aura)$") end
    assertEq(uw, "shield of Retribution Aura", "no talent: the aura's answer")
    BT.db.debug, BT.recorded = false, nil
    STATE.buffs = {}
    fire("PLAYER_REGEN_ENABLED")
    clear()
end

-- Touch of the Grave (the Undead racial on Forever; issue: its damage and its heal on you
-- showed with no name). Its hit on the mob and its heal on you land together.
do
    clear()
    BT.db.debug, BT.recorded = true, {}
    SetNames(true) SetIcons(false)
    STATE.spellNames[1260189] = "Touch of the Grave"
    STATE.spellNames[1260201] = "Touch of the Grave"
    local function verdicts()
        local out = {}
        for _, r in ipairs(BT.recorded) do
            local v = r:match("^.-target [^:]+: (.+)$")
            if v then out[#out + 1] = v end
        end
        BT.recorded = {}
        return table.concat(out, " / ")
    end
    local function heals()
        local out = {}
        for _, area in pairs({ "incoming", "outgoing", "heal" }) do
            if BT.areas[area] then
                for _, o in ipairs(BT.areas[area].active) do
                    local t = o.text.__shown or o.text:GetText() or ""
                    if t:find("+", 1, true) and t:find("Touch of the Grave", 1, true) then out[#out + 1] = t end
                end
            end
        end
        return #out
    end
    local function grave(amount, school) fire("UNIT_COMBAT", "player", "HEAL", "", amount, school or 32) end
    STATE.knownSpells[1260201] = true   -- (a mage, priest or warlock's)
    -- the hit, then the heal, in one frame
    Advance(2)
    wound(Secret(30), 32) grave(Secret(30))
    Advance(0.5)
    assertEq(verdicts(), "proc of Touch of the Grave", "its hit is named")
    lines("outgoing")
    assertEq(heals(), 1, "and so is its heal on you")
    -- the heal first
    clear() BT.recorded = {}
    Advance(2)
    grave(Secret(30)) wound(Secret(30), 32)
    Advance(0.5)
    assertEq(verdicts(), "proc of Touch of the Grave", "heal first: still named")
    lines("outgoing")
    assertEq(heals(), 1, "heal first: the heal too")
    -- the heal a moment after the hit: the hit waits for it
    clear() BT.recorded = {}
    Advance(2)
    wound(Secret(30), 32)
    Advance(0.1)
    grave(Secret(30))
    Advance(0.5)
    assertEq(verdicts(), "waiting: Touch of the Grave? / proc of Touch of the Grave", "the heal just after: named")
    lines("outgoing")
    assertEq(heals(), 1, "and the heal")
    -- no heal comes: an unnamed Shadow hit, shown when the wait is over
    clear() BT.recorded = {}
    Advance(2)
    wound(Secret(30), 32)
    Advance(0.5)
    assertEq(verdicts(), "waiting: Touch of the Grave? / no heal came for it: shown", "no heal: not the racial")
    assertEq(#lines("outgoing"), 1, "but still shown")
    -- issue #23: the wait's debug line had tostring(amount), a secret string in the game, and
    -- /btf copy failed on it (table.concat). It says "(hidden amount)" and copies.
    clear() BT.recorded = {}
    Advance(2)
    wound(Secret(30), 32)
    Advance(0.5)
    for i, r in ipairs(BT.recorded) do assert(not issecretvalue(r), "line " .. i .. " is plain text") end
    assert(table.concat(BT.recorded, "\n"):find("(hidden amount): no heal came for it", 1, true), "the amount says hidden")
    BT:OpenCopyWindow()
    assert(BT.copyWindow.edit:GetText():find("no heal came for it", 1, true), "/btf copy shows it")
    -- and a hidden value that still gets in is left as a note, and the window opens
    BT:Record(Secret("x"))
    BT.recorded[#BT.recorded + 1] = Secret("y")
    BT:OpenCopyWindow()
    local copied = BT.copyWindow.edit:GetText()
    assertEq(select(2, copied:gsub("%(a line with a hidden value%)", "")), 2, "hidden lines: notes in /btf copy")
    assert(copied:find("no heal came for it", 1, true), "the rest is still there")
    BT.copyWindow:Hide()
    clear() BT.recorded = {}
    -- a physical hit with a heal on you isn't it
    clear() BT.recorded = {}
    Advance(2)
    wound(Secret(30), 1) grave(Secret(30), 2)
    Advance(0.5)
    assertEq(verdicts(), "shown", "a swing isn't the racial")
    lines("outgoing")
    assertEq(heals(), 0, "nor the heal with it")
    -- one heal names one hit
    clear() BT.recorded = {}
    Advance(2)
    grave(Secret(30)) wound(Secret(30), 32) wound(Secret(31), 32)
    Advance(0.5)
    assertEq(verdicts(), "proc of Touch of the Grave / waiting: Touch of the Grave? / no heal came for it: shown",
        "one heal: one hit")
    -- not Undead: a Shadow hit and a heal on you stay as they were
    STATE.knownSpells[1260201] = nil
    clear() BT.recorded = {}
    Advance(2)
    wound(Secret(30), 32) grave(Secret(30))
    Advance(0.5)
    assertEq(verdicts(), "shown", "without the racial: unnamed, at once")
    lines("outgoing")
    assertEq(heals(), 0, "without the racial: the heal isn't named")
    -- an Undead character the game won't say knows the passive
    STATE.race = "Scourge"
    clear() BT.recorded = {}
    Advance(2)
    wound(Secret(30), 32) grave(Secret(30))
    Advance(0.5)
    assertEq(verdicts(), "proc of Touch of the Grave", "Undead: named")
    STATE.race = nil
    BT.db.debug, BT.recorded = false, nil
    clear()
end
clear()
BT.buffShields, BT.itemShields, BT.dots = nil, nil, nil
STATE.buffs, STATE.equipped = {}, {}
reset()
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
-- tests/real_fight.txt and real_fight2.txt are real /btf copy recordings: a cat
-- druid killing mobs with Claw, Rake and Rip, wearing a cape that stings back
-- (and, in the second, Thorns). Each line is replayed at its own time.
--
-- A hit on your target is recorded twice, under its nameplate and then as
-- "target": that's how the replay knows which mob your target is.
-- whoToo(who, target): more units to have about (your pet, and what it's on)
local function replay(file, happenings, whoToo)
    local events = {}
    for line in read_file(ADDON_DIR .. "/tests/" .. file):gmatch("[^\r\n]+") do
        local time, what = line:match("^%s*([%d%.]+)%s%s(.*)$")
        assert(time, "a line of the recording: " .. line)
        if not what:find("^%s") then   -- (indented lines are BattleText's own verdicts)
            local e = { time = tonumber(time), what = what }
            e.unit, e.action, e.flag, e.amount, e.school = what:match("^UNIT_COMBAT (%S+) (%S+) (%S*) (%S+) school (%d+)")
            if not e.unit then   -- (a hidden amount: "(hidden amount)")
                e.unit, e.action, e.flag, e.school = what:match("^UNIT_COMBAT (%S+) (%S+) (%S*) %(hidden amount%) school (%d+)")
                e.secret = e.unit ~= nil
            end
            events[#events + 1] = e
        end
    end
    local targetIs
    for i = #events, 1, -1 do
        local e = events[i]
        if e.unit == "target" and events[i - 1].unit and events[i - 1].unit:find("^nameplate") then
            targetIs = events[i - 1].unit
        end
        e.targetIs = targetIs
    end
    for i = 2, #events do events[i].targetIs = events[i].targetIs or events[i - 1].targetIs end

    local out = {}
    local realEmit = BT.Emit
    BT.Emit = function(self, area, text, ...)
        if area == "outgoing" then out[#out + 1] = text end
        return realEmit(self, area, text, ...)
    end
    local base = FAKE_TIME + 10 - events[1].time
    local mobs, seen, count = {}, {}, 0
    -- The mob behind a nameplate: a new one when that nameplate hasn't been heard of for a while
    local function mob(token, now)
        if not mobs[token] or now - seen[token] >= 8 then
            count = count + 1
            mobs[token] = "replay" .. count
            STATE.unit[mobs[token]] = { enemy = true, guid = "Creature-0-1-2-3-300-0000" .. count, target = "me" }
        end
        seen[token] = now
        return mobs[token]
    end
    -- The older recordings came before BattleText listened to the swing timer (PLAYER_SWING),
    -- which in the game fires for every swing: there, each white hit on the mob gets its swing
    -- (once, under its first name). Alone with the lines arriving, a white hit needs it (1.18.4).
    local swingsRecorded = false
    for _, e in ipairs(events) do
        if e.what:find("^SWING") then swingsRecorded = true end
    end
    local frame, before
    for _, e in ipairs(events) do
        if e.time ~= frame then
            -- A new frame: the one before is over (its timer runs)
            frame = e.time
            FAKE_TIME = base + e.time
            for i = #TIMERS, 1, -1 do
                if TIMERS[i].at <= FAKE_TIME then table.remove(TIMERS, i).fn() end
            end
            for i, h in ipairs(happenings or {}) do
                if h.at and e.time >= h.at then h.at = nil h.fn() end
            end
        end
        if not swingsRecorded and e.unit and e.unit ~= "player" and e.school == "1"
            and (e.unit == e.targetIs or (e.unit == "target" and not (before and before.unit == e.targetIs
                and before.time == e.time and before.amount == e.amount))) then
            fire("PLAYER_SWING", 1.5, 0)
        end
        before = e
        local target = e.targetIs and mob(e.targetIs, e.time)
        STATE.who = { target = target, softenemy = target }
        for token, id in pairs(mobs) do STATE.who[token] = id end
        if whoToo then whoToo(STATE.who, target) end
        if e.what:find("^hidden") then
            assertEq(log(e.what:match("(|K.-|k)")), true, "the line arrives")
        elseif e.what:find("^CAST") then
            fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-r", tonumber(e.what:match("^CAST (%d+)")))
        elseif e.what:find("^SWING") then
            fire("PLAYER_SWING", 1.5, tonumber(e.what:match("^SWING (%d+)")))
        elseif e.unit then
            if e.unit:find("^nameplate") then STATE.who[e.unit] = mob(e.unit, e.time) end
            local amount = e.secret and Secret(100) or tonumber(e.amount)
            fire("UNIT_COMBAT", e.unit, e.action, e.flag, amount, tonumber(e.school))
        else
            -- (logs since 1.18.1 end in "school <n>")
            local what, school = e.what:match("^(.-) school (%S+)$")
            what = what or e.what
            local action, flag, amount = what:match("^UNIT_COMBAT player (%S+) (%S*) (%S+)$")
            if not action then
                action, flag = what:match("^UNIT_COMBAT player (%S+) (%S*) %(hidden amount%)$")
                amount = Secret(20)
            end
            assert(action, "what happened to you: " .. e.what)
            fire("UNIT_COMBAT", "player", action, flag, tonumber(amount) or amount, tonumber(school) or 1)
        end
    end
    BT:FlushHits(true)
    BT.Emit = realEmit
    STATE.who = {}
    return out, count
end
local function freshFight()
    BT.hiddenSeen, BT.hiddenAt, BT.credits, BT.dots, BT.spellSchool = nil, nil, nil, nil, nil
    BT.db.shieldAmounts = {}
    BT.shieldCounts, BT.shieldPending, BT.buffShields, BT.itemShields = nil, nil, nil, nil
    STATE.buffs, STATE.equipped = {}, {}
    clear()
end
local function same(out, expect)
    if os.getenv("DUMP") then io.stderr:write(table.concat(out, " | "), "\n") end
    for i = 1, math.max(#expect, #out) do
        assertEq(out[i], expect[i], "hit " .. i .. " of the fight")
    end
end
local CAPE = { name = "Sporid Cape", icon = 133762,
    lines = { "Equip: When struck in combat, inflicts 1 Nature damage to the attacker." } }

step("a real fight, as the game sent it")
freshFight()
BT.db.merge = false
STATE.equipped[15] = CAPE
fire("PLAYER_EQUIPMENT_CHANGED", 15, true)
local out, mobCount = replay("real_fight.txt")
assertEq(mobCount, 3, "three mobs")
same(out, {
    -- first mob
    "Claw 56", "27", "32", "Sporid Cape 1", "Rake 35", "29", "Sporid Cape 1", "31", "Sporid Cape 1", "Rake 28",
    "28", "32", "Sporid Cape 1", "Rip 16", "56", "Sporid Cape 1", "29",
    -- second mob: the first Rip is parried, the second ticks three times (the last one a crit)
    "Claw 111", "Sporid Cape 1", "60", "Sporid Cape 1", "28", "Rip Parry", "Sporid Cape 1", "27", "29", "31",
    "Sporid Cape 1", "Rip 10", "56", "Sporid Cape 1", "Rip 10", "Sporid Cape 1", "Rip 19",
    -- third mob: the cape answers in the very frame of the opening Claw; Rip ticks six times
    "Claw 108", "Sporid Cape 1", "64", "Sporid Cape 1", "30", "Sporid Cape 1", "30", "Rip 10", "Sporid Cape 1",
    "Sporid Cape 1", "Rip 9", "Sporid Cape 1", "Rip 9", "Sporid Cape 1", "Sporid Cape 1", "Rip 9", "Sporid Cape 1",
    "Rip 9", "Sporid Cape 1", "Rip 9", "Sporid Cape 1", "Claw 59",
})

step("a second real fight: Thorns and the cape together")
freshFight()
STATE.equipped[15] = CAPE
STATE.buffs = { { name = "Thorns", spellId = 1075 } }
fire("PLAYER_ENTERING_WORLD")
out = replay("real_fight2.txt", {
    -- Thorns ran out between the second and third fights (its 11s stop), and was cast again before the last
    { at = 630, fn = function() STATE.buffs = {} fire("UNIT_AURA", "player") end },
})
same(out, {
    -- Thorns' 11 is named from the first one: each answers a blow on you (amounts can't be relied
    -- on: they're often hidden). After Thorns runs out only the cape answers.
    "29", "Sporid Cape 1", "31", "Thorns 11", "26", "27", "Sporid Cape 1", "Thorns 11", "Rake 67",
    "Sporid Cape 1", "Thorns 11", "50", "Sporid Cape 1", "Claw 108", "29", "29", "Sporid Cape 1", "Rake 27",
    "Sporid Cape 1", "Claw 53", "27", "Rake 33", "Sporid Cape 1", "24", "Sporid Cape 1", "28", "48",
    "Sporid Cape 1", "Sporid Cape 1", "Rake 27", "Rip 16", "29", "Sporid Cape 1", "Sporid Cape 1", "30",
    "Rip 31", "Sporid Cape 1", "29", "Sporid Cape 1", "59", "Claw 49", "Sporid Cape 1", "28", "26",
    "Sporid Cape 1", "Rake 33", "Sporid Cape 1", "47", "26", "30", "Rake 27", "Sporid Cape 1", "28", "29",
    "Sporid Cape 1", "27", "Thorns 11", "Thorns 11", "Sporid Cape 1", "28", "Thorns 11", "Sporid Cape 1",
    "Thorns 11", "Sporid Cape 1", "Thorns 11", "Sporid Cape 1", "Thorns 11", "Sporid Cape 1", "Claw 52", "27",
    "Thorns 11", "Sporid Cape 1", "Claw 103",
})
assertEq(BT.db.shieldAmounts.Thorns, 11, "Thorns was learned on the way")

step("a third real fight: mobs that can't bleed, and attacks that land in two parts")
freshFight()
STATE.equipped[15] = CAPE
STATE.buffs = { { name = "Thorns", spellId = 1075 } }
fire("PLAYER_ENTERING_WORLD")
BT.db.shieldAmounts = { Thorns = 11 }
local taken = {}
local emit = BT.Emit
BT.Emit = function(self, area, text, ...)
    if area == "incoming" then taken[#taken + 1] = text end
    return emit(self, area, text, ...)
end
out = replay("real_fight3.txt", {
    -- (in the recording Thorns was cast before the second fight; the first has only the cape's answers)
    { at = 390, fn = function() STATE.buffs = {} fire("UNIT_AURA", "player") end },
})
BT.Emit = emit
same(out, {
    -- first mob: Rake lands but never ticks
    "Claw 54", "Sporid Cape 1", "29", "55", "Claw 56", "29", "24", "Rake 35", "Sporid Cape 1", "62", "Claw 55", "29",
    "Sporid Cape 1", "25",
    -- second mob, with Thorns up again: both shields answer every blow
    "Thorns 11", "Sporid Cape 1", "30", "52", "Rake 35", "Thorns 11", "Sporid Cape 1", "25", "27", "Thorns 11",
    "Sporid Cape 1", "57", "Claw 109", "28", "Thorns 11", "Sporid Cape 1", "26", "27", "31",
    -- third mob: Rip finds it immune
    "Thorns 11", "Sporid Cape 1", "Claw 50", "29", "29", "Rake 34", "Thorns 11", "Sporid Cape 1", "25", "Rip Immune",
    "Thorns 11", "Sporid Cape 1", "27", "50", "Rake 35", "Thorns 11", "Sporid Cape 1", "27", "27", "28", "Thorns 11",
    "Sporid Cape 1", "Rake 35", "27", "27", "Thorns 11", "Sporid Cape 1",
})
-- What happened to you: three of the mobs' attacks came as "WOUND 0" and "WOUND 33" in one
-- frame. Each is one blow, not a miss and a blow.
same(taken, { "-19", "Dodge", "-33", "-19", "-18", "-36", "-19", "-21", "-18", "-19", "-36", "-21", "-20", "-20" })
-- Cast naming goes by order: a hit ahead of the cast in its frame isn't the cast's
freshFight()
STATE.unit.mobA = { enemy = true, guid = "Creature-0-1-2-3-100-00000A", target = "me" }
STATE.who.target = "mobA"
fire("UNIT_COMBAT", "target", "WOUND", "", 7, 8)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-o", 1082)
fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
assertEq(table.concat(lines("outgoing"), " / "), "7 / Claw 50", "the hit before the cast is just a hit")
-- And a shield's answer between a cast and its hit is still the shield's
freshFight()
STATE.equipped[15] = CAPE
fire("PLAYER_EQUIPMENT_CHANGED", 15, true)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-p", 1082)
fire("UNIT_COMBAT", "target", "WOUND", "", 1, 8)
fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
assertEq(table.concat(lines("outgoing"), " / "), "Sporid Cape 1 / Claw 50", "the cape's answer isn't taken for the cast's hit")
-- Your own attacks can come in two parts too (Maul): one blow, not a miss and a hit
freshFight()
STATE.unit.mobA = { enemy = true, guid = "Creature-0-1-2-3-100-00000A", target = "me" }
STATE.who.target = "mobA"
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-q", 1082)   -- (any attack; the game sends Maul this way)
fire("UNIT_COMBAT", "target", "WOUND", "", 0, 1)
fire("UNIT_COMBAT", "target", "WOUND", "", 37, 1)
assertEq(table.concat(lines("outgoing"), " / "), "Claw 37", "an attack in two parts: no Miss with it")
Advance(1)
fire("UNIT_COMBAT", "target", "WOUND", "", 0, 1)
assertEq(last("outgoing"), "Miss", "a hit for nothing on its own is still a miss")
Advance(1)
fire("UNIT_COMBAT", "target", "WOUND", "PARRY", 0, 1)
fire("UNIT_COMBAT", "target", "WOUND", "", 30, 1)
assertEq(table.concat(lines("outgoing"), " / "), "Claw 37 / Miss / Parry / 30", "a parry says so, whatever lands with it")
-- With the amounts hidden the empty part can't be read as 0 (the game draws "0"). Two frames from
-- a player's /btf debug: Maul, a hit, a line, a crit; and Maul with Thorns answering in between.
local function maulFrame(...)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-m-" .. GetTime(), 6807)
    for _, step in ipairs({ ... }) do
        if step == "line" then hidden(1668) else fire("UNIT_COMBAT", "target", "WOUND", step[2] or "", Secret(step[1]), step[3] or 1) end
    end
    return lines("outgoing")
end
clear()
local got = maulFrame({ 0 }, "line", { 43, "CRITICAL" })
assertEq(#got, 1, "Maul with hidden amounts: one line, no \"0\"")
assertEq(BT.areas.outgoing.active[1].sticky, true, "and it's the crit")
clear()
got = maulFrame({ 0 }, { 11, "", 8 }, "line", { 40 })
assertEq(#got, 2, "Maul and Thorns: two lines, no \"0\"")
STATE.who = {}

step("a fourth real fight: Shred, whose hit comes ahead of its cast")
-- tests/real_fight4.txt opens with a Shred from stealth. The game sent the line, the hit, the
-- cast and then both damage shields' answers in one frame: the hit with a line just ahead of
-- it is the cast's, whichever side of the cast it falls on.
freshFight()
STATE.equipped[15] = CAPE
STATE.buffs = { { name = "Thorns", spellId = 1075 } }
fire("PLAYER_ENTERING_WORLD")
BT.db.shieldAmounts = { Thorns = 11 }
BT.db.outShields = false   -- as in the recording
out = replay("real_fight4.txt")
same(out, {
    "Shred 131", "59", "31", "26", "Rake 35", "Dodge", "24", "60", "Rake 29", "Rip 17", "Parry", "27", "Rip 17", "27",
    "Rake 29",
})
assertEq(BT.schoolSeen and BT.schoolSeen[5221] and BT.schoolSeen[5221].school, 1, "Shred was seen as physical")
assertEq(BT.spellSchool and BT.spellSchool[5221], nil, "but one frame isn't enough to learn it")
BT.db.outShields = true
-- The same fight with neither shield known yet: their answers still aren't taken for Shred
freshFight()
out = replay("real_fight4.txt")
assertEq(out[1], "Shred 131", "the hit with the line is Shred's")
assertEq(out[2], "11", "the first shield answer is just a hit (the frame's second line vouches for it)")
-- (alone with the lines, a hit no line vouches for and no shield of yours explains isn't shown: 1.18.4)
assertEq(out[3], "59", "the second, with no line left for it, is left out")
assertEq(BT.schoolSeen and BT.schoolSeen[5221] and BT.schoolSeen[5221].school, 1, "and Shred isn't taken for a nature spell")
-- A swing landing in the frame of a cast whose own hit has the line: only that hit is the cast's
freshFight()
STATE.unit.mobA = { enemy = true, guid = "Creature-0-1-2-3-100-00000A", target = "me" }
STATE.who.target = "mobA"
fire("UNIT_COMBAT", "target", "WOUND", "", 30, 1)
log("|Ky1|k")
fire("UNIT_COMBAT", "target", "WOUND", "", 72, 1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-s", 5221)
fire("PLAYER_SWING", 1.5, 0)   -- (the 30 and the 9 are swings: alone with the lines, they need theirs)
fire("PLAYER_SWING", 1.5, 0)
fire("UNIT_COMBAT", "target", "WOUND", "", 9, 1)
assertEq(table.concat(lines("outgoing"), " / "), "30 / Shred 72 / 9", "one line, one hit for the cast")
-- A miss with its line ahead of the cast is the cast's too
freshFight()
STATE.who.target = "mobA"
log("|Ky2|k")
fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-t", 5221)
assertEq(table.concat(lines("outgoing"), " / "), "Shred Dodge", "a dodged Shred says so")
-- Ravage from Prowl with no line (Tyler's log, 1.40.4, 737.03): SWING, its one hit, then its CAST,
-- all in one frame while the lines flow. The hit ahead of the cast is Ravage's, not a white hit
freshFight()
STATE.who.target = "mobA"
log("|Ky3|k")   -- (lines arriving lately: Thrill of Adventure's)
Advance(1.6)
fire("PLAYER_SWING", 1.5, 0)
fire("UNIT_COMBAT", "target", "WOUND", "", 140, 1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-rv", 6785)
assertEq(table.concat(lines("outgoing"), " / "), "Ravage 140", "the one hit ahead of the cast is Ravage's")
-- With a hit after the cast too, that one is the cast's, as before
freshFight()
STATE.who.target = "mobA"
log("|Ky4|k")
Advance(1.6)
fire("PLAYER_SWING", 1.5, 0)
fire("UNIT_COMBAT", "target", "WOUND", "", 30, 1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-cl", 1082)
fire("UNIT_COMBAT", "target", "WOUND", "", 60, 1)
assertEq(table.concat(lines("outgoing"), " / "), "30 / Claw 60", "a hit after the cast is the cast's")
-- A spell's school takes two frames to learn, and two frames to unlearn (BT-006)
do
    local function clawFrame(school)
        clear()
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-6-" .. GetTime(), 1082)
        fire("UNIT_COMBAT", "target", "WOUND", "", 20, school)
        Advance(0.1)
        return table.concat(lines("outgoing"), " / ")
    end
    freshFight()
    STATE.who.target = "mobA"
    clawFrame(8)   -- an unlucky first frame: a nature answer right behind the cast
    assertEq(BT.spellSchool and BT.spellSchool[1082], nil, "one nature frame doesn't make Claw a nature spell")
    assertEq(clawFrame(1), "Claw 20", "so Claw's real hit is still named")
    clawFrame(1)
    assertEq(BT.spellSchool and BT.spellSchool[1082], 1, "two physical frames: Claw is learned as physical")
    -- Learned wrong anyway: two frames of the spell's own hits put it right
    BT.spellSchool[1082], BT.schoolSeen[1082] = 8, { school = 8, n = 2 }
    assertEq(clawFrame(1), "20", "learned wrong, the hit isn't named")
    clawFrame(1)
    assertEq(BT.spellSchool[1082], 1, "two frames of physical hits relearn it")
    assertEq(clawFrame(1), "Claw 20", "and Claw is named again")
end
-- The units you struck are forgotten after a while (BT-014)
do
    BT.struck = { old = GetTime() - 60, new = GetTime() }
    BT:ForgetOldDots()
    assertEq(BT.struck.old, nil, "a unit struck a minute ago is forgotten")
    assert(BT.struck.new, "one struck just now isn't")
    BT.struck = nil
end
-- A line from the pool that has the font already isn't given it again; a new font is (BT-022)
do
    clear()
    log(hit("Claw", 16827, 41))
    local o = BT.areas.outgoing.active[1]
    clear()
    local calls = 0
    local setFont = o.text.SetFont
    o.text.SetFont = function(...) calls = calls + 1 return setFont(...) end
    log(hit("Claw", 16827, 42))
    assertEq(BT.areas.outgoing.active[1], o, "(the same line, from the pool)")
    assertEq(calls, 0, "same font, size and outline: not set again")
    clear()
    local fontWas = BT.db.font
    BT.db.font = BT.FONTS[3].name
    log(hit("Claw", 16827, 43))
    assertEq(BT.areas.outgoing.active[1] == o, true, "(the same line again)")
    assertEq(calls, 1, "another font: set")
    assertEq(o.text.__font[1], BT.FONTS[3].path, "to the new one")
    BT.db.font = fontWas
    o.text.SetFont = nil
    clear()
end
-- An icon the game can't find by name yet is asked for again a little later (BT-019)
do
    BT.iconCache, BT.iconMissAt = nil, nil
    assertEq(BT:IconText("Late Spell"), "", "no icon yet")
    STATE.spellIcons["Late Spell"] = 135000
    Advance(1)
    assertEq(BT:IconText("Late Spell"), "", "not asked again straight away")
    Advance(10)
    assertEq(BT:IconText("Late Spell"), "|T135000:0|t ", "but a little later it's found")
    STATE.spellIcons["Late Spell"], BT.iconCache, BT.iconMissAt = nil, nil, nil
end
-- Lines are arriving, but this frame's hit has none: it goes by order, as before
freshFight()
STATE.who.target = "mobA"
log("|Ky3|k")
Advance(1)
fire("PLAYER_SWING", 1.5, 0)
fire("UNIT_COMBAT", "target", "WOUND", "", 7, 1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-3-u", 1082)
fire("UNIT_COMBAT", "target", "WOUND", "", 50, 1)
assertEq(table.concat(lines("outgoing"), " / "), "7 / Claw 50", "no line in the frame: the hit after the cast is its hit")
STATE.who = {}
BT.db.merge = true
freshFight()

step("a fifth real fight: a warlock's Shadow Bolt landing just after Bane of Agony ticked")
-- tests/real_fight5.txt (issue #20, 1.16.5, every amount hidden): Bane of Agony ticks every 2s
-- at .55, Corruption every 3s, a shadow wand shoots. Shadow Bolt is cast at 416.27; Bane of Agony
-- ticks at 416.55 and the bolt lands at 416.66, still inside that beat's slack. 1.16.5 took the
-- bolt for a second tick of Bane of Agony (a tick on its beat beats a spell on its way when the
-- amounts can't be compared), found no line behind it, and showed it with no name.
do
local function warlockFight()
    freshFight()
    STATE.class, STATE.pet = "WARLOCK", true
    for id, name in pairs({ [6217] = "Bane of Agony", [17920] = "Searing Pain", [7648] = "Corruption",
            [7641] = "Shadow Bolt", [5019] = "Shoot" }) do STATE.spellNames[id] = name end
    BT.db.debug, BT.recorded = true, {}
    replay("real_fight5.txt")
    BT.db.debug = false
    local named = {}
    for _, l in ipairs(BT.recorded) do
        local what = l:match("^%s*[%d.]+%s%s%s%snameplate2 %(hidden amount%): (.*)$")
        if what then named[#named + 1] = what end
    end
    STATE.class, STATE.pet, BT.recorded = "DRUID", false, nil
    return named
end
local named = warlockFight()
local bolt = 0
for _, what in ipairs(named) do if what == "cast of Shadow Bolt" then bolt = bolt + 1 end end
assertEq(bolt, 1, "the Shadow Bolt is named")
assertEq(named[14], "tick of Bane of Agony", "the tick before it is still Bane of Agony's")
assertEq(named[15], "cast of Shadow Bolt", "and the hit 0.1s later is the bolt")
local ticks = { ["tick of Bane of Agony"] = 0, ["tick of Corruption"] = 0 }
for _, what in ipairs(named) do if ticks[what] then ticks[what] = ticks[what] + 1 end end
assertEq(ticks["tick of Bane of Agony"], 6, "every Bane of Agony tick is named (one a beat)")
assertEq(ticks["tick of Corruption"], 3, "and every Corruption tick")
-- The other way round: the bolt lands 0.2s before Bane of Agony's beat, with a line behind it.
-- Once the dot has ticked its beat is known closely, so the bolt isn't taken for the tick (and
-- the tick, when it comes, isn't taken for the bolt).
freshFight()
STATE.unit.mobA = { enemy = true, guid = "Creature-0-1-2-3-100-00000A", target = "me" }
STATE.who.target = "mobA"
STATE.spellNames[6217], STATE.spellNames[7641] = "Bane of Agony", "Shadow Bolt"
local function hiddenHit(n) fire("UNIT_COMBAT", "target", "WOUND", "", Secret(n), 32) end
BT.db.debug, BT.recorded = true, {}
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-w-1", 6217)
Advance(2) hiddenHit(30) hidden(9001)
Advance(2) hiddenHit(30) hidden(9001)
Advance(1.5) fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-w-2", 7641)
Advance(0.3) hiddenHit(90) hidden(9002)
Advance(0.2) hiddenHit(30) hidden(9001)
BT:FlushHits(true)
BT.db.debug = false
local got = {}
for _, l in ipairs(BT.recorded) do
    local what = l:match("^%s*[%d.]+%s%s%s%starget %(hidden amount%): (.*)$")
    if what then got[#got + 1] = what end
end
assertEq(table.concat(got, " / "), "tick of Bane of Agony / tick of Bane of Agony / cast of Shadow Bolt / tick of Bane of Agony",
    "a bolt just ahead of the beat is the bolt, and the tick is the tick")
STATE.who, BT.recorded = {}, nil
end

step("a sixth real fight: a Shadow damage that BattleText doesn't know ticks while a Shadow Bolt flies")
-- tests/real_fight6.txt (issue #21, 1.21.0, every amount hidden): Bane of Agony ticks every 2s at
-- .5x, Corruption every 3s, Immolate, and a Shadow damage of the warlock's that BattleText has no
-- name for (Demonic Brand) every 2s at .6x, 0.1s after Bane of Agony. Shadow Bolt is cast at
-- 675.01; Bane of Agony ticks at 675.52, the unknown one at 675.66, and the bolt lands (a crit)
-- at 676.27. 1.21.0 gave the unknown tick the bolt's name and showed the bolt with none.
do
freshFight()
STATE.class, STATE.pet = "WARLOCK", true
for id, name in pairs({ [6217] = "Bane of Agony", [17920] = "Searing Pain", [7648] = "Corruption",
        [7641] = "Shadow Bolt", [2941] = "Immolate" }) do STATE.spellNames[id] = name end
BT.db.debug, BT.recorded = true, {}
replay("real_fight6.txt")
BT.db.debug = false
-- (by the recording's own times: its first verdict is at 663.58)
local at, first = {}, nil
for _, l in ipairs(BT.recorded) do
    local t, what = l:match("^%s*([%d.]+)%s%s%s%snameplate7 %(hidden amount%): (.*)$")
    if t then
        first = first or tonumber(t)
        at[("%.2f"):format(tonumber(t) - first + 663.58)] = what
    end
end
STATE.class, STATE.pet, BT.recorded = "DRUID", false, nil
assertEq(at["675.52"], "tick of Bane of Agony", "Bane of Agony's tick is its own")
assertEq(at["675.66"], "shown", "the unknown Shadow tick on its 2s beat isn't taken for the bolt")
assertEq(at["676.27"], "cast of Shadow Bolt", "the bolt is named when it lands")
local ticks = { ["tick of Bane of Agony"] = 0, ["tick of Corruption"] = 0, ["tick of Immolate"] = 0 }
local bolts = 0
for _, what in pairs(at) do
    if ticks[what] then ticks[what] = ticks[what] + 1 end
    if what == "cast of Shadow Bolt" then bolts = bolts + 1 end
end
assertEq(bolts, 1, "one Shadow Bolt landed in the recording")
assertEq(ticks["tick of Bane of Agony"], 8, "every Bane of Agony tick is named")
assertEq(ticks["tick of Corruption"], 4, "and every Corruption tick")
assertEq(ticks["tick of Immolate"], 2, "and Immolate's")
STATE.who = {}
end

step("a seventh real fight: the unknown Shadow tick lands in a Shadow Bolt's cast frame")
-- tests/real_fight7.txt (issue #24, 1.21.6, every amount hidden, an Undead warlock): the Shadow
-- damage BattleText has no name for ticks every ~2.5s (560.54, 563.05, 565.57). The second Shadow
-- Bolt is cast at 565.57, in the very frame of that tick, and lands at 566.15. 1.21.6 took the
-- tick for the bolt (a spell that needs no time to land) and left the bolt with no name.
do
freshFight()
STATE.class, STATE.pet, STATE.race = "WARLOCK", true, "Scourge"
for id, name in pairs({ [11711] = "Bane of Agony", [17920] = "Searing Pain", [7648] = "Corruption",
        [7641] = "Shadow Bolt", [1260189] = "Touch of the Grave", [1260201] = "Touch of the Grave" }) do
    STATE.spellNames[id] = name
end
BT.db.debug, BT.recorded = true, {}
replay("real_fight7.txt")
BT.db.debug = false
local at, first = {}, nil
for _, l in ipairs(BT.recorded) do
    local t, what = l:match("^%s*([%d.]+)%s%s%s%snameplate1 %(hidden amount%): (.*)$")
    if t then
        first = first or tonumber(t)
        local k = ("%.2f"):format(tonumber(t) - first + 555.53)
        at[k] = at[k] and (at[k] .. " / " .. what) or what
    end
end
STATE.class, STATE.pet, STATE.race, BT.recorded = "DRUID", false, nil, nil
assertEq(at["562.47"], "cast of Shadow Bolt", "the first bolt is named")
assert(not (at["565.57"] or ""):find("Shadow Bolt", 1, true),
    "the unknown tick in the second bolt's cast frame isn't the bolt: " .. tostring(at["565.57"]))
assertEq(at["566.15"], "cast of Shadow Bolt", "the second bolt is named when it lands")
local bolts = 0
for _, what in pairs(at) do
    for _ in what:gmatch("cast of Shadow Bolt") do bolts = bolts + 1 end
end
assertEq(bolts, 2, "two Shadow Bolts landed in the recording")
STATE.who = {}
clear()
end

step("an eighth real fight: a paladin's blocks give Shield Specialization's mana")
-- tests/real_fight8.txt (1.41.0, Tyler's Protection paladin, every amount hidden): six blocks
-- (901.84, 902.10, 903.82, 904.16, 908.16, 920.18) and not one mana line from the game, no
-- UNIT_COMBAT ENERGIZE and no combat log line near any of them. Until 1.41.1 the talent's mana
-- waited for an ENERGIZE, so it never showed. The talent gives mana at most once every 3 seconds:
-- the blocks at 901.84, 908.16 and 920.18.
do
local GAME = getmetatable(_G).__index
local powerType = GAME.UnitPowerType
GAME.UnitPowerType = function() return 0, "MANA" end
STATE.class = "PALADIN"
STATE.spellNames[20150] = "Shield Specialization"
STATE.spellNames[20925], STATE.spellNames[1292851] = "Holy Shield", "Lightning Bolt"
STATE.knownSpells[20150] = true
BT.db.inPower = true
local mana = {}
local realEmit = BT.Emit
BT.Emit = function(self, area, text, ...)
    if type(text) == "string" and text:find("Mana", 1, true) then mana[#mana + 1] = text end
    return realEmit(self, area, text, ...)
end
local function fight()
    freshFight()
    BT.lastBlock, BT.shieldSpecAt, BT.energizeAt, BT.manaRise = nil, nil, nil, nil
    mana = {}
    replay("real_fight8.txt")
    return mana
end
-- Forever hides your mana, and the most you can have too: the talent's 4%
STATE.mana, STATE.manaMax, STATE.manaHidden, STATE.manaMaxHidden = 600, 1000, true, true
local got = fight()
assertEq(#got, 3, "one Shield Specialization per 3 seconds of blocks: " .. table.concat(got, " | "))
assertEq(got[1], "+4% Mana Shield Specialization", "both hidden: it says 4%")
-- Only your mana hidden: 4% of the most
STATE.manaMaxHidden = nil
got = fight()
assertEq(#got, 3, "the same three blocks")
assertEq(got[1], "+40 Mana Shield Specialization", "4% of 1000 mana")
-- Your mana can be read, and the bar didn't move (full, or rank 1's chance missed): nothing
STATE.manaHidden = nil
got = fight()
assertEq(#got, 0, "no rise, no mana shown: " .. table.concat(got, " | "))
-- The bar rose at the block: that rise
local blocks, gaveAt = 0, nil
local onCombat = BT.OnUnitCombat
BT.OnUnitCombat = function(self, unit, action, ...)
    local r = onCombat(self, unit, action, ...)
    if unit == "player" and action == "BLOCK" then
        blocks = blocks + 1
        if not gaveAt or GetTime() - gaveAt >= 3 then   -- (the game's own 3 seconds)
            gaveAt = GetTime()
            STATE.mana = STATE.mana + 37
            BT:OnMana()
        end
    end
    return r
end
STATE.mana = 500
BT.manaSeen = 500
got = fight()
BT.OnUnitCombat = onCombat
assertEq(blocks, 6, "six blocks")
assertEq(got[1], "+37 Mana Shield Specialization", "the bar's own rise")
assertEq(#got, 3, "still once per 3 seconds")
-- Without the talent, a block gives nothing
STATE.knownSpells[20150] = nil
STATE.manaHidden = true
got = fight()
assertEq(#got, 0, "no talent, no mana")
-- The game's own ENERGIZE beside a block is shown once, not twice
STATE.knownSpells[20150] = true
clear()
BT.lastBlock, BT.shieldSpecAt, BT.energizeAt, mana = nil, nil, nil, {}
Advance(5)
fire("UNIT_COMBAT", "player", "BLOCK", "", 0, 1)
Advance(0.1)
fire("UNIT_COMBAT", "player", "ENERGIZE", "", 40, 1)
Advance(0.6)
assertEq(#mana, 1, "one line: " .. table.concat(mana, " | "))
assertEq(mana[1], "+40 Mana Shield Specialization", "the game's own amount")
BT.Emit = realEmit
STATE.knownSpells[20150] = nil
STATE.manaHidden, STATE.manaMaxHidden, BT.manaSeen = nil, nil, nil
STATE.mana, STATE.manaMax = 1000, 1000
GAME.UnitPowerType = powerType
BT.db.inPower = false
BT.lastBlock, BT.shieldSpecAt, BT.energizeAt, BT.manaRise = nil, nil, nil, nil
STATE.class = "DRUID"
STATE.who = {}
clear()
end

step("a ninth real fight: a hunter shooting, with a pet and hawks on the same mob")
-- tests/real_fight9.txt (1.42.0, GitHub #41, every amount hidden)
do
STATE.class = "HUNTER"
STATE.spellNames[75], STATE.spellNames[1293525], STATE.spellNames[20901] = "Auto Shot", "Summon Hawk", "Aimed Shot"
STATE.spellNames[14319] = "Aspect of the Hawk"
local function fight()
    freshFight()
    BT.flying, BT.hawks, BT.swings, BT.hands, BT.swungAt, BT.meleeAt = nil, nil, nil, nil, nil, nil
    BT:RemakeSpellLists()
    BT.db.debug, BT.recorded = true, {}
    local out = replay("real_fight9.txt", nil, function(who, target) who.pettarget = target end)
    local verdicts = {}
    for _, r in ipairs(BT.recorded) do
        local at, v = r:match("^%s*([%d%.]+)%s+nameplate1 [^:]+: (.+)$")
        if v then verdicts[#verdicts + 1] = v end
    end
    BT.db.debug, BT.recorded = false, nil
    return out, verdicts
end
STATE.pet, STATE.unit.pet = true, { friend = true }
STATE.group = false
fire("GROUP_ROSTER_UPDATE")
-- Until 1.43.0 the pet's blow right after a shot took the shot's name (its dodge at 501.99 was
-- "Auto Shot Dodge", its parry at 505.33 "Aimed Shot Parry") and the shot itself, landing with
-- its line, showed as the pet's. Each of the eight lines in the recording comes with one shot.
local out = fight()
local named, wrong = {}, {}
for _, text in ipairs(out) do
    if not text:find("^%(") then
        named[#named + 1] = text:match("^(.-Shot)") or text:match("^(Summon Hawk)") or text
        if text:find("Dodge") or text:find("Parry") then wrong[#wrong + 1] = text end
    end
end
assertEq(table.concat(named, ", "), "Auto Shot, Summon Hawk, Auto Shot, Auto Shot, Aimed Shot, Summon Hawk, Auto Shot, Auto Shot",
    "every shot with its line named, and nothing else")
assertEq(#wrong, 0, "no dodge or parry (the pet's) named after a shot: " .. table.concat(wrong, ", "))
STATE.pet, STATE.unit.pet = false, nil
STATE.class = "DRUID"
STATE.who = {}
clear()
end

step("a tenth real fight: the same hunter, with the pet's and hawks' lines arriving too")
-- tests/real_fight10.txt (1.43.0, GitHub #41, every amount hidden, SENT lines left out). After the
-- first fight, every shot showed as the pet's: the pet's and hawks' blows, shown as "(Pet)", were
-- also kept as unnamed hits of yours, so thick that every shot's hit seemed on the beat of an
-- unknown tick (OnUnnamedBeat) and lost its name.
do
STATE.class = "HUNTER"
STATE.spellNames[75], STATE.spellNames[1293525], STATE.spellNames[20901] = "Auto Shot", "Summon Hawk", "Aimed Shot"
STATE.spellNames[14323] = "Hunter's Mark"
STATE.pet, STATE.unit.pet = true, { friend = true }
STATE.group = false
fire("GROUP_ROSTER_UPDATE")
freshFight()
BT.flying, BT.hawks, BT.swings, BT.hands, BT.swungAt, BT.meleeAt, BT.unnamed = nil, nil, nil, nil, nil, nil, nil
BT:RemakeSpellLists()
-- (the recording starts mid-fight: you'd been shooting already)
local out = replay("real_fight10.txt", { { at = 0, fn = function() BT.swungAt = GetTime() end } },
    function(who, target) who.pettarget = target end)
local named, pets, glancing = {}, 0, {}
for _, text in ipairs(out) do
    if text:find("^%(") then
        pets = pets + 1
    else
        named[#named + 1] = (text:gsub("%s+$", ""))
    end
end
assertEq(table.concat(named, ", "), "Summon Hawk, Auto Shot, Aimed Shot Miss, Auto Shot, Summon Hawk, Auto Shot, "
    .. "Auto Shot, Aimed Shot, Summon Hawk, Auto Shot, Auto Shot, Auto Shot, Aimed Shot",
    "each shot and hawk dive names one hit")
assertEq(pets, 45, "the rest are the pet's (and hawks')")
-- A glancing blow is a melee auto attack's: never a shot's, even with a line just ahead of it
BT.flying = { { name = "Auto Shot", id = 75, key = "glance-mob", at = GetTime() - 0.4, school = 1, auto = true } }
BT.credits, BT.hiddenSeen = { GetTime() }, true
STATE.unit.glanceMob = { enemy = true, guid = "glance-mob" }
local h = { unit = "glanceMob", key = "glance-mob", kind = "damage", action = "WOUND", flag = "GLANCING", school = 1, time = GetTime() }
assertEq(BT:FlightFor(h), nil, "a glancing blow isn't the shot's")
h.flag = ""
assertEq(BT:FlightFor(h) ~= nil, true, "a plain hit is")
BT.flying, BT.credits, STATE.unit.glanceMob = nil, nil, nil
STATE.pet, STATE.unit.pet = false, nil
STATE.class = "DRUID"
STATE.who = {}
clear()
end

step("an eleventh real fight: Tyler's cat druid, Rake's bleed with Thorns and the ring stinging back")
-- tests/real_fight11.txt (1.47.2, Tyler's druid, every amount hidden, SENT lines left out). Rake's
-- ticks come with no line on his game, while Thorns' and the Spiked Shell Band's lines keep coming.
-- Until 1.47.2 a shield's line landing in the frame of a hit on Rake's beat was counted as Rake's
-- tick coming with its line (BT.tickLines); after two, Rake's beat named nothing for the rest of the
-- session. In game every tick showed as a plain white hit, the last one (127.28, no swing near it)
-- turned away as "no line of yours with it".
do
STATE.class = "DRUID"
STATE.spellNames[1823], STATE.spellNames[3029], STATE.spellNames[768] = "Rake", "Claw", "Cat Form"
STATE.spellNames[1066], STATE.spellNames[414924] = "Aquatic Form", "Feral Charge (Cat)"
local RING = { name = "Spiked Shell Band", icon = 133345,
    lines = { "Equip: When struck in combat, inflicts 2 Nature damage to the attacker." } }
local function geared()
    STATE.buffs = { { name = "Thorns", spellId = 782 } }
    fire("PLAYER_REGEN_ENABLED")
    STATE.equipped[11] = RING
    fire("PLAYER_EQUIPMENT_CHANGED", 11, true)
end
local function fight()
    freshFight()
    BT.flying, BT.hawks, BT.swings, BT.hands, BT.swungAt, BT.meleeAt, BT.unnamed = nil, nil, nil, nil, nil, nil, nil
    geared()
    BT:RemakeSpellLists()
    BT.db.debug, BT.recorded = true, {}
    local out = replay("real_fight11.txt")
    local ticks, zero = {}, nil
    for _, r in ipairs(BT.recorded) do
        -- (times as recorded: the first Rake, dodged, was at 110.80)
        local cast = r:match("^%s*([%d%.]+)%s+nameplate1 [^:]+: cast of Rake$")
        if cast and not zero then zero = tonumber(cast) - 110.80 end
        local at = r:match("^%s*([%d%.]+)%s+nameplate1 [^:]+: tick of Rake$")
        if at then ticks[#ticks + 1] = string.format("%.2f", tonumber(at) - zero) end
    end
    BT.db.debug, BT.recorded = false, nil
    local rakes = 0
    for _, text in ipairs(out) do
        if text:find("^Rake") and not text:find("Dodge") then rakes = rakes + 1 end
    end
    return ticks, rakes
end
-- The hits on Rake's beat: 115.59 (3s after the cast at 112.69), then 121.31, 124.34 and 127.28 (from
-- the cast again at 118.26)
local function shift(list) return table.concat(list, " ") end
BT.dots, BT.tickLines = nil, nil
local ticks, rakes = fight()
assertEq(shift(ticks), "115.59 121.31 124.34 127.28", "Rake's ticks named by their beat")
assertEq(rakes, 2 + 4, "on screen: the two Rakes that hit, and four ticks")
-- A session's earlier fights: Thorns and the ring answering a blow (a line, two Nature hits) in the
-- frame of a hit on Rake's beat, twice. Their line isn't Rake's tick's: Rake keeps its beat.
freshFight()
geared()
BT.dots, BT.swings, BT.swungAt, BT.tickLines = nil, nil, nil, nil
STATE.unit.rakeMob = { enemy = true, guid = "Creature-0-1-2-3-311-00000R", target = "me" }
STATE.who = { target = "rakeMob", nameplate1 = "rakeMob" }
hidden(356)
cast(1823) wound(30)
for k = 1, 2 do
    Advance(k == 1 and 3 or 2.7)
    wound(12) hidden(356 + k) wound(9, 8) wound(2, 8)
    Advance(0.3) fire("UNIT_COMBAT", "player", "WOUND", "", 20, 1)
end
Advance(2)
assertEq(lines("outgoing")[#lines("outgoing") - 2], "Rake 12", "(each one Rake's tick)")
assert(((BT.tickLines or {}).Rake or 0) < 2, "a shield's lines aren't Rake's ticks' lines")
STATE.unit.rakeMob = nil
BT.dots = nil
ticks, rakes = fight()
assertEq(shift(ticks), "115.59 121.31 124.34 127.28", "after them, Rake's ticks are still named")
-- And a tick on its beat with no line behind it wipes out a line counted for it before
BT.dots, BT.tickLines = nil, { Rake = 1 }
fight()
assertEq((BT.tickLines or {}).Rake, nil, "a tick with no line: this game sends none for Rake's ticks")
-- (on a game that does send them, two in a row still switch its beat off: see "Rake on a game that
-- sends Rake's ticks their lines" above)
BT.tickLines = { Rake = 2 }
BT.dots = nil
ticks = fight()
assertEq(#ticks, 0, "switched off: no tick by its beat alone (what Tyler saw)")
BT.dots, BT.tickLines = nil, nil
STATE.equipped[11] = nil
fire("PLAYER_EQUIPMENT_CHANGED", 11, false)
STATE.buffs = {}
STATE.class = "DRUID"
STATE.who = {}
clear()
end

step("lines scroll, keep their distance and go away")
log(hit("Claw", 16827, 50))
log(hit("Bite", 17253, 60))
log(hit("Rake", 1822, 70))
local act = BT.areas.outgoing.active
assert(act[2].start > act[1].start and act[3].start > act[2].start, "each line starts after the one before")
Advance(1)
assert(act[1].__pos[2] < 0, "moving down")
assert((act[1].__pos[1] - act[1].edgeX) > 0, "bowing outward")
BT.db.outCurved = false
Advance(0.1)
assertEq((act[1].__pos[1] - act[1].edgeX), 0, "straight when curves are off")
BT.db.outCurved = true
local downY = act[1].__pos[2]
BT.db.outScrollUp = true
BT:Animate(GetTime())
local upY = act[1].__pos[2]
assert(upY < downY, "scrolling up: the line starts low in its area")
Advance(0.5)
assert(act[1].__pos[2] > upY, "and moves up")
assert((act[1].__pos[1] - act[1].edgeX) > 0, "still bowing outward")
-- Each area has its own: Outgoing up, Incoming down
local out = BT:Emit("outgoing", "5", { 1, 1, 1 })
local inc = BT:Emit("incoming", "-30", { 1, 1, 1 })
Advance(0.5)
assert(inc.__pos[2] > -BT:AreaHeight(BT.areas.incoming) / 2, "Incoming still scrolls down from the top")
assert(out.__pos[2] < -BT:AreaHeight(BT.areas.outgoing) / 2, "while Outgoing scrolls up from the bottom")
BT.db.inCurved = false
Advance(0.1)
assertEq((inc.__pos[1] - inc.edgeX), 0, "Incoming straight")
assert((out.__pos[1] - out.edgeX) > 0, "Outgoing still curved")
BT.db.inCurved, BT.db.outScrollUp = true, false
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
-- Money you loot: off by default (its own Money setting), "+1g 25s 30c" when on, in any language
SetGameText("GOLD_AMOUNT", "%d Gold"); SetGameText("SILVER_AMOUNT", "%d Silver"); SetGameText("COPPER_AMOUNT", "%d Copper")
BT.moneyPatterns = nil
BT.db.nMoney = false
fire("CHAT_MSG_MONEY", "You loot 1 Gold, 25 Silver, 30 Copper")
assertEq(#lines("notify"), 0, "money is off unless its setting is on (not the Loot setting)")
BT.db.nMoney = true
fire("CHAT_MSG_MONEY", "You loot 1 Gold, 25 Silver, 30 Copper")
assertEq(last("notify"), "+|cFFFFD7001g|r |cFFC0C0C025s|r |cFFCD7F3230c|r", "money looted, gold silver and copper")
fire("CHAT_MSG_MONEY", "Your share of the loot is 12 Silver.")
assertEq(last("notify"), "+|cFFC0C0C012s|r", "a share of money, silver only")
fire("CHAT_MSG_MONEY", "You loot something odd.")
assertEq(last("notify"), "You loot something odd", "a money line it can't read shows as the game wrote it")
fire("CHAT_MSG_MONEY", Secret("You loot 5 Copper"))
assertEq(last("notify"), "You loot something odd", "a hidden money line is skipped")
SetGameText("GOLD_AMOUNT", "%d골드"); SetGameText("SILVER_AMOUNT", "%d실버"); SetGameText("COPPER_AMOUNT", "%d코퍼")
BT.moneyPatterns = nil
fire("CHAT_MSG_MONEY", "전리품 획득: 2골드 3실버 4코퍼")
assertEq(last("notify"), "+|cFFFFD7002g|r |cFFC0C0C03s|r |cFFCD7F324c|r", "Korean money text")
SetGameText("GOLD_AMOUNT", nil); SetGameText("SILVER_AMOUNT", nil); SetGameText("COPPER_AMOUNT", nil)
BT.moneyPatterns, BT.db.nMoney = nil, false
clear()
fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Your reputation with Stormwind has increased by 25.")
assertEq(last("notify"), "Your reputation with Stormwind has increased by 25", "reputation")
fire("CHAT_MSG_SKILL", Secret("Your skill in Swords has increased to 12."))
assertEq(last("notify"), "Your reputation with Stormwind has increased by 25", "hidden chat lines are skipped")
STATE.spellIcons["First Aid"], STATE.spellIcons[2366], BT.iconCache = 135966, 136065, nil
SetIcons(true)
fire("CHAT_MSG_SKILL", "Your skill in First Aid has increased to 12.")
assertEq(last("notify"), "|T135966:0|t Your skill in First Aid has increased to 12", "a skill up, with its spell's icon")
fire("CHAT_MSG_SKILL", "Your skill in Herbalism has increased to 3.")
assertEq(last("notify"), "|T136065:0|t Your skill in Herbalism has increased to 3", "Herbalism, by its spell's ID")
fire("CHAT_MSG_SKILL", "Your skill in Swords has increased to 12.")
assertEq(last("notify"), "Your skill in Swords has increased to 12", "a skill with no icon")
-- A German client numbers the sentence's parts ("%1$s", "%2$d"): no error, and the icon still found
local englishSkill = SKILL_RANK_UP
SetGameText("SKILL_RANK_UP", "Eure Fertigkeit '%1$s' hat sich auf %2$d erhöht.")
BT.skillPattern = nil
STATE.spellIcons["Erste Hilfe"] = 135966
fire("CHAT_MSG_SKILL", "Eure Fertigkeit 'Erste Hilfe' hat sich auf 101 erhöht.")
assertEq(last("notify"), "|T135966:0|t Eure Fertigkeit 'Erste Hilfe' hat sich auf 101 erhöht", "German: the skill up, with its icon")
SetGameText("SKILL_RANK_UP", englishSkill)
BT.skillPattern, STATE.spellIcons["Erste Hilfe"] = nil, nil
SetIcons(false)
fire("CHAT_MSG_SKILL", "Your skill in First Aid has increased to 13.")
assertEq(last("notify"), "Your skill in First Aid has increased to 13", "icons off")
STATE.spellIcons["First Aid"], STATE.spellIcons[2366], BT.iconCache = nil, nil, nil
clear()
fire("CHAT_MSG_COMBAT_FACTION_CHANGE", "Your reputation with Stormwind has increased by 25.")
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
-- Your pet's heal on you comes with "My actions" + Pet: it doesn't mean the log is giving you
-- other people's heals, so their heals still come from UNIT_COMBAT (BT-016)
do
    local PET = "|Hunit:Pet-0-1-2-3-4-000002:Fluffy Zapsu|hFluffy Zapsu|h"
    BT.fromLog = nil
    log(PET .. " |Hspell:27046:0:SPELL_HEAL|h|cffffffffMend Pet|r|h |Haction:SPELL_HEAL|h|cff7f7f7fhealed|r|h "
        .. ME .. "You|h |cffffffff40|r |cffffffffNature|r. ")
    assertEq(BT.fromLog and BT.fromLog.heal, nil, "a pet's heal on you isn't someone else's heal from the log")
    clear()
    fire("UNIT_COMBAT", "player", "HEAL", "", 55, 2)
    Advance(0.3)
    assertEq(last("incoming"), "+55", "so a priest's heal on you still shows from UNIT_COMBAT")
end
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
assert(copied:find("UNIT_COMBAT player WOUND CRITICAL 58 school", 1, true), "what happened to you, with its school")
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
log("|Ky10|k")   -- (alone with the lines, a hit needs one of yours too)
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
BT.recorded = {}
for i = 1, 5501 do BT:Record("line " .. i) end
assertEq(#BT.recorded, 5000, "only the last 5000 are kept: a whole play session")
assertEq(BT.recorded[5000]:match("line %d+"), "line 5501", "the newest ones")
BT.recorded = {}
-- /btf report: only what looks wrong, by kind, with a count and an example (Tyler's logs, 1.40.5)
do
    local list = {
        " 727.35  UNIT_COMBAT player HEAL  (hidden amount) school 1",
        " 727.35    player heal: no cast of yours with it",
        " 729.43    player heal: no cast of yours with it",
        " 737.03  SENT 6785 to target [sent a name]",
        " 737.03  SWING 0",
        " 737.03  UNIT_COMBAT nameplate1 WOUND  (hidden amount) school 1",
        " 737.03  CAST 6785 Ravage",
        " 737.03    nameplate1 (hidden amount): shown",
        " 738.45  CAST 1823 Rake",
        " 738.45  UNIT_COMBAT nameplate1 WOUND BLOCK_REDUCED (hidden amount) school 1",
        " 738.45    nameplate1 (hidden amount): cast of Rake",
        " 738.98    nameplate1 (hidden amount): shown",
        " 740.00  CAST 5215 Prowl",
        " 742.78  CAST 3029 Claw",
        " 742.78    nameplate1 (hidden amount): shown",
        " 742.78    nameplate1 (hidden amount): cast of Claw",
        " 745.10    nameplate1 (hidden amount): nothing came for it: shown",
        " 746.00    party1 120: no heal of yours with it",
    }
    local report = table.concat(BT:BuildReport(list), "\n")
    assert(report:find("== Casts of yours whose hit was shown with no name: 1 ==", 1, true), "Ravage's plain hit is found")
    assert(report:find("Ravage x1", 1, true), "by name")
    assert(not report:find("Rake x", 1, true), "Rake's hit was named: not in it")
    assert(not report:find("Prowl", 1, true), "a cast that hits nothing isn't in it")
    assert(not report:find("Claw x", 1, true), "a swing beside a named Claw isn't in it")
    assert(report:find("== Heals on you with no source: 2 ==", 1, true), "the heals with no source, counted")
    assert(report:find("== Hits that waited for a seal, shield or gear, and nothing came: 1 ==", 1, true), "the hit nothing came for")
    assert(report:find("== Hits turned away for want of a line of yours: 1 ==", 1, true), "the heal turned away")
    assert(report:find("737.03  SWING 0", 1, true), "with the lines around an example")
    assert(not report:find("746.00", 1, true) or report:find("746.00    party1", 1, true), "examples are whole lines")
    local clean = table.concat(BT:BuildReport({ " 738.45  CAST 1823 Rake", " 738.45    nameplate1 30: cast of Rake" }), "\n")
    assert(clean:find("Nothing that looks wrong.", 1, true), "a clean log says so")
    BT.recorded = list
    SlashCmdList.BATTLETEXTFOREVER("report")
    assert(BT.copyWindow:IsShown(), "/btf report opens it to copy")
    BT.copyWindow:Hide()
    BT.recorded = {}
end
BT.copyWindow:Hide()
clear()

step("moving and turning off")
SlashCmdList.BATTLETEXTFOREVER("unlock")
assertEq(BT.areas.outgoing.mover:IsShown(), true, "boxes to drag")
-- A click picks a box, and the arrow keys nudge it a pixel at a time (a player's ask, 1.43.0)
do
    local a, pos = BT.areas.outgoing, BT.db.areas.outgoing
    local x0, y0 = pos.x, pos.y
    a.mover.__scripts.OnMouseDown(a.mover, "LeftButton")
    local keys = BT.nudgeKeys
    assertEq(BT.selectedArea == a and keys.__keyboard, true, "picked: the keys are listened to")
    assertEq(a.mover.selected[1]:IsShown(), true, "with a gold edge")
    keys.__scripts.OnKeyDown(keys, "RIGHT")
    assertEq(keys.__propagate, false, "an arrow is kept from the game")
    keys.__scripts.OnKeyDown(keys, "UP") keys.__scripts.OnKeyDown(keys, "UP")
    assertEq((pos.x - x0) .. "," .. (pos.y - y0), "1,2", "one pixel a press")
    STATE.shift = true
    keys.__scripts.OnKeyDown(keys, "LEFT")
    STATE.shift = nil
    assertEq(pos.x - x0, -9, "ten with Shift")
    keys.__scripts.OnKeyDown(keys, "W")
    assertEq(keys.__propagate, true, "any other key goes on to the game")
    assertEq((pos.x - x0) .. "," .. (pos.y - y0), "-9,2", "and moves nothing")
    -- another box: that one; the same box again: let go
    BT.areas.incoming.mover.__scripts.OnMouseDown(BT.areas.incoming.mover, "LeftButton")
    assertEq(BT.selectedArea == BT.areas.incoming and not a.mover.selected[1]:IsShown(), true, "another box: picked instead")
    BT.areas.incoming.mover.__scripts.OnMouseDown(BT.areas.incoming.mover, "LeftButton")
    assertEq(tostring(BT.selectedArea) .. " " .. tostring(keys.__keyboard), "nil false", "clicked again: let go, the keys are the game's")
    -- a fight starting lets go before the keys can't be given back (also with BattleText off)
    a.mover.__scripts.OnMouseDown(a.mover, "LeftButton")
    BT.db.enabled = false
    fire("PLAYER_REGEN_DISABLED")
    BT.db.enabled = true
    assertEq(tostring(BT.selectedArea) .. " " .. tostring(keys.__keyboard), "nil false", "a fight: let go")
    COMBAT = true
    BLOCKED = {}
    a.mover.__scripts.OnMouseDown(a.mover, "LeftButton")
    keys.__scripts.OnKeyDown(keys, "RIGHT")
    assertEq(BT.selectedArea == nil and #BLOCKED, 0, "in a fight a click picks nothing, and nothing protected is touched")
    COMBAT = false
    -- locking lets go
    a.mover.__scripts.OnMouseDown(a.mover, "LeftButton")
    SlashCmdList.BATTLETEXTFOREVER("lock")
    assertEq(tostring(BT.selectedArea) .. " " .. tostring(keys.__keyboard), "nil false", "locked: let go")
    pos.x, pos.y = x0, y0
    BT:ApplyAreas()
    SlashCmdList.BATTLETEXTFOREVER("unlock")
end
SlashCmdList.BATTLETEXTFOREVER("lock")
assertEq(BT.areas.outgoing.mover:IsShown(), false, "locked again")
BT.db.areas.outgoing.x = 400
SlashCmdList.BATTLETEXTFOREVER("reset")
assertEq(BT.db.areas.outgoing.x, 305, "positions reset")
-- Lines start at the box's edge (1.43.0; a player: "Pop Left shows on the right"). Saved places
-- from before move by half a box, so the text stays where it was on screen.
do
    local old = { outAlign = "LEFT", inAlign = "RIGHT", healAlign = "LEFT", nAlign = "CENTER",
        areas = { outgoing = { x = 230, y = 20 }, incoming = { x = -230, y = 20 }, heal = { x = 0, y = -190 },
            notify = { x = 0, y = 170 } } }
    BT:MoveOldSettings(old)
    assertEq(old.areas.outgoing.x .. " " .. old.areas.incoming.x .. " " .. old.areas.heal.x .. " " .. old.areas.notify.x,
        "305 -305 110 0", "old places moved by half a box toward the side the lines start on")
    BT:MoveOldSettings(old)
    assertEq(old.areas.outgoing.x, 305, "only once")
    local fresh = {}
    BT:MoveOldSettings(fresh)
    assertEq(fresh.areas, nil, "a new player's places are the new ones")
    local plain = { areas = { outgoing = { x = 230, y = 20 } } }
    BT:MoveOldSettings(plain)
    assertEq(plain.areas.outgoing.x, 305, "an alignment never changed counts as the area's own (Left)")
    -- Left: the line starts at the box's left edge and runs right; Right: ends at its right edge
    clear()
    local half = BT:AreaWidth(BT.areas.outgoing) / 2
    BT.db.outAlign = "LEFT"
    local l = BT:Emit("outgoing", "12", { 1, 1, 1 })
    BT.db.outAlign = "RIGHT"
    local r = BT:Emit("outgoing", "34", { 1, 1, 1 })
    BT.db.outCurved = false
    Advance(0.5)
    assertEq(l.anchor .. " " .. l.__pos[1], "LEFT " .. -half, "Left: at the box's left edge")
    assertEq(r.anchor .. " " .. r.__pos[1], "RIGHT " .. half, "Right: at the box's right edge")
    -- Pop from a side edge lands inside the box
    BT.db.outStyle = "pop"
    for i = 1, 20 do
        BT.db.outAlign = i % 2 == 0 and "LEFT" or "RIGHT"
        local o = BT:Emit("outgoing", tostring(i), { 1, 1, 1 })
        assert(o.px * o.inward >= 0, "Pop goes into the box, never out of it")
    end
    BT.db.outStyle, BT.db.outAlign, BT.db.outCurved = "scroll", "LEFT", true
    clear()
end
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
assertEq(STATE.cvars.floatingCombatTextCombatDamage_v2, "0", "Forever's numbers over the mobs you hit too")
assertEq(STATE.cvars.floatingCombatTextCombatHealing_v2, "0", "and over the units you heal")
assertEq(STATE.cvars.floatingCombatTextPetMeleeDamage_v2, "0", "and your pet's")
assertEq(BT.db.inPower, false, "(Power gains off)")
assertEq(STATE.cvars.floatingCombatTextEnergyGains_v2, "0", "and with Power gains off, the game's own +mana, rage and energy")
assertEq(STATE.cvars.floatingCombatTextPeriodicEnergyGains_v2, "0", "over time too")
BT.db.inPower = true
BT:ApplySettings()
assertEq(STATE.cvars.floatingCombatTextEnergyGains_v2, "1", "but with Power gains on, the game's +mana stays (some never reach BattleText)")
BT.db.inPower = false
BT:ApplySettings()
assertEq(STATE.cvars.floatingCombatTextCombatLogPeriodicSpells_v2, nil, "a setting the game doesn't have is left alone")
-- The game's "+XP" in the world has no setting of its own (a player's report: it still showed)
assertEq(STATE.cvars.WorldTextScale_v2, "1000", "the game's +XP: its world text drawn too big to see")
assertEq(STATE.cvars.WorldTextScale, nil, "Forever's is the \"_v2\" one: the old name, which it doesn't have, is left alone")
BT.db.nXP = false
BT:ApplySettings()
assertEq(STATE.cvars.WorldTextScale_v2, "1", "but only while BattleText shows your XP itself")
assertEq(STATE.cvars.floatingCombatTextCombatDamage_v2, "0", "the rest stay hidden")
BT.db.nXP = true
BT:ApplySettings()
assertEq(STATE.cvars.WorldTextScale_v2, "1000", "XP back on: hidden again")
SlashCmdList.BATTLETEXTFOREVER("off")
assertEq(STATE.cvars.floatingCombatTextCombatDamage_v2, "1", "BattleText off: Forever's come back too")
assertEq(STATE.cvars.floatingCombatTextCombatDamage, "1", "BattleText off: the game's numbers come back")
assertEq(STATE.cvars.floatingCombatTextEnergyGains_v2, "1", "its +mana too")
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
assertEq(STATE.cvars.floatingCombatTextCombatDamage_v2, "1", "Forever's put back too")
assertEq(STATE.cvars.WorldTextScale_v2, "1", "and the world text's size")
STATE.cvars.floatingCombatTextCombatDamage_v2 = "0"   -- someone who had already turned it off by hand
BT.db.hideBlizzard = true
BT:ApplySettings()
BT.db.hideBlizzard = false
BT:ApplySettings()
assertEq(STATE.cvars.floatingCombatTextCombatDamage_v2, "0", "keeps it off when the option goes off again")
STATE.cvars.floatingCombatTextCombatDamage_v2 = "1"
STATE.cvars.enableFloatingCombatText = "0"   -- one of them was off already
BT.db.hideBlizzard = true
BT:ApplySettings()
BT.db.hideBlizzard = false
BT:ApplySettings()
assertEq(STATE.cvars.enableFloatingCombatText, "0", "one you had off stays off")
assertEq(STATE.cvars.floatingCombatTextCombatHealing, "1", "the others come back")
STATE.cvars.enableFloatingCombatText = "1"
-- After a crash the game kept the world text hidden, but the note of what it was got lost:
-- the game's default goes back, not the hidden size (BT-020)
do
    local GAME = getmetatable(_G).__index
    local cvarWas = GAME.C_CVar
    GAME.C_CVar = { GetCVarDefault = function(name) return name == "WorldTextScale_v2" and "1" or nil end }
    STATE.cvars.WorldTextScale_v2 = "1000"
    BT.db.savedCVars = nil
    BT.db.hideBlizzard = true
    BT:ApplySettings()
    BT.db.hideBlizzard = false
    BT:ApplySettings()
    assertEq(STATE.cvars.WorldTextScale_v2, "1", "the world text's size is the game's own again")
    GAME.C_CVar = cvarWas
end

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
-- The shared look: header with the logo, tabs down the left, no Blizzard templates
local win = BT.config
assertEq(win.logo.__texture, "Interface\\AddOns\\BattleTextForever\\Media\\Icon", "the logo in the header")
assertEq(win.title:GetText(), "BattleText Forever", "the name beside it")
local tabNames = {}
for _, t in ipairs(BT.CONFIG_TABS) do
    tabNames[#tabNames + 1] = t.label
    assert(win.pages[t.key] and win.tabButtons[t.key], "a tab and its page: " .. t.label)
end
assertEq(table.concat(tabNames, ", "), "General, Text, Motion, Outgoing, Incoming, Healing, Notifications, Layout, Spells, Colors", "the tabs")
assertEq(win.currentTab, "general", "it opens on General")
-- Every page's cards fit above the footer
for _, t in ipairs(BT.CONFIG_TABS) do
    local body = win.pages[t.key].body
    for _, f in ipairs(ALL_FRAMES) do
        if f.__parent == body and f.__size and f.__pos then
            local bottom = -f.__pos[2] + f.__size[2]
            assert(bottom <= ns.Theme.WINDOW.BODY_H, ("%s: a card reaches %d, below the page's %d"):format(
                t.label, bottom, ns.Theme.WINDOW.BODY_H))
        end
    end
end
win:ShowTab("healing")
assertEq(win.pages.healing:IsShown(), true, "a tab shows its page")
assertEq(win.pages.general:IsShown(), false, "and only its page")
win:ShowTab("general")
local function inWindow(f)
    while f do if f == win then return true end f = f.__parent end
    return false
end
for _, f in ipairs(ALL_FRAMES) do
    if inWindow(f) then assertEq(f.__template, nil, "no Blizzard template in the window: " .. tostring(f.__kind)) end
    assert(not (inWindow(f) and f.__kind == "CheckButton"), "switches, not checkboxes")
end
-- Click every switch twice: nothing errors, and the settings end where they began
local before = {}
for k, v in pairs(BT.db) do before[k] = v end
local switches = 0
for _, f in ipairs(ALL_FRAMES) do
    if f.isSwitch and f.key and inWindow(f) then
        switches = switches + 1
        assertEq(f:IsOn(), f.key == "locked" and not BT.db.locked or (f.key ~= "locked" and BT.db[f.key] == true),
            "a switch shows its setting: " .. f.key)
        local changed = false
        f.__scripts.OnClick(f)
        for k, v in pairs(before) do
            if type(v) == "boolean" and BT.db[k] ~= v then changed = true end
        end
        if f.disabled then
            assert(not changed, "a greyed-out switch can't be clicked: " .. f.key)
        else
            assert(changed, "a switch that changes no setting: " .. f.key)
            f.__scripts.OnClick(f)
        end
    end
end
assertEq(switches, 63, "the switches are there")
-- A switch's label is part of it: its click area stretches over the text
for _, f in ipairs(ALL_FRAMES) do
    if f.isSwitch and f.key and inWindow(f) then
        local reach = -f.__hitRect[2]
        assert(reach >= 8 + #f.label:GetText() * 7, "the label can be clicked: " .. f.key)
    end
end
-- Controls that do nothing with the settings as they are, are greyed out
local function control(key)
    for _, f in ipairs(ALL_FRAMES) do if f.key == key and inWindow(f) then return f end end
end
local savedLook = { merge = BT.db.merge, outStyle = BT.db.outStyle, outDamage = BT.db.outDamage,
    routeOutHeals = BT.db.routeOutHeals, routeInHeals = BT.db.routeInHeals }
BT.db.merge, BT.db.outStyle, BT.db.outDamage = true, "scroll", true
BT.db.routeOutHeals, BT.db.routeInHeals = "heal", "heal"
BT:RefreshConfig()
assertEq(control("tickMerge").disabled, false, "the tick window, with Add up rapid hits on")
assertEq(control("outScrollUp").disabled, false, "Scroll upward, with Scroll movement")
assertEq(control("healSize").disabled, false, "the Healing area's look, with its own area")
BT.db.merge, BT.db.outStyle, BT.db.outDamage = false, "pop", false
BT.db.routeOutHeals, BT.db.routeInHeals = "outgoing", "incoming"   -- (nothing left in the Healing area)
BT:RefreshConfig()
assertEq(control("tickMerge").disabled, true, "greyed out with Add up rapid hits off")
assertEq(control("tickMerge").__alpha, 0.4, "and looks it")
assertEq(control("outScrollUp").disabled and control("outCurved").disabled, true, "Scroll upward and Curved, with Pop")
assertEq(control("healSize").disabled and control("healStyle").disabled, true, "the Healing area's look, without it")
assertEq(control("minDamage").disabled and control("outSeals").disabled, true, "Hide hits below and seals, with Damage off")
assertEq(control("inScrollUp").disabled, false, "each area on its own")
for k, v in pairs(savedLook) do BT.db[k] = v end
BT:RefreshConfig()
-- 0 reads Off where 0 turns a setting off
BT.db.minDamage = 0
BT:RefreshConfig()
assertEq(control("minDamage").valueText:GetText(), "Off", "Hide hits below at 0")
BT.db.minDamage = 25
BT:RefreshConfig()
assertEq(control("minDamage").valueText:GetText(), "25", "and its number otherwise")
BT.db.minDamage = 0
assertEq(control("fontSize").valueText:GetText(), "20", "a size never reads Off")
-- Hiding the game's numbers in a fight waits for the fight to end, and says so
COMBAT = true
control("hideBlizzard").__scripts.OnClick(control("hideBlizzard"))
assert(LOG[#LOG]:find("when this fight ends", 1, true), "said in chat")
control("hideBlizzard").__scripts.OnClick(control("hideBlizzard"))
COMBAT = false
-- Show sample text, Reset positions and Reset all are in the footer beside Close (a player's ask,
-- 1.43.0: test the look from any tab), and Close looks unlike them
for _, name in ipairs({ "sampleButton", "resetButton", "resetAllButton" }) do
    assertEq(win[name].__parent, win.footer, name .. ": in the footer")
end
assertEq(win.resetAllButton.__rel, win.closeButton, "beside Close")
assertEq(win.closeButton.look, "close", "Close looks different")
win.sampleButton.__scripts.OnClick(win.sampleButton)
Advance(3)
assert(#BT.areas.outgoing.active + #BT.areas.notify.active > 0, "Show sample text works from any tab")
clear()
-- Reset positions asks first
BT.db.areas.notify.x = 77
win.resetButton.__scripts.OnClick(win.resetButton)
assertEq(BT.db.areas.notify.x, 77, "Reset positions asks first")
BT.confirmWindow.yes.__scripts.OnClick(BT.confirmWindow.yes)
assertEq(BT.db.areas.notify.x, 0, "then moves them back")
for k, v in pairs(before) do
    if type(v) ~= "table" then assertEq(BT.db[k], v, "setting unchanged: " .. k) end
end
-- Reset all: asks first, then every setting is as it started, and the game's numbers'
-- originals are kept (BT-028)
do
    local function deep(t) local c = {} for k, v in pairs(t) do c[k] = type(v) == "table" and deep(v) or v end return c end
    local saved, cvarsSaved = deep(BT.db), deep(STATE.cvars)
    BT.db.fontSize, BT.db.colors.heal = 33, { 0, 0, 1 }
    BT.db.spellRules, BT.rulesByName = { { name = "Claw", hide = true } }, nil
    BT.db.learnedBuffs = { ["Power Word: Fortitude"] = true }
    BT.db.hideBlizzard = true
    BT:ApplySettings()
    assertEq(STATE.cvars.floatingCombatTextCombatDamage, "0", "(the game's numbers hidden)")
    win.resetAllButton.__scripts.OnClick(win.resetAllButton)
    assertEq(BT.db.fontSize, 33, "Reset all asks first")
    assert(BT.confirmWindow.text:GetText():find("every setting", 1, true), "saying what it resets")
    BT.confirmWindow.yes.__scripts.OnClick(BT.confirmWindow.yes)
    assertEq(BT.db.fontSize, BT.DEFAULTS.fontSize, "then the text size is as it started")
    assertEq(BT.db.colors.heal, nil, "the colors")
    assertEq(#BT.db.spellRules .. tostring(BT:SpellRule("Claw")), "0nil", "the Spells list")
    assertEq(BT.db.learnedBuffs, nil, "and what was learned")
    local hidden = BT.DEFAULTS.hideBlizzard and BT.DEFAULTS.enabled
    assertEq(STATE.cvars.floatingCombatTextCombatDamage, hidden and "0" or "1", "the game's numbers follow the reset")
    if hidden then
        assertEq(BT.db.savedCVars.floatingCombatTextCombatDamage, "1", "with what they were before BattleText kept")
    end
    LOG = {}
    SlashCmdList.BATTLETEXTFOREVER("resetall")
    assertEq(BT.confirmWindow:IsShown(), true, "/btf resetall asks too")
    BT.confirmWindow.no.__scripts.OnClick(BT.confirmWindow.no)
    -- (back to the settings the rest of the tests use)
    BT:ApplyBlizzardText(true)
    for k in pairs(BT.db) do BT.db[k] = nil end
    for k, v in pairs(saved) do BT.db[k] = v end
    for k, v in pairs(cvarsSaved) do STATE.cvars[k] = v end
    BT.rulesByName = nil
    BT:ApplySettings()
    BT:RefreshConfig()
end
-- Every slider writes the setting it's labelled with
local sliders = 0
for _, f in ipairs(ALL_FRAMES) do
    if f.__kind == "Slider" and f.key and f.__scripts.OnValueChanged then
        sliders = sliders + 1
        local snapshot = {}
        for k, v in pairs(BT.db) do snapshot[k] = v end
        local target = BT.db[f.key] == f.__max and f.__min or f.__max
        f.__scripts.OnValueChanged(f, target)
        local moved = {}
        for k, v in pairs(snapshot) do
            if type(v) == "number" and BT.db[k] ~= v then moved[#moved + 1] = k end
        end
        assertEq(#moved, 1, "a slider changes exactly one setting")
        do
            assertEq(BT.db[moved[1]], target, "slider set " .. moved[1])
            assert(f.label and f.label:lower():find(({ fontSize = "text size", critScale = "crit size",
                scrollTime = "time on screen", height = "area height", minDamage = "hide hits below", minHeal = "hide heals below",
                outSize = "size", inSize = "size", healSize = "size", nSize = "size",
                outAlpha = "opacity", inAlpha = "opacity", healAlpha = "opacity", nAlpha = "opacity",
                tickMerge = "ticks and area hits", minCrit = "smallest crit", lowManaAt = "low mana at", plateX = "left and right", plateY = "up and down" })[moved[1]], 1, true),
                "slider label matches its setting: " .. tostring(f.label) .. " -> " .. moved[1])
            f.__scripts.OnValueChanged(f, snapshot[moved[1]])
        end
    end
end
assertEq(sliders, 19, "nineteen sliders: eleven, and each area's size and opacity")
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
assertEq(bundled, 18, "eighteen bundled fonts")
assertEq(#BT.FONTS, 23, "twenty-three fonts to choose from")
for _, name in ipairs({ "Cinzel Decorative", "Metamorphous", "New Rocker" }) do
    local found
    for _, font in ipairs(BT.FONTS) do if font.name == name then found = font end end
    assert(found, "a font in the style of Diablo: " .. name)
end
local names = {}
for _, font in ipairs(BT.FONTS) do
    assert(not names[font.name], "font listed twice: " .. font.name)
    names[font.name] = true
end
local pkgmeta = read_file(ADDON_DIR .. "/.pkgmeta")
assert(not pkgmeta:find("Fonts", 1, true), "the Fonts folder isn't left out of the download")

-- The font dropdown, in the shared look: it shows the font in use and opens a menu of them all
local dropdown = BT.config.fontDropdown
-- Its list is a frame of our own: the game's menus are shared with its unit
-- menus, and opening one from an addon got the raid markers blocked (issue #9)
local List = ns.Theme.List
local function openMenu(d)
    if List():IsShown() then List():Hide() end
    d.__scripts.OnClick(d)
    assertEq(List():IsShown(), true, "the dropdown's list opens")
    assertEq(List().owner, d, "under that dropdown")
    assertClean("opening a dropdown")
    return List().items
end
assertEq(dropdown:GetText(), "Default", "it shows the font in use")
local menu = openMenu(dropdown)
assertEq(#menu, 23, "every font is in the list")
assertEq(List().visible, 12, "a long list shows twelve rows and scrolls")
assertEq(List().rows[1].label:GetText(), BT.FONTS[1].name, "the first row shows the first font")
List().__scripts.OnMouseWheel(List(), -1)
assertEq(List().rows[1].label:GetText(), BT.FONTS[4].name, "the mouse wheel scrolls it")
for _ = 1, 10 do List().__scripts.OnMouseWheel(List(), -1) end
assertEq(List().rows[12].label:GetText(), BT.FONTS[23].name, "to the last font and no further")
assertEq(List().rows[12]:IsShown(), true, "every row in use")
dropdown.__scripts.OnClick(dropdown)
assertEq(List():IsShown(), false, "a second click on the dropdown closes it")
openMenu(dropdown)
List().catcher.__scripts.OnClick(List().catcher)
assertEq(List():IsShown(), false, "so does a click anywhere else")
openMenu(dropdown)
BT.config:Hide()
List().__scripts.OnUpdate(List())
assertEq(List():IsShown(), false, "and closing the options window")
BT.config:Show()
openMenu(dropdown)
local row = List().rows[2]
row.__scripts.OnClick(row)
assertEq(BT.db.font, BT.FONTS[2].name, "clicking a row picks it")
assertEq(List():IsShown(), false, "and closes the list")
assertClean("picking from a dropdown")
BT.db.font = "Default"
BT:RefreshConfig()
menu = openMenu(dropdown)
for i, row in ipairs(menu) do
    assertEq(row.text, BT.FONTS[i].name, "in order")
    assertEq(row.isSelected(), i == 1, "only the font in use is ticked")
end
clear()
menu[13].pick()
assertEq(BT.db.font, "Lato", "picking one sets the font")
assertEq(dropdown:GetText(), "Lato", "the dropdown says so")
assertEq(BT:FontPath(), "Interface\\AddOns\\BattleTextForever\\Fonts\\Lato-Bold.ttf", "its file")
assertEq(last("notify"), "Lato", "and shows a line in it straight away")
assertEq(BT.areas.notify.active[1].text.__font[1], BT:FontPath(), "in that font")
assertEq(menu[13].isSelected(), true, "it's the ticked one now")
assertEq(menu[1].isSelected(), false, "and the old one isn't")
SlashCmdList.BATTLETEXTFOREVER("off")
menu[2].pick()
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

-- The outlines: normal lines and crits each have their own
assertEq(BT.DEFAULTS.outline, "OUTLINE", "a thin outline by default")
assertEq(BT.DEFAULTS.critOutline, "OUTLINE", "for crits too")
for _, k in ipairs({ "outScrollUp", "inScrollUp", "healScrollUp", "nScrollUp" }) do
    assertEq(BT.DEFAULTS[k], false, "lines scroll down by default: " .. k)
end
assertEq(BT.DEFAULTS.outCurved and BT.DEFAULTS.inCurved, true, "and the side areas curve")
-- The old one-for-all settings become each area's own
local old = { scrollUp = true, curved = false, inCurved = true }
BT:MoveOldSettings(old)
assertEq(old.outScrollUp and old.inScrollUp and old.healScrollUp and old.nScrollUp, true, "scroll upward, in every area")
assertEq(old.outCurved, false, "curves off")
assertEq(old.inCurved, true, "never over a setting already made")
assertEq(old.scrollUp, nil, "the old settings go")
assertEq(old.curved, nil, "both")
local outlineDropdown, critDropdown = BT.config.outlineDropdown, BT.config.critOutlineDropdown
assertEq(outlineDropdown:GetText(), "Thin", "it shows the outline in use")
local outlineMenu, critMenu = openMenu(outlineDropdown), openMenu(critDropdown)
assertEq(#outlineMenu, 4, "none, thin, thick, shadow")
assertEq(outlineMenu[1].text .. outlineMenu[2].text .. outlineMenu[3].text .. outlineMenu[4].text,
    "NoneThinThickShadow", "named for people")
clear()
critMenu[3].pick()
assertEq(BT.db.critOutline, "THICKOUTLINE", "picking Thick sets the crits' outline")
assertEq(critDropdown:GetText(), "Thick", "the dropdown says so")
assertEq(BT.db.outline, "OUTLINE", "and leaves the normal one")
assertEq(last("notify"), "Crit", "a sample crit shows straight away")
assertEq(BT.areas.notify.active[1].text.__font[3], "THICKOUTLINE", "with the thick outline")
assertEq(critMenu[3].isSelected(), true, "it's the ticked one now")
clear()
outlineMenu[1].pick()
assertEq(BT.db.outline, "", "picking None takes the outline away")
assertEq(last("notify"), "Normal", "a sample line shows straight away")
assertEq(BT.areas.notify.active[1].text.__font[3], "", "with no outline")
clear()
BT:Emit("outgoing", "12", { 1, 1, 1 })
BT:Emit("outgoing", "34", { 1, 1, 1 }, { crit = true })
local fonts = {}
for _, o in ipairs(BT.areas.outgoing.active) do fonts[o.text:GetText()] = o.text.__font[3] end
assertEq(fonts["12"], "", "a normal line uses the normal outline")
assertEq(fonts["34"], "THICKOUTLINE", "a crit uses the crits' outline")
BT.db.outline = "SOMETHING ODD"
assertEq(BT:OutlineFlags(false), "OUTLINE", "an unknown outline falls back to thin")
-- The sound lists on the Notifications tab
local critSounds = openMenu(BT.config.critSoundDropdown)
assertEq(#critSounds, #BT.SOUNDS, "every sound in the list")
assertEq(BT.config.critSoundDropdown:GetText(), "Crafting crit", "the crit sound to start with")
assertEq(BT.config.killSoundDropdown:GetText(), "Boss defeated", "and the kill sound")
STATE.sounds = {}
for _, item in ipairs(critSounds) do if item.text == "Cheers" then item.pick() end end
assertEq(BT.db.critSound, "UI_MISSION_SUCCESS_CHEERS", "picking one sets it")
assertEq(BT.config.critSoundDropdown:GetText(), "Cheers", "the list shows it")
BT.db.critSound = BT.DEFAULTS.critSound
clear()
outlineMenu[4].pick()
assertEq(BT.db.outline, "SHADOW", "picking Shadow")
local shadowed = BT.areas.notify.active[1].text
assertEq(shadowed.__font[3], "", "a shadow instead of an outline")
assertEq(shadowed.__shadow[1] > 0 and shadowed.__shadow[2] < 0, true, "down and to the right")
clear()
outlineMenu[2].pick()
assertEq(BT.areas.notify.active[1].text.__shadow[1], 0, "an outlined line has no shadow")
BT.db.outline, BT.db.critOutline = "OUTLINE", "OUTLINE"
BT:RefreshConfig()
clear()

-- Closing the window locks the text areas again
local moveSwitch
for _, f in ipairs(ALL_FRAMES) do
    if f.isSwitch and f.key == "locked" and inWindow(f) then moveSwitch = f end
end
assert(moveSwitch, "the Move the text areas switch")
assertEq(moveSwitch.label:GetText(), "Move the text areas", "named for what it does")
moveSwitch.__scripts.OnClick(moveSwitch)
assertEq(BT.db.locked, false, "on: unlocked")
assertEq(BT.areas.outgoing.mover:IsShown(), true, "with boxes to drag")
assertEq(BT.areas.outgoing.mover.header.text:GetText(), "Outgoing", "each with the header bar and its name")
assertEq(BT.areas.outgoing.mover.header.logo.__texture, BT.ICON, "and the logo")
BT:OpenConfig()
assertEq(BT.config:IsShown(), false, "closes")
assertEq(BT.db.locked, true, "closing the window locks the text areas")
assertEq(BT.areas.outgoing.mover:IsShown(), false, "the boxes go")
BT:OpenConfig()
assertEq(moveSwitch:IsOn(), false, "and the switch is off when it opens again")
moveSwitch.__scripts.OnClick(moveSwitch)
BT.config:Hide()   -- Escape, or the X
assertEq(BT.db.locked, true, "however it's closed")
SlashCmdList.BATTLETEXTFOREVER("unlock")
assertEq(BT.db.locked, false, "/btf unlock still works with the window closed")
SlashCmdList.BATTLETEXTFOREVER("lock")
clear()

step("area damage on mobs that aren't after you")
STATE.group = false
STATE.unit.mobA = { enemy = true, guid = "Creature-0-1-2-3-100-00000A", target = "me" }
STATE.unit.mobB = { enemy = true, guid = "Creature-0-1-2-3-100-00000B", target = "friend" }
STATE.unit.mobC = { enemy = true, guid = "Creature-0-1-2-3-100-00000C" }
STATE.who.target, STATE.who.nameplate1, STATE.who.nameplate2, STATE.who.nameplate3 = "mobA", "mobA", "mobB", "mobC"
freshFight()
-- Fire Nova: every mob around you is hit in the same instant, with the same school
fire("UNIT_COMBAT", "target", "WOUND", "", 40, 4)
fire("UNIT_COMBAT", "nameplate1", "WOUND", "", 40, 4)   -- (your target again, under its nameplate)
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 41, 4)   -- after someone else
fire("UNIT_COMBAT", "nameplate3", "WOUND", "", 42, 4)   -- not after anyone yet
assertEq(table.concat(lines("outgoing"), " / "), "40 / 41 / 42", "every mob your area spell hit")
clear()
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 41, 4)
assertEq(#lines("outgoing"), 0, "a hit on someone else's mob, on its own, isn't yours")
Advance(1)
fire("UNIT_COMBAT", "target", "WOUND", "", 40, 1)
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 41, 4)
assertEq(table.concat(lines("outgoing"), " / "), "40", "nor one of another school in the same instant")
clear()
-- With a cast in the frame, they're all named after it, and add up
STATE.spellNames[1449] = "Arcane Explosion"
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-ae", 1449)
fire("UNIT_COMBAT", "target", "WOUND", "", 30, 64)
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 31, 64)
fire("UNIT_COMBAT", "nameplate3", "WOUND", "", 32, 64)
assertEq(last("outgoing"), "Arcane Explosion 93 |cffb0b0b0(x3)|r", "named after the spell, added up")
clear()
-- Hidden amounts (as players see them now) can't be added up, but they still share one line
-- (a player's log: one cast, two mobs, each also seen as the target and the soft target)
STATE.who.softenemy = "mobA"
local function newestShown() local a = BT.areas.outgoing.active return a[#a].text.__shown end
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-ae2", 1449)
fire("UNIT_COMBAT", "nameplate3", "WOUND", "", Secret(30), 64)
fire("UNIT_COMBAT", "nameplate1", "WOUND", "", Secret(31), 64)
fire("UNIT_COMBAT", "target", "WOUND", "", Secret(31), 64)
fire("UNIT_COMBAT", "softenemy", "WOUND", "", Secret(31), 64)
assertEq(#lines("outgoing"), 1, "hidden hits of one area cast share one line")
assertEq(newestShown(), "Arcane Explosion <secret> |cffb0b0b0(2 hits)|r", "the last hit, and how many: not a total")
-- The next cast, a moment later, adds to it too (the same as read amounts)
Advance(0.3)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-ae3", 1449)
fire("UNIT_COMBAT", "nameplate3", "WOUND", "", Secret(30), 64)
fire("UNIT_COMBAT", "nameplate1", "WOUND", "", Secret(31), 64)
assertEq(#lines("outgoing"), 1, "a quick second cast adds to the line")
assertEq(newestShown(), "Arcane Explosion <secret> |cffb0b0b0(4 hits)|r", "four hits now")
-- A read amount never joins a hidden line
Advance(0.1)
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-ae4", 1449)
fire("UNIT_COMBAT", "target", "WOUND", "", 30, 64)
assertEq(#lines("outgoing"), 2, "a read hit starts its own line")
clear()
BT.db.merge = false
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-ae5", 1449)
fire("UNIT_COMBAT", "nameplate3", "WOUND", "", Secret(30), 64)
fire("UNIT_COMBAT", "nameplate1", "WOUND", "", Secret(31), 64)
assertEq(#lines("outgoing"), 2, "with \"Add up rapid hits\" off, each hit has its own line")
BT.db.merge = true
STATE.who.softenemy = nil
clear()
-- In a group, each still needs a line of yours
STATE.group, STATE.who.party1 = true, "friend"
BT.hiddenSeen, BT.hiddenAt, BT.credits = true, GetTime(), {}
BT:NoteHiddenLine(GetTime())
BT:NoteHiddenLine(GetTime())
fire("UNIT_COMBAT", "target", "WOUND", "", 40, 4)
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 41, 4)
fire("UNIT_COMBAT", "nameplate3", "WOUND", "", 42, 4)
assertEq(table.concat(lines("outgoing"), " / "), "40 / 41", "two lines: two hits")
STATE.group, STATE.who.party1 = false, nil
STATE.who.nameplate1, STATE.who.nameplate2, STATE.who.nameplate3 = nil, nil, nil
freshFight()

step("the killing blow on a mob that wasn't your target")
STATE.group = false
STATE.unit.mobA = { enemy = true, guid = "Creature-0-1-2-3-100-00000A", target = "me" }
STATE.unit.mobB = { enemy = true, guid = "Creature-0-1-2-3-100-00000B", target = "me" }
STATE.unit.mobC = { enemy = true, guid = "Creature-0-1-2-3-100-00000C", dead = true }
STATE.who.target, STATE.who.nameplate1, STATE.who.nameplate2, STATE.who.nameplate3 = "mobA", "mobA", "mobB", "mobC"
freshFight()
BT.fought = nil
-- You hit the second mob (it's after you; your target is the first one)
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 30, 1)
assertEq(last("outgoing"), "30", "a hit on a mob that's after you")
Advance(1.5)
-- It dies from your next hit: by the time the hit arrives it has let go of you
STATE.unit.mobB.target, STATE.unit.mobB.dead = nil, true
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 31, 1)
assertEq(last("outgoing"), "31", "the killing blow still shows")
Advance(1)
-- A dead mob you never hit isn't yours
fire("UNIT_COMBAT", "nameplate3", "WOUND", "", 32, 1)
assertEq(last("outgoing"), "31", "someone else's kill isn't yours")
-- Nor one you last hit long ago
clear()
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 33, 1)
assertEq(#lines("outgoing"), 0, "nor a hit long after yours")
-- A living mob you just hit that has turned to someone else isn't yours either
STATE.unit.mobB.dead, STATE.unit.mobB.target = nil, "me"
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 20, 1)
assertEq(last("outgoing"), "20", "your hit")
Advance(1)
STATE.unit.mobB.target = "friend"
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 34, 1)
assertEq(last("outgoing"), "20", "a mob that turned to someone else")
STATE.who.nameplate1, STATE.who.nameplate2, STATE.who.nameplate3 = nil, nil, nil
STATE.unit.mobB, STATE.unit.mobC = nil, nil
freshFight()

step("a spell on its way makes its mob yours: the opener of a pull, and the overkill")
STATE.spellNames[1326079] = "Arcane Wrath"
STATE.group = false
STATE.unit.mobB = { enemy = true, guid = "Creature-0-1-2-3-100-00000B" }   -- not after you yet
STATE.unit.mobC = { enemy = true, guid = "Creature-0-1-2-3-100-00000C" }
STATE.who.target, STATE.who.nameplate1, STATE.who.nameplate2, STATE.who.nameplate3 = "mobB", "mobA", "mobB", "mobC"
freshFight()
BT.fought, BT.flying = nil, nil
SetIcons(false)
-- Cast to open the pull, then on to the next mob before it lands: the mob isn't after you
-- yet and isn't your target
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-aw1", 1326079)
STATE.who.target = "mobA"
Advance(0.9)
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 900, 64)
assertEq(last("outgoing"), "Arcane Wrath 900", "the opener lands on a mob that isn't after you yet")
-- It kills the mob: dead, no target, and not yours the moment it lands
clear()
STATE.who.target = "mobC"
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-aw2", 1326079)
STATE.unit.mobC.dead = true
STATE.who.target = nil
Advance(1.0)
fire("UNIT_COMBAT", "nameplate3", "WOUND", "", 1500, 64)
assertEq(last("outgoing"), "Arcane Wrath 1,500", "the overkill on a mob it killed still shows")
-- Only a hit of its school, while it can still be on its way
clear()
STATE.unit.mobC.dead = nil
STATE.who.target = "mobC"
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-aw3", 1326079)
STATE.who.target = nil
Advance(0.5)
fire("UNIT_COMBAT", "nameplate3", "WOUND", "", 40, 4)
assertEq(#lines("outgoing"), 0, "a fire hit on that mob isn't yours")
Advance(2.2)
fire("UNIT_COMBAT", "nameplate3", "WOUND", "", 41, 64)
assertEq(#lines("outgoing"), 0, "nor an arcane hit long after the cast")
-- And when it needs no time to land, the hit in the cast's own frame is it
STATE.who.target = "mobA"
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-aw4", 1326079)
fire("UNIT_COMBAT", "target", "WOUND", "", 950, 64)
assertEq(last("outgoing"), "Arcane Wrath 950", "in its cast's frame")
-- Frostfire Bolt too (CurseForge, xnmd: the opener and the overkill didn't show)
clear()
STATE.unit.mobC.dead = nil
STATE.who.target = "mobC"
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-ffb1", 1237313)
STATE.who.target = "mobA"
Advance(1.1)
fire("UNIT_COMBAT", "nameplate3", "WOUND", "", 310, 20)
assertEq(last("outgoing"), "Frostfire Bolt 310", "a Frostfire Bolt opening the pull")
STATE.who.target = "mobC"
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-ffb2", 1237313)
STATE.unit.mobC.dead = true
STATE.who.target = nil
Advance(1.1)
fire("UNIT_COMBAT", "nameplate3", "WOUND", "", 320, 20)
assertEq(last("outgoing"), "Frostfire Bolt 320", "and its overkill")
STATE.unit.mobC.dead = nil
STATE.who.nameplate1, STATE.who.nameplate2, STATE.who.nameplate3 = nil, nil, nil
STATE.unit.mobB, STATE.unit.mobC = nil, nil
BT.flying = nil
freshFight()

step("a paladin's seals")
STATE.spellNames[21084], STATE.spellNames[20375], STATE.spellNames[20271] = "Seal of Righteousness", "Seal of Command", "Judgement"
STATE.spellIcons[21084] = 132325
STATE.group, STATE.who.target = false, "mobA"
STATE.buffs = {}
fire("UNIT_AURA", "player")
BT.seal = nil
freshFight()
SetIcons(false)
local function cast(id) fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-seal", id) end
cast(21084)
assertEq(last("notify"), "+Seal of Righteousness", "putting a seal on says so")
assert(isColor(BT.areas.notify.active[#BT.areas.notify.active], BT.TEXT_COLORS.seal), "in the seals' color")
Advance(1)
-- Its damage, landing with your swing on the same mob, is named after it
wound(30, 1)
wound(12, 2)
assertEq(table.concat(lines("outgoing"), " / "), "30 / Seal of Righteousness 12", "the seal's hit beside your swing")
Advance(1)
wound(13, 2)
assertEq(last("outgoing"), "Seal of Righteousness 12", "a Holy hit alone waits a moment for a swing")
Advance(1.3)
assertEq(last("outgoing"), "13", "a Holy hit without a swing isn't taken for the seal")
-- The swing's hit comes up to a second after its line; the seal's comes with its own line,
-- so it can be ahead of the swing (a player's report: plain yellow numbers on each swing)
clear()
cast(21084)   -- (renewed: it's been on a while)
Advance(1)
wound(11, 2)
assertEq(#lines("outgoing"), 0, "the seal's hit ahead of the swing waits for it")
Advance(0.6)
wound(31, 1)
assertEq(table.concat(lines("outgoing"), " / "), "31 / Seal of Righteousness 11", "and is named when the swing lands")
Advance(2)
assertEq(#lines("outgoing"), 2, "shown once")
clear()
wound(32, 1)
Advance(0.3)
wound(10, 2)
assertEq(table.concat(lines("outgoing"), " / "), "32 / Seal of Righteousness 10", "a seal's hit just after the swing")
clear()
Advance(1)
wound(9, 2)
BT.struck = {}
fire("UNIT_COMBAT", "nameplate4", "WOUND", "", 30, 1)
Advance(1.3)
assertEq(lines("outgoing")[1], "9", "a swing on another mob doesn't name it")
cast(21084)   -- (renewed again)
clear()
Advance(1)
BT.db.outSeals = false
Advance(1)
wound(30, 1)
wound(14, 2)
assertEq(last("outgoing"), "14", "Seal damage turned off: a plain number")
BT.db.outSeals = true
-- On Forever Judgement leaves the seal on (issue #7: "-Seal" showed at Judgement, then
-- "+Seal" at the next reading of your buffs, though you hadn't cast it)
clear()
cast(20271)
assertEq(last("notify"), nil, "Judgement doesn't take the seal off")
assertEq(BT.seal and BT.seal.name, "Seal of Righteousness", "the seal is still on")
Advance(1)
wound(30, 1)
wound(12, 2)
assertEq(last("outgoing"), "Seal of Righteousness 12", "and its hits are still named after it")
STATE.buffs = { { name = "Seal of Righteousness", spellId = 21084 } }
fire("UNIT_AURA", "player")
assertEq(last("notify"), nil, "a reading of your buffs after Judgement: no new +Seal")
STATE.buffs = {}
fire("UNIT_AURA", "player")
assertEq(last("notify"), "-Seal of Righteousness", "it's gone when your buffs say so")
Advance(1)
wound(30, 1)
wound(12, 2)
assertEq(last("outgoing"), "12", "and with no seal on, nothing is named after it")
clear()
-- A new seal replaces the old one; one that runs out goes after its 30 seconds
cast(21084)
Advance(1)
cast(20375)
local notices = lines("notify")
assertEq(table.concat(notices, " / "), "+Seal of Righteousness / -Seal of Righteousness / +Seal of Command", "one seal for another")
clear()                -- (8 seconds)
Advance(21.5)
assertEq(BT.seal and BT.seal.name, "Seal of Command", "still on just before its 30 seconds")
Advance(1)
assertEq(last("notify"), "-Seal of Command", "the seal runs out after 30 seconds")
clear()
cast(21084)
Advance(20)
cast(21084)
assertEq(last("notify"), nil, "put on again: no line, it was only renewed")
Advance(15)
assertEq(BT.seal and BT.seal.name, "Seal of Righteousness", "it lasts 30 seconds from then")
Advance(15.5)
assertEq(last("notify"), "-Seal of Righteousness", "and runs out 30 seconds after that")
clear()
-- Out of a fight, your buffs say so directly
STATE.buffs = { { name = "Seal of Righteousness", spellId = 21084 } }
fire("UNIT_AURA", "player")
assertEq(last("notify"), "+Seal of Righteousness", "a seal seen among your buffs")
fire("UNIT_AURA", "player")
assertEq(#lines("notify"), 1, "only once")
STATE.buffs = {}
fire("UNIT_AURA", "player")
assertEq(last("notify"), "-Seal of Righteousness", "and gone when it's gone")
clear()
-- In a fight the buffs are hidden: nothing changes until a cast or the time says so
cast(21084)
STATE.buffsHidden = true
fire("UNIT_AURA", "player")
assertEq(#lines("notify"), 1, "hidden buffs don't take the seal off")
STATE.buffsHidden = false
-- Turned off
clear()
BT.db.nSeals = false
cast(20375)
assertEq(#lines("notify"), 0, "no lines with Seals turned off")
assertEq(BT.seal and BT.seal.name, "Seal of Command", "though the seal is still followed")
BT:LoseSeal(true)
BT.db.nSeals = true
SetIcons(true)
cast(21084)
assertEq(last("notify"), "|T132325:0|t +Seal of Righteousness", "with its icon when icons are on")
BT:LoseSeal(true)
-- How long a seal lasts is taken from your buffs: when it runs out, and how long it
-- lasts for the next time it's cast in a fight (Forever's may not be Classic's 30s)
clear()
STATE.buffs = { { name = "Seal of Command", spellId = 20375, duration = 45, expirationTime = GetTime() + 40 } }
fire("UNIT_AURA", "player")
assertEq(last("notify"), "+Seal of Command", "a seal seen among your buffs")
Advance(35)
assertEq(BT.seal and BT.seal.name, "Seal of Command", "still on: the game says it runs out in 40 seconds")
STATE.buffsHidden = true
Advance(5.5)
assertEq(last("notify"), "-Seal of Command", "and it runs out then")
clear()
cast(20375)
Advance(44)
assertEq(BT.seal and BT.seal.name, "Seal of Command", "cast in a fight: it lasts what the game said, 45 seconds")
Advance(1.5)
assertEq(last("notify"), "-Seal of Command", "then runs out")
STATE.buffsHidden = false
STATE.buffs = {}
BT.db.sealTimes = nil
-- Forever's Seal of Fury (1.35.0, CurseForge): Holy damage with each swing, named like the others
STATE.spellNames[1311649] = "Seal of Fury"
BT.periodic = nil
clear()
cast(1311649)
assertEq(last("notify"), "+Seal of Fury", "putting Seal of Fury on says so")
Advance(1)
wound(40, 1)
wound(6, 2)
assertEq(table.concat(lines("outgoing"), " / "), "40 / Seal of Fury 6", "its Holy hit beside your swing is named")
Advance(31)
SetIcons(false)
-- A German game (GitHub #36): seals show by the game's name for them, not the English one
BT.seals = nil
STATE.locale, STATE.spellNames[20375] = "deDE", "Siegel des Befehls"
clear()
cast(20375)
assertEq(last("notify"), "+Siegel des Befehls", "German: putting a seal on says its German name")
Advance(1)
wound(40, 1)
wound(9, 2)
assertEq(table.concat(lines("outgoing"), " / "), "40 / Siegel des Befehls 9", "and its hit is named in German")
BT:LoseSeal(true)
clear()
STATE.buffs = { { name = "Siegel des Befehls", spellId = 20375, duration = 30, expirationTime = GetTime() + 20 } }
fire("UNIT_AURA", "player")
assertEq(last("notify"), "+Siegel des Befehls", "a German seal seen among your buffs")
STATE.buffs = {}
BT:LoseSeal(true)
BT.db.sealTimes = nil
STATE.locale, STATE.spellNames[20375] = "enUS", "Seal of Command"
BT.seals = nil
clear()
cast(20375)
assertEq(last("notify"), "+Seal of Command", "English: still the English name")
BT:LoseSeal(true)
STATE.who.target = nil
clear()

step("spells that fly to their target")
STATE.unit.mobA = { enemy = true, guid = "Creature-0-1-2-3-100-00000A", target = "me" }
STATE.unit.mobB = { enemy = true, guid = "Creature-0-1-2-3-100-00000B", target = "me" }
STATE.group, STATE.who.target, STATE.who.nameplate1, STATE.who.nameplate2 = false, "mobA", "mobA", "mobB"
freshFight()
BT.flying = nil
SetIcons(false)
BT.db.merge = false
local function fly(id) fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-fly", id) end
local function on(unit, amount, school, action, flag)
    fire("UNIT_COMBAT", unit, action or "WOUND", flag or "", amount, school)
end
-- A Fireball lands a moment after the cast, and leaves the mob burning
fly(133)
assertEq(#lines("outgoing"), 0, "nothing lands with the cast")
Advance(0.8)
wound(60, 4)
assertEq(last("outgoing"), "Fireball 60", "the fire hit that lands after it is the Fireball")
assert(isColor(newest(), BT:SchoolColor("Fire")), "fire-colored")
Advance(0.4)
wound(61, 4)
assertEq(last("outgoing"), "61", "one hit for one cast")
Advance(1.6)
wound(3, 4)
assertEq(last("outgoing"), "Fireball 3", "its burn ticks two seconds after it landed")
Advance(1.1)
wound(3, 4)
assertEq(last("outgoing"), "3", "off the beat: not a tick")
clear()
-- Forever's Frostfire Bolt: Frostfire (Fire and Frost, 20), and a burn ticking every 3 seconds
-- for 9 (CurseForge, xnmd: its hit and burn had no name or icon)
fly(1237313)
Advance(1.2)
wound(300, 20)
assertEq(last("outgoing"), "Frostfire Bolt 300", "the frostfire hit that lands after it is the Frostfire Bolt")
Advance(3)
wound(19, 20)
assertEq(last("outgoing"), "Frostfire Bolt 19", "its burn ticks three seconds after it landed")
Advance(1.4)
wound(19, 20)
assertEq(last("outgoing"), "19", "off the beat: not a tick")
clear()
fly(1237313)
Advance(1)
wound(280, 4)
assertEq(last("outgoing"), "Frostfire Bolt 280", "the game may call its hit Fire")
Advance(3)
wound(18, 16)
assertEq(last("outgoing"), "Frostfire Bolt 18", "or a tick Frost")
fly(1237313)
Advance(1)
wound(280, 8)
assertEq(last("outgoing"), "280", "but a nature hit isn't it")
BT.flying = nil
clear()
-- A hunter's Multi-Shot (CurseForge, feuerbanane on 1.30.0: "Multi-Shot also prints out no
-- text"): a physical shot that flies. Its hit is named, and shows with "Auto attacks" off.
BT.db.outSwings = false
fly(2643)
Advance(0.4)
wound(85, 1)
assertEq(last("outgoing"), "Multi-Shot 85", "Multi-Shot's hit is named, with auto attacks off")
fly(19434)
Advance(0.5)
wound(140, 1)
assertEq(last("outgoing"), "Aimed Shot 140", "and Aimed Shot's")
BT.db.outSwings = true
clear()
-- Only a hit of its school, on the mob it was cast at, while it can still be on its way
fly(116)   -- Frostbolt
Advance(0.4)
wound(27, 1)
assertEq(last("outgoing"), "27", "a swing landing meanwhile isn't the Frostbolt")
on("target", 0, 1, "DODGE")
assertEq(last("outgoing"), "Dodge", "nor is a swing that's dodged")
Advance(0.5)
on("nameplate2", 50, 16)
assertEq(last("outgoing"), "50", "nor a frost hit on another mob")
wound(52, 16)
assertEq(last("outgoing"), "Frostbolt 52", "the frost hit on the mob it was cast at")
fly(116)
Advance(2.6)
wound(53, 16)
assertEq(last("outgoing"), "53", "too long after the cast: something else")
fly(116)
Advance(0.9)
on("target", 0, 16, "RESIST")
assertEq(last("outgoing"), "Frostbolt Resist", "a resist is the spell's")
fly(116)
Advance(0.9)
on("target", 0, 1, "WOUND", "RESIST")
assertEq(last("outgoing"), "Frostbolt Resist", "a resist is the spell's, whatever school the game gives it")
clear()
-- The mob it was cast at, even once you've moved to another
fly(116)
STATE.who.target = "mobB"
Advance(0.7)
on("nameplate1", 51, 16)
assertEq(last("outgoing"), "Frostbolt 51", "it lands on the mob it was cast at")
STATE.who.target = "mobA"
-- Two on their way: they land in turn
fly(133)
Advance(0.3)
fly(133)
Advance(0.6)
wound(70, 4)
Advance(0.3)
wound(71, 4)
assertEq(table.concat(lines("outgoing"), " / "):match("Fireball 70 / Fireball 71$"), "Fireball 70 / Fireball 71",
    "each cast names one hit")
BT.dots = nil
clear()
-- In its cast's own frame: a swing isn't it; its own hit, when it needs no time to land, is
fly(116)
wound(27, 1)
assertEq(last("outgoing"), "27", "a swing landing with the cast isn't the Frostbolt, even the first time")
Advance(0.5)
wound(54, 16)
assertEq(last("outgoing"), "Frostbolt 54", "the Frostbolt still lands after")
fly(5176)   -- Wrath
wound(40, 8)
assertEq(last("outgoing"), "Wrath 40", "a hit of its school with the cast is the cast's")
Advance(0.5)
wound(41, 8)
assertEq(last("outgoing"), "41", "and it isn't waited for again")
fly(5176)
on("target", 0, 1, "DODGE")
assertEq(last("outgoing"), "Dodge", "a swing dodged with the cast isn't the Wrath")
Advance(0.5)
wound(42, 8)
assertEq(last("outgoing"), "Wrath 42", "the Wrath still lands")
clear()
-- With a tick of yours of the same school: the tick on its beat, unless its amount says otherwise
BT.flying, BT.dots = nil, nil
fly(5570)   -- Insect Swarm: nature, every 2 seconds
Advance(2)
wound(9, 8)
assertEq(last("outgoing"), "Insect Swarm 9", "its first tick")
Advance(1.5)
fly(5176)
Advance(0.5)
wound(45, 8)
assertEq(last("outgoing"), "Wrath 45", "a Wrath landing on the swarm's beat, for more than its ticks: the Wrath")
Advance(2)
wound(9, 8)
assertEq(last("outgoing"), "Insect Swarm 9", "the next tick")
Advance(1.5)
fly(5176)
Advance(0.5)
wound(9, 8)
assertEq(last("outgoing"), "Insect Swarm 9", "a tick for what its ticks hit for, while a Wrath is on its way: the tick")
Advance(0.6)
wound(44, 8)
assertEq(last("outgoing"), "Wrath 44", "and then the Wrath")
BT.dots = nil
clear()
-- Something much smaller of its school landing meanwhile (a mage's Ignite) isn't it, once it's been seen to land
BT.flying, BT.flightLeast = nil, nil
fly(133)
Advance(0.8)
wound(300, 4)
assertEq(last("outgoing"), "Fireball 300", "a Fireball lands")
BT.dots = nil
fly(133)
Advance(0.5)
wound(60, 4)
assertEq(last("outgoing"), "60", "an Ignite tick for a fifth of it, while the next is on its way: not the Fireball")
Advance(0.3)
wound(280, 4)
assertEq(last("outgoing"), "Fireball 280", "the Fireball, for about what it hit for before")
fly(133)
Advance(0.8)
wound(120, 4, "RESIST")
assertEq(last("outgoing"), "Fireball 120 |cffb0b0b0(resisted)|r", "partly resisted, it's still the Fireball")
STATE.spellNames[143] = "Fireball"
fly(143)   -- a lower rank of it
Advance(0.8)
wound(40, 4)
assertEq(last("outgoing"), "Fireball 40", "a lower rank hits for less, and goes by its own amounts")
STATE.spellNames[143] = nil
BT.dots = nil
clear()
-- Landing in the frame of an instant cast of the same school: one hit on the mob is the cast's, the other the Fireball's
BT.flightLeast = nil
fly(133)
Advance(0.8)
fly(2136)   -- Fire Blast
wound(80, 4)
wound(300, 4)
assertEq(table.concat(lines("outgoing"), " / "), "Fire Blast 80 / Fireball 300", "the cast's hit, and the Fireball")
BT.dots = nil
clear()
hidden(70)
fly(133)
Advance(0.8)
hidden(71) fly(2136) hidden(72) wound(81, 4) hidden(73) wound(301, 4)
assertEq(table.concat(lines("outgoing"), " / "), "Fire Blast 81 / Fireball 301", "the same with the combat lines arriving")
Advance(0.5)
hidden(74) fly(2136) hidden(75) wound(82, 4)
assertEq(last("outgoing"), "Fire Blast 82", "with nothing on its way, the cast's hit as before")
BT.hiddenSeen, BT.hiddenAt, BT.credits, BT.dots = nil, nil, nil, nil
clear()
-- A Holy hit with your swing is your seal's, even with a Hammer of Wrath on its way
STATE.spellNames[24275] = "Hammer of Wrath"
BT.seal = nil
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-seal", 21084)
fly(24275)
Advance(0.3)
wound(30, 1)
wound(12, 2)
assertEq(table.concat(lines("outgoing"), " / "), "30 / Seal of Righteousness 12", "the seal's hit beside your swing")
Advance(0.4)
wound(250, 2)
assertEq(last("outgoing"), "Hammer of Wrath 250", "and then the Hammer of Wrath")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-seal", 20271)
BT.seal = nil
clear()
-- In a group, a hit is yours only with a line of yours: someone else's doesn't use yours up
STATE.group = true
BT.hiddenSeen, BT.hiddenAt, BT.credits, BT.flightLeast = true, nil, nil, nil
fly(133)
Advance(0.5)
wound(55, 4)
assertEq(#lines("outgoing"), 0, "a fire hit with no line of yours isn't yours")
Advance(0.3)
hidden(60)
wound(62, 4)
assertEq(last("outgoing"), "Fireball 62", "yours, with its line, is still the Fireball")
STATE.group = false
BT.hiddenSeen, BT.hiddenAt, BT.credits, BT.dots, BT.flying = nil, nil, nil, nil, nil
-- Forgotten once they can't land any more
fly(116)
Advance(5)
fire("PLAYER_REGEN_ENABLED")
assertEq(#BT.flying, 0, "a spell that never landed is forgotten")
-- Debug says what a hit was taken for
BT.db.debug, BT.recorded = true, {}
fly(116)
Advance(0.5)
wound(56, 16)
BT:FlushHits(true)
assert(table.concat(BT.recorded, "\n"):find("cast of Frostbolt", 1, true), "debug names the spell")
BT.db.debug = false
BT.db.merge = true
clear()

step("explosives you throw (issue #6)")
STATE.unit.mobA = { enemy = true, guid = "Creature-0-1-2-3-100-00000A", target = "me" }
STATE.unit.mobB = { enemy = true, guid = "Creature-0-1-2-3-100-00000B", target = "me" }
STATE.unit.mobC = { enemy = true, guid = "Creature-0-1-2-3-100-00000C" }   -- not after you
STATE.group, STATE.who.target = false, "mobA"
STATE.who.nameplate1, STATE.who.nameplate2, STATE.who.nameplate3 = "mobA", "mobB", "mobC"
STATE.spellNames[4054], STATE.spellNames[13241], STATE.spellNames[19821] = "Rough Dynamite", "Goblin Sapper Charge", "Arcane Bomb"
STATE.spellIcons[4054] = 133714
freshFight()
BT.thrown = nil
SetIcons(false)
BT.db.merge = false
local function throw(id) fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-throw", id) end
local function on(unit, amount, school, action, flag)
    fire("UNIT_COMBAT", unit, action or "WOUND", flag or "", amount, school)
end
-- Dynamite goes off a moment after the throw, on every mob where it lands
throw(4054)
assertEq(#lines("outgoing"), 0, "nothing lands with the throw")
Advance(0.9)
on("target", 30, 4)
on("nameplate2", 28, 4)
on("nameplate3", 27, 4)
assertEq(table.concat(lines("outgoing"), " / "), "Rough Dynamite 30 / Rough Dynamite 28 / Rough Dynamite 27",
    "every mob it hits, your target or not, gets its name")
Advance(0.3)
on("target", 31, 4)
assertEq(last("outgoing"), "31", "it went off: a fire hit after that is something else")
clear()
-- With its icon, as your spells have
SetIcons(true)
throw(4054)
Advance(0.8)
on("nameplate2", 29, 4)
assertEq(last("outgoing"), "|T133714:0|t Rough Dynamite 29", "with the dynamite's icon")
SetIcons(false)
clear()
-- Only a hit of its school, while it can still be on its way
throw(4054)
Advance(0.5)
wound(25, 1)
assertEq(last("outgoing"), "25", "a swing landing meanwhile isn't the dynamite")
on("target", 0, 1, "DODGE")
assertEq(last("outgoing"), "Dodge", "nor is a dodged swing")
Advance(0.4)
on("target", 0, 4, "RESIST")
assertEq(last("outgoing"), "Rough Dynamite Resist", "a resist is the dynamite's")
throw(4054)
Advance(2.6)
on("target", 30, 4)
assertEq(last("outgoing"), "30", "too long after the throw: something else")
clear()
-- A Sapper Charge goes off at once, in the frame of its use
throw(13241)
on("target", 300, 4)
on("nameplate2", 290, 4)
assertEq(table.concat(lines("outgoing"), " / "), "Goblin Sapper Charge 300 / Goblin Sapper Charge 290",
    "a charge that goes off at once names its hits")
Advance(0.5)
on("target", 31, 4)
assertEq(last("outgoing"), "31", "and it's done after that")
clear()
-- Each explosive has its school: an Arcane Bomb's hit is arcane
throw(19821)
Advance(0.7)
on("target", 40, 4)
assertEq(last("outgoing"), "40", "a fire hit isn't an Arcane Bomb")
on("target", 41, 64)
assertEq(last("outgoing"), "Arcane Bomb 41", "an arcane one is")
-- Never landed: forgotten when the fight ends
throw(4054)
Advance(5)
fire("PLAYER_REGEN_ENABLED")
assertEq(#BT.thrown, 0, "a throw that never hit anything is forgotten")
STATE.who.nameplate1, STATE.who.nameplate2, STATE.who.nameplate3 = nil, nil, nil
STATE.unit.mobC = nil
BT.db.merge = true
clear()

step("spells that keep hitting: channels and area spells")
STATE.unit.mobA = { enemy = true, guid = "Creature-0-1-2-3-100-00000A", target = "me" }
STATE.unit.mobB = { enemy = true, guid = "Creature-0-1-2-3-100-00000B", target = "me" }
STATE.unit.mobC = { enemy = true, guid = "Creature-0-1-2-3-100-00000C" }   -- not after you
STATE.group, STATE.who.target = false, "mobA"
STATE.who.nameplate1, STATE.who.nameplate2, STATE.who.nameplate3 = "mobA", "mobB", "mobC"
STATE.spellNames[10], STATE.spellNames[5143], STATE.spellNames[26573] = "Blizzard", "Arcane Missiles", "Consecration"
STATE.spellIcons[10] = 135857
freshFight()
BT.areaOn = nil
SetIcons(false)
BT.db.merge = false
local function on(unit, amount, school, action, flag)
    fire("UNIT_COMBAT", unit, action or "WOUND", flag or "", amount, school)
end
local function channel(id) fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-ch", id) end
local function stop(id) fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-ch", id) end
-- Blizzard: every mob in it, each time it hits, while you channel
channel(10)
Advance(1)
on("target", 40, 16)
on("nameplate2", 41, 16)
on("nameplate3", 39, 16)
assertEq(table.concat(lines("outgoing"), " / "), "Blizzard 40 / Blizzard 41 / Blizzard 39",
    "each mob it hits, your target or not, gets its name")
Advance(1)
on("target", 42, 16)
assertEq(last("outgoing"), "Blizzard 42", "and the next wave too")
Advance(0.5)
on("nameplate3", 38, 16)
assertEq(last("outgoing"), "Blizzard 38", "a mob that isn't after you, hit on its own")
on("target", 30, 4)
assertEq(last("outgoing"), "30", "a hit of another school isn't the Blizzard")
SetIcons(true)
Advance(1)
on("target", 43, 16)
assertEq(last("outgoing"), "|T135857:0|t Blizzard 43", "with its icon")
SetIcons(false)
on("target", 0, 16, "RESIST")
assertEq(last("outgoing"), "Blizzard Resist", "a resist is the Blizzard's")
stop(10)
Advance(0.5)
on("target", 44, 16)
assertEq(last("outgoing"), "Blizzard 44", "what was already falling as you stopped still lands")
Advance(0.6)
on("target", 45, 16)
assertEq(last("outgoing"), "45", "after you stopped channeling: something else")
clear()
-- With hidden amounts and "Add up rapid hits" on: one wave is one line, counted
BT.db.merge = true
channel(10)
Advance(1)
on("target", Secret(40), 16)
on("nameplate2", Secret(41), 16)
on("nameplate3", Secret(39), 16)
assertEq(#lines("outgoing"), 1, "a hidden Blizzard wave on three mobs: one line")
assertEq(BT.areas.outgoing.active[1].text.__shown, "Blizzard <secret> |cffb0b0b0(3 hits)|r",
    "the last hit, and how many")
stop(10)
BT.db.merge = false
clear()
-- The longest it can last, without a stop
channel(10)
Advance(8.5)
on("target", 46, 16)
assertEq(last("outgoing"), "Blizzard 46", "a moment after its 8 seconds: still landing")
Advance(0.6)
on("target", 47, 16)
assertEq(last("outgoing"), "47", "past its time and the slack: something else")
clear()
-- Arcane Missiles: only the mob you channel at
channel(5143)
Advance(0.6)
on("nameplate2", 20, 64)
assertEq(last("outgoing"), "20", "an arcane hit on another mob isn't the missiles")
on("target", 21, 64)
assertEq(last("outgoing"), "Arcane Missiles 21", "the one you channel at")
STATE.who.target = "mobB"
Advance(0.6)
on("nameplate1", 22, 64)
assertEq(last("outgoing"), "Arcane Missiles 22", "even once you've moved your target")
STATE.who.target = "mobA"
stop(5143)
clear()
-- Starshards (a Night Elf priest's, 1.35.0, CurseForge): Arcane ticks on the mob you channel at
STATE.spellNames[10797] = "Starshards"
channel(10797)
Advance(2)
on("target", 34, 64)
assertEq(last("outgoing"), "Starshards 34", "a Starshards tick is named")
on("nameplate2", 19, 64)
assertEq(last("outgoing"), "19", "an arcane hit on another mob isn't Starshards")
stop(10797)
Advance(1.1)
on("target", 35, 64)
assertEq(last("outgoing"), "35", "after the channel: not Starshards")
clear()
-- Wrack (Forever's Affliction talent): a channel on the mob you aim it at, Shadow every second,
-- with its icon. While it lasts your Corruption there ticks twice as fast (every 1.5s).
STATE.spellNames[1316697], STATE.spellNames[172] = "Wrack", "Corruption"
STATE.spellIcons[1316697] = 136163
BT.periodic, BT.dots = nil, nil
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-cor", 172)
Advance(3)
on("target", 30, 32)
assertEq(last("outgoing"), "Corruption 30", "Corruption ticks on its 3s beat")
channel(1316697)
SetIcons(true)
Advance(1)
on("target", 60, 32)
assertEq(last("outgoing"), "|T136163:0|t Wrack 60", "a Wrack tick, named and with its icon")
SetIcons(false)
Advance(0.5)
on("target", 31, 32)
assertEq(last("outgoing"), "Corruption 31", "under Wrack, Corruption ticks 1.5s after its last tick")
Advance(0.5)
on("target", 61, 32)
assertEq(last("outgoing"), "Wrack 61", "and Wrack's next second is Wrack's")
on("nameplate2", 25, 32)
assertEq(last("outgoing"), "25", "a shadow hit on another mob isn't Wrack")
Advance(1)
on("target", 32, 32)
assertEq(last("outgoing"), "Corruption 32", "Corruption again 1.5s on")
on("target", 0, 32, "RESIST")
assertEq(last("outgoing"), "Wrack Resist", "a resist while you channel is Wrack's")
stop(1316697)
Advance(1.1)
on("target", 62, 32)
assertEq(last("outgoing"), "62", "after you stopped channeling: not Wrack")
Advance(1.9)
on("target", 33, 32)
assertEq(last("outgoing"), "Corruption 33", "with Wrack over, Corruption is back to every 3s")
BT.dots = nil
clear()
-- Consecration: lasts its 8 seconds whatever you do
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-cons", 26573)
Advance(1)
on("target", 12, 2)
on("nameplate3", 12, 2)
assertEq(table.concat(lines("outgoing"), " / "), "Consecration 12 / Consecration 12", "it burns every mob on it")
Advance(7)
on("target", 13, 2)
assertEq(last("outgoing"), "Consecration 13", "for its 8 seconds")
-- "DoTs and area spells" off: its ticks are hidden
BT.db.outTicks = false
Advance(0.5)
local before = #lines("outgoing")
on("target", 13, 2)
assertEq(#lines("outgoing"), before, "turned off: Consecration's ticks are hidden")
BT.db.outTicks = true
Advance(2.1)
on("target", 14, 2)
assertEq(last("outgoing"), "14", "and no longer")
on("nameplate3", 15, 2)
assertEq(last("outgoing"), "14", "a mob that isn't after you, with nothing of yours there: not shown")
clear()
-- Consecration's tick with Retribution Aura on and no line of yours with it (the mob dying in
-- that moment: a player's screenshot, a bare "6" under "7 Retribution Aura"). It waited for a
-- blow on you as the aura's answer, none came, and it was shown with no name.
do
    STATE.buffs = { { name = "Retribution Aura", spellId = 10301 } }
    fire("PLAYER_REGEN_ENABLED")
    BT.db.shieldAmounts = {}
    BT.db.debug, BT.recorded = true, {}
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-cons2", 26573)
    Advance(1)
    hidden(30) on("target", 6, 2)
    Advance(1)
    on("target", Secret(6), 2)   -- (the game sent no line for it)
    Advance(1.5)
    local why
    for _, r in ipairs(BT.recorded) do why = r:match("target %(hidden amount%): (.+)$") or why end
    assertEq(why, "tick of Consecration (nothing else came for it)", "named as Consecration's tick")
    -- a blow on you just before, answered by the aura: the extra hit is still the tick
    BT.recorded = {}
    blow() on("target", Secret(7), 2)
    Advance(0.2)
    on("target", Secret(6), 2)
    Advance(1.5)
    local named = {}
    for _, r in ipairs(BT.recorded) do
        local what = r:match("target %(hidden amount%): (.+)$")
        if what and not what:match("^waiting") then named[#named + 1] = what end
    end
    assertEq(table.concat(named, " / "), "shield of Retribution Aura / tick of Consecration (nothing else came for it)",
        "the aura answers the blow, the other hit is Consecration's")
    -- Consecration over: a lone Holy hit is shown as it is, as before
    Advance(6)
    BT.recorded = {}
    on("target", Secret(6), 2)
    Advance(1.5)
    why = nil
    for _, r in ipairs(BT.recorded) do why = r:match("target %(hidden amount%): (.+)$") or why end
    assertEq(why, "nothing came for it: shown", "no spell of yours burning there: shown as it is")
    BT.db.debug, BT.recorded = false, nil
    STATE.buffs = {}
    fire("PLAYER_REGEN_ENABLED")
    BT.areaOn = nil
    clear()
end
STATE.who.nameplate1, STATE.who.nameplate2, STATE.who.nameplate3 = nil, nil, nil
STATE.unit.mobC = nil
BT.areaOn = nil

step("weapon and gear procs")
STATE.who.target, STATE.who.nameplate1 = "mobA", "mobA"
freshFight()
STATE.equipped[16] = { name = "Shadowfang", icon = 135315,
    lines = { "Chance on hit: Shadow bolt the enemy for 30 Shadow damage." } }
STATE.equipped[17] = { name = "Quel'Serrar", icon = 135349, lines = { "Fiery Weapon" } }
STATE.equipped[18] = { name = "Ice Barbed Spear", icon = 135130,
    lines = { "Chance on hit: Blasts a target for 95 to 105 Frost damage." } }
STATE.equipped[13] = { name = "Hand of Justice", lines = { "Equip: 2% chance on hit to gain an extra attack." } }
fire("PLAYER_EQUIPMENT_CHANGED", 16, true)
assertEq(#BT.itemProcs, 3, "three procs read from your gear (an extra attack does no damage of its own)")
assertEq(BT.itemProcs[1].name .. " " .. BT.itemProcs[1].school .. " " .. BT.itemProcs[1].most, "Shadowfang 32 30",
    "Shadowfang, Shadow, up to 30")
local function on(unit, amount, school, action, flag)
    fire("UNIT_COMBAT", unit, action or "WOUND", flag or "", amount, school)
end
-- With your swing, in the same frame
SetIcons(true)
wound(55, 1)
on("target", 30, 32)
assertEq(table.concat(lines("outgoing"), " / "), "|T135315:0|t 55 / |T135315:0|t Shadowfang 30",
    "the proc beside your swing is named after the weapon, with its icon (and the swing has the weapon's)")
SetIcons(false)
Advance(1)
on("target", 29, 32)
assertEq(last("outgoing"), "Shadowfang 29", "a moment after the swing, it still is")
Advance(2)
on("target", 28, 32)
assertEq(last("outgoing"), "28", "with no swing of yours just before: not the proc")
wound(55, 1)
on("target", 80, 32)
assertEq(last("outgoing"), "80", "too big for it: something else")
on("target", 40, 4)
assertEq(last("outgoing"), "Fiery Weapon 40", "an enchant's: named after the enchant")
on("target", 104, 16)
assertEq(last("outgoing"), "Ice Barbed Spear 104", "one that hits for a range: up to its most")
on("target", 150, 16, "WOUND", "")
assertEq(last("outgoing"), "150", "over its most: not it")
STATE.equipped[16], STATE.equipped[17], STATE.equipped[18], STATE.equipped[13] = nil, nil, nil, nil
fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
Advance(0.5)
wound(55, 1)
on("target", 30, 32)
assertEq(last("outgoing"), "30", "the weapon taken off: no proc")
STATE.who.nameplate1 = nil
BT.struck = nil
BT.db.merge = true
clear()

step("rogue poisons: Instant, Wound and Deadly Poison on your weapons")
-- CurseForge (TheFarbod, 1.24.0): poison damage showed as plain numbers. A poison's tooltip line
-- has its rank and time left ("Instant Poison III (30 min)"), so it never matched an enchant's
-- name; and Deadly Poison ticks every 3s for 12s, long after the blow that put it on.
do
    STATE.who.target, STATE.who.nameplate1 = "mobA", "mobA"
    freshFight()
    BT.struck = nil
    BT.db.merge = false
    STATE.spellNames[8680], STATE.spellNames[13218], STATE.spellNames[2818] = "Instant Poison", "Wound Poison", "Deadly Poison"
    STATE.spellIcons[8680], STATE.spellIcons[2818], STATE.spellIcons[13218] = 132273, 132290, 134197
    local function on(amount, school) fire("UNIT_COMBAT", "target", "WOUND", "", amount, school) end
    -- Instant Poison alone, on the main hand
    STATE.equipped[16] = { name = "Kingsfall", icon = 135662, lines = { "Instant Poison III (30 min)" } }
    fire("PLAYER_EQUIPMENT_CHANGED", 16, true)
    local p1 = BT.itemProcs[1]
    assertEq(p1 and (p1.name .. " " .. p1.school .. " " .. p1.id), "Instant Poison 8 8680",
        "the poison's line is read past its rank and time left")
    wound(60, 1)
    on(25, 8)
    assertEq(last("outgoing"), "Instant Poison 25", "Instant Poison beside your blow is named")
    SetIcons(true)
    wound(60, 1)
    on(26, 8)
    assertEq(last("outgoing"), "|T132273:0|t Instant Poison 26", "with the poison's icon")
    SetIcons(false)
    Advance(3)
    on(27, 8)
    assertEq(last("outgoing"), "27", "with no blow of yours just before: not the poison")
    -- Wound Poison, any rank, with charges in its line too
    STATE.equipped[16].lines = { "Wound Poison IV (12 min) (40 charges)" }
    fire("PLAYER_EQUIPMENT_CHANGED", 16, true)
    wound(60, 1)
    on(20, 8)
    assertEq(last("outgoing"), "Wound Poison 20", "Wound Poison's line, rank, time and charges: named")
    -- Instant Poison on the main hand, Deadly Poison on the off hand (both Nature)
    STATE.equipped[16].lines = { "Instant Poison VI (29 min)" }
    STATE.equipped[17] = { name = "Gutgore Ripper", icon = 135651, lines = { "Deadly Poison V (30 min)" } }
    fire("PLAYER_EQUIPMENT_CHANGED", 17, true)
    assertEq(#BT.itemProcs, 2, "a poison on each hand")
    Advance(5)
    wound(60, 1)
    on(110, 8)
    assertEq(last("outgoing"), "Instant Poison 110", "beside your blow, in its frame: Instant Poison")
    Advance(3)
    on(30, 8)
    assertEq(last("outgoing"), "Deadly Poison 30", "3s after your blow, alone: a Deadly Poison tick")
    Advance(1.8)
    wound(60, 1)
    Advance(0.4)
    on(30, 8)
    assertEq(last("outgoing"), "Deadly Poison 30",
        "a moment after your blow, not in its frame: Deadly's tick (its first one has no beat to go by)")
    Advance(3)
    wound(60, 1)
    on(115, 8)
    assertEq(last("outgoing"), "Instant Poison 115", "in your blow's own frame: Instant Poison")
    Advance(3)
    on(31, 8)
    Advance(3)
    on(32, 8)
    assertEq(last("outgoing"), "Deadly Poison 32", "it keeps ticking after you stop swinging")
    Advance(10)
    on(33, 8)
    assertEq(last("outgoing"), "33", "long after your last blow on it: not Deadly Poison")
    -- Instant Poison alone keeps the moment after your blow (its hit can come a frame late)
    STATE.equipped[17] = nil
    fire("PLAYER_EQUIPMENT_CHANGED", 17, false)
    wound(60, 1)
    Advance(0.4)
    on(105, 8)
    assertEq(last("outgoing"), "Instant Poison 105", "Instant alone: a moment after your blow is still its")
    -- A weapon's own Nature "Chance on hit" on the other hand: the poison goes off far more often
    -- (on the main hand, read first; the poison on the off hand)
    local poisoned = STATE.equipped[16]
    STATE.equipped[16] = { name = "Electrocutioner Leg", icon = 135650,
        lines = { "Chance on hit: Blasts your enemy with lightning, dealing 10 to 20 Nature damage." } }
    STATE.equipped[17] = poisoned
    fire("PLAYER_EQUIPMENT_CHANGED", 17, true)
    Advance(2)
    wound(60, 1)
    on(15, 8)
    assertEq(last("outgoing"), "Instant Poison 15", "a poison comes before a weapon's own Nature proc")
    STATE.equipped[16], STATE.equipped[17] = poisoned, nil
    fire("PLAYER_EQUIPMENT_CHANGED", 17, false)
    -- Deadly Poison alone: its ticks are its, and "DoT ticks" off hides them
    STATE.equipped[16] = nil
    STATE.equipped[17] = { name = "Gutgore Ripper", icon = 135651, lines = { "Deadly Poison V (30 min)" } }
    fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
    wound(60, 1)
    Advance(3)
    on(30, 8)
    assertEq(last("outgoing"), "Deadly Poison 30", "Deadly Poison alone: its tick is named")
    BT.db.outTicks = false
    Advance(3)
    local before = #lines("outgoing")
    on(30, 8)
    assertEq(#lines("outgoing"), before, "a Deadly Poison tick is a DoT tick: hidden with ticks off")
    BT.db.outTicks = true
    -- The game colors the poison's line, and putting a poison on fires UNIT_INVENTORY_CHANGED, a
    -- moment before the tooltip has it (CurseForge, TheFarbod, 1.24.1)
    STATE.equipped[17] = nil
    STATE.equipped[16] = { name = "Kingsfall", icon = 135662 }
    fire("PLAYER_EQUIPMENT_CHANGED", 16, true)
    assertEq(#BT.itemProcs, 0, "no poison on yet")
    fire("UNIT_INVENTORY_CHANGED", "player")
    STATE.equipped[16].lines = { "|cff00ff00Instant Poison VI (30 min) (60 charges)|r" }
    STATE.weaponEnchants = { [0] = { { hasEnchant = true, enchantType = 0, timeLeft = 1800000, charges = 60,
        enchantID = 625 } } }
    Advance(0.1)
    fire("UNIT_INVENTORY_CHANGED", "player")
    Advance(0.2)
    assertEq(#BT.itemProcs, 0, "the gear is read a moment after the last change, not at once")
    Advance(0.2)
    assertEq(BT.itemProcs[1] and BT.itemProcs[1].name, "Instant Poison",
        "read after the poison went on, past its color codes, charges and time left")
    -- Looting fires UNIT_INVENTORY_CHANGED too: with nothing you wear changed, the tooltips aren't
    -- read again (a player's report: a small hitch with each item looted). Not even when the
    -- poison's time and charges ran down.
    do
        local reads, realGet = 0, C_TooltipInfo.GetInventoryItem
        C_TooltipInfo.GetInventoryItem = function(...) reads = reads + 1 return realGet(...) end
        STATE.weaponEnchants[0][1].timeLeft, STATE.weaponEnchants[0][1].charges = 1700000, 55
        for _ = 1, 3 do fire("UNIT_INVENTORY_CHANGED", "player") Advance(0.5) end
        assertEq(reads, 0, "a loot: the gear isn't read again")
        STATE.weaponEnchants[0][1].enchantID = 626
        fire("UNIT_INVENTORY_CHANGED", "player") Advance(0.5)
        assertEq(reads, 19, "another poison on the weapon: read again")
        reads = 0
        STATE.equipped[11] = { name = "Ring", id = 999 }
        fire("UNIT_INVENTORY_CHANGED", "player") Advance(0.5)
        assertEq(reads, 19, "a new piece put on: read again")
        STATE.equipped[11] = nil
        C_TooltipInfo.GetInventoryItem = realGet
        fire("UNIT_INVENTORY_CHANGED", "player") Advance(0.5)
    end
    -- No icon from the poison's spell: the one the game shows for the weapon's poison
    STATE.weaponEnchants = { [0] = { { hasEnchant = true, enchantType = 0, timeLeft = 1800000, charges = 60,
        enchantID = 625, enchantIconID = 136007 } } }
    STATE.spellIcons[8680], BT.iconCache = nil, nil
    fire("UNIT_INVENTORY_CHANGED", "player")
    Advance(0.5)
    SetIcons(true)
    Advance(2)
    wound(60, 1)
    on(90, 8)
    assertEq(last("outgoing"), "|T136007:0|t Instant Poison 90", "with the icon the game shows for the weapon's poison")
    SetIcons(false)
    STATE.weaponEnchants = nil
    STATE.equipped[16] = nil
    fire("PLAYER_EQUIPMENT_CHANGED", 16, false)
    -- A poison's name on another slot (a trinket called that) is not a poison on your weapon
    STATE.equipped[17] = nil
    STATE.equipped[13] = { name = "Odd Trinket", lines = { "Instant Poison" } }
    fire("PLAYER_EQUIPMENT_CHANGED", 13, true)
    assertEq(#BT.itemProcs, 0, "only a weapon carries a poison")
    STATE.equipped[13] = nil
    fire("PLAYER_EQUIPMENT_CHANGED", 13, false)
    BT.struck = nil
    STATE.who.nameplate1 = nil
    BT.db.merge = true
    clear()
end

step("Serpent Sting: its ticks are timed from when the shot lands")
-- CurseForge (1.24.1): "Serpent Sting for Hunters is only showing a number. No name or icon." The
-- sting is a shot: it lands a moment after the cast, and its ticks were off the beat counted
-- from the cast, so none was ever named.
do
    STATE.who.target = "mobA"
    freshFight()
    BT.db.merge = false
    STATE.spellNames[1978], STATE.spellIcons[1978] = "Serpent Sting", 132204
    BT.periodic = nil
    local function on(amount) fire("UNIT_COMBAT", "target", "WOUND", "", amount, 8) end
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-sting", 1978)
    Advance(3.8)   -- (landed 0.8s after the cast)
    on(12)
    assertEq(last("outgoing"), "Serpent Sting 12", "its first tick, late by the shot's flight: named")
    SetIcons(true)
    Advance(3)
    on(12)
    assertEq(last("outgoing"), "|T132204:0|t Serpent Sting 12", "then on its own beat, with its icon")
    SetIcons(false)
    Advance(1.5)
    on(40)
    assertEq(last("outgoing"), "40", "a Nature hit off its beat isn't it")
    BT.dots = nil
    clear()
end

step("gear that adds a set amount to every hit: Cursed Murloc Eye, and Hide hits below")
-- CurseForge (1.21.5): "Cursed Murloc Eye still shows the 2 shadow damage even you hide hits below
-- 5". The Eye adds 2 Shadow to every spell and attack; the game hides its number in a fight, and
-- a hidden number always showed. It's named now, and its amount is known, so the setting hides it.
do
    STATE.who.target = "mobA"
    freshFight()
    BT.db.merge = false
    STATE.equipped[13] = { name = "Cursed Murloc Eye", icon = 133884,
        lines = { "Equip: Spells and attacks deal 2 Shadow damage. Deals 4 times as much damage to Murlocs." } }
    fire("PLAYER_EQUIPMENT_CHANGED", 13, true)
    local eye = BT.itemProcs[1]
    assertEq(eye and (eye.name .. " " .. eye.school .. " " .. eye.amount .. " x" .. eye.times .. " " .. eye.versus),
        "Cursed Murloc Eye 32 2 x4 Murloc", "read from the trinket: 2 Shadow, 4 times as much to Murlocs")
    local function hiddenOn(n, school) fire("UNIT_COMBAT", "target", "WOUND", "", Secret(n), school) end
    -- Beside your swing, hidden: named after the trinket, its number still drawn by the game
    wound(40, 1)
    hiddenOn(2, 32)
    assertEq(#lines("outgoing"), 2, "your swing and the Eye's hit")
    BT:FlushHits(true)
    local a = BT.areas.outgoing.active
    assertEq(a[#a].text.__shown, "Cursed Murloc Eye <secret>", "the hidden hit is the Eye's")
    clear()
    -- Hide hits below 5: the Eye's 2 goes, hidden number or not; your swing stays
    BT.db.minDamage = 5
    wound(40, 1)
    hiddenOn(2, 32)
    assertEq(table.concat(lines("outgoing"), " / "), "40", "hidden hits below 5: the Eye's hidden 2 isn't shown")
    Advance(2)
    wound(41, 1)
    fire("UNIT_COMBAT", "target", "WOUND", "", 2, 32)
    assertEq(last("outgoing"), "41", "nor a readable one")
    -- With a Frost spell's hit too (spells, not only attacks)
    Advance(2)
    fire("UNIT_COMBAT", "target", "WOUND", "", 120, 16)
    hiddenOn(2, 32)
    assertEq(last("outgoing"), "120", "beside a spell's hit it's hidden too")
    -- CurseForge (OdysseaLUL, on 1.30.0): "it still shows some random damages from the cursed
    -- murloc eye... might be from the skills". The Eye's hit can come a moment before or after a
    -- spell's or ability's hit, not in the same frame: it waited for a swing that never came.
    Advance(2)
    hiddenOn(2, 32)
    Advance(0.4)
    fire("UNIT_COMBAT", "target", "WOUND", "", 120, 16)
    Advance(1.3)
    assertEq(table.concat(lines("outgoing"), " / "), "120", "the Eye's hit just before a spell's: hidden below 5")
    clear()
    Advance(2)
    fire("UNIT_COMBAT", "target", "WOUND", "", 120, 16)
    Advance(0.2)
    hiddenOn(2, 32)
    Advance(1.3)
    assertEq(table.concat(lines("outgoing"), " / "), "120", "the Eye's hit just after a spell's: hidden below 5")
    clear()
    -- (a Frost hit of the Eye's own school isn't the point: an ability's physical hit works too, a
    -- hidden one as well)
    Advance(2)
    hiddenOn(2, 32)
    Advance(0.3)
    fire("UNIT_COMBAT", "target", "WOUND", "", Secret(55), 1)
    Advance(1.3)
    assertEq(#lines("outgoing"), 1, "the Eye's hit before a hidden ability hit: only the ability shows")
    clear()
    -- (a warlock's hidden Shadow hit next to an Immolate may be a Shadow spell of theirs: shown)
    do
        local wasClass = STATE.class
        STATE.class = "WARLOCK"
        Advance(2)
        fire("UNIT_COMBAT", "target", "WOUND", "", 120, 4)
        Advance(0.2)
        hiddenOn(300, 32)
        Advance(1.3)
        assertEq(#lines("outgoing"), 2, "a warlock's hidden Shadow hit after a Fire hit isn't taken for the Eye")
        clear()
        Advance(2)
        hiddenOn(300, 32)
        Advance(0.3)
        fire("UNIT_COMBAT", "target", "WOUND", "", 120, 4)
        Advance(1.3)
        assertEq(#lines("outgoing"), 2, "nor one before it")
        STATE.class = wasClass
        clear()
    end
    -- A Shadow hit of 2 on its own, with nothing of yours beside it: it waits a moment for your
    -- swing, and when none comes it isn't the Eye's: shown
    Advance(3)
    hiddenOn(2, 32)
    assertEq(#lines("outgoing"), 0, "a hidden Shadow hit alone waits for your swing")
    Advance(1.3)
    assertEq(#lines("outgoing"), 1, "a hidden Shadow hit with no hit of yours beside it still shows")
    clear()
    -- GitHub #25 (1.24.3): with the combat lines on, the Eye's hit comes with its line, up to a
    -- second ahead of your swing's hit. It waits for the swing, then is the Eye's and is hidden.
    do
        local was = { STATE.filterApplied, STATE.filteredEvents }
        STATE.filterApplied, STATE.filteredEvents = true, true
        Advance(3)
        hidden(1)
        hiddenOn(2, 32)
        Advance(0.4)
        fire("PLAYER_SWING", 2.6, 0)
        hidden(2)
        wound(40, 1)
        Advance(1.3)
        assertEq(table.concat(lines("outgoing"), " / "), "40", "the Eye's hit ahead of your swing: hidden below 5")
        clear()
        BT.db.minDamage = 0
        Advance(3)
        hidden(1)
        hiddenOn(2, 32)
        Advance(0.4)
        fire("PLAYER_SWING", 2.6, 0)
        hidden(2)
        wound(40, 1)
        BT:FlushHits(true)
        local shown = {}
        for _, l in ipairs(BT.areas.outgoing.active) do shown[#shown + 1] = l.text.__shown end
        assertEq(table.concat(shown, " / "), "40 / Cursed Murloc Eye <secret>", "and named after the trinket, shown at 0 (once your swing lands)")
        BT.db.minDamage = 5
        STATE.filterApplied, STATE.filteredEvents = was[1], was[2]
        BT.hiddenSeen, BT.hiddenAt, BT.credits, BT.swings = nil, nil, nil, nil
        clear()
    end
    -- A Murloc takes 8: with Hide hits below 5 it shows; below 10 it doesn't
    STATE.unit.mobA.creature = "Murloc"
    wound(40, 1)
    hiddenOn(8, 32)
    assertEq(#lines("outgoing"), 2, "on a Murloc it does 8, more than 5: shown")
    clear()
    BT.db.minDamage = 10
    wound(40, 1)
    hiddenOn(8, 32)
    assertEq(table.concat(lines("outgoing"), " / "), "40", "and hidden below 10")
    STATE.unit.mobA.creature = nil
    clear()
    -- Two hidden Shadow hits side by side (a Shadow Bolt and the Eye) can't be told apart: neither
    -- is taken for the Eye, so a big one is never hidden by mistake
    BT.db.minDamage = 5
    local wasClass = STATE.class
    STATE.class = "WARLOCK"
    hiddenOn(300, 32)
    hiddenOn(2, 32)
    assertEq(#lines("outgoing"), 2, "two hidden Shadow hits together (a warlock): both shown")
    clear()
    -- GitHub #25 (1.27.1, a shaman's log): Stormstrike and its swing in one frame, each with the
    -- Eye's hidden Shadow hit. A shaman has no Shadow spells: both are the Eye's, hidden below 5.
    STATE.class = "SHAMAN"
    Advance(3)
    wound(40, 1)
    hiddenOn(2, 32)
    hiddenOn(2, 32)
    assertEq(table.concat(lines("outgoing"), " / "), "40", "a shaman's two hidden Shadow hits beside a blow: both the Eye's")
    clear()
    -- (but not two on their own: they wait for a swing, and none comes)
    Advance(3)
    hiddenOn(2, 32)
    hiddenOn(2, 32)
    Advance(1.3)
    assertEq(#lines("outgoing"), 2, "two hidden Shadow hits with no blow of yours: shown")
    clear()
    -- An Undead shaman has Touch of the Grave (Shadow): still in doubt
    STATE.race = "Scourge"
    Advance(3)
    wound(40, 1)
    hiddenOn(300, 32)
    hiddenOn(2, 32)
    Advance(1.3)
    assertEq(#lines("outgoing"), 3, "an Undead's two hidden Shadow hits: both shown")
    STATE.race = nil
    STATE.class = wasClass
    clear()
    -- GitHub #25 (1.27.1): on a Russian client the tooltip isn't English, so the Eye was never
    -- read and its 2 always showed. It's known by its item ID, named by the tooltip's first line.
    STATE.equipped[13] = { id = 273840, name = "Проклятый глаз мурлока", icon = 133884,
        lines = { "Если на персонаже: заклинания и атаки наносят 2 ед. урона от темной магии." } }
    fire("PLAYER_EQUIPMENT_CHANGED", 13, true)
    local ru = BT.itemProcs[1]
    assertEq(ru and (ru.name .. " " .. ru.school .. " " .. ru.amount .. " x" .. ru.times),
        "Проклятый глаз мурлока 32 2 x4", "a Russian Eye known by its ID")
    assertEq(#BT.itemProcs, 1, "once")
    Advance(3)
    wound(40, 1)
    hiddenOn(2, 32)
    assertEq(table.concat(lines("outgoing"), " / "), "40", "a Russian client's Eye hidden below 5")
    clear()
    -- (the English tooltip read, with its ID too: still once)
    STATE.equipped[13] = { id = 273840, name = "Cursed Murloc Eye", icon = 133884,
        lines = { "Equip: Spells and attacks deal 2 Shadow damage. Deals 4 times as much damage to Murlocs." } }
    fire("PLAYER_EQUIPMENT_CHANGED", 13, true)
    assertEq(#BT.itemProcs, 1, "an English Eye with its ID: read once")
    -- Russian Thorncursed Grips, by ID: melee only, Nature
    STATE.equipped[13] = nil
    STATE.equipped[10] = { id = 274159, name = "Терновые перчатки", icon = 132939,
        lines = { "Если на персонаже: ваши атаки оружием ближнего боя наносят 2 ед. урона от сил природы." } }
    fire("PLAYER_EQUIPMENT_CHANGED", 10, true)
    local gr = BT.itemProcs[1]
    assertEq(gr and (gr.name .. " " .. gr.school .. " " .. gr.amount .. " " .. tostring(gr.melee)),
        "Терновые перчатки 8 2 true", "Russian Grips known by their ID")
    Advance(3)
    wound(40, 1)
    hiddenOn(2, 8)
    assertEq(table.concat(lines("outgoing"), " / "), "40", "the Russian Grips' 2 hidden below 5")
    clear()
    -- Thorncursed Grips (GitHub #25): "Your melee weapon attacks deal 2 Nature damage to both you
    -- and your target". Only beside a weapon blow: a Nature hit of 2 beside a spell isn't theirs.
    STATE.equipped[13] = nil
    STATE.equipped[10] = { name = "Thorncursed Grips", icon = 132939,
        lines = { "Equip: Your melee weapon attacks deal 2 Nature damage to both you and your target." } }
    fire("PLAYER_EQUIPMENT_CHANGED", 10, true)
    local grips = BT.itemProcs[1]
    assertEq(grips and (grips.name .. " " .. grips.school .. " " .. grips.amount .. " " .. tostring(grips.melee)),
        "Thorncursed Grips 8 2 true", "read from the gloves: 2 Nature, melee only")
    Advance(3)
    wound(40, 1)
    hiddenOn(2, 8)
    assertEq(table.concat(lines("outgoing"), " / "), "40", "the Grips' hidden 2 beside your swing: hidden below 5")
    Advance(3)
    fire("UNIT_COMBAT", "target", "WOUND", "", 120, 16)
    hiddenOn(2, 8)
    Advance(1.3)
    assertEq(#lines("outgoing"), 2, "beside a Frost spell's hit only (and no swing after it), a Nature hit isn't the Grips'")
    clear()
    -- GitHub #25 (1.28.3, a shaman's log): with Lightning Shield on, the Grips' own 2 on you came
    -- as a "blow" and Windfury's three Nature hits (in doubt: a shaman has Nature spells) were named
    -- Lightning Shield. The Grips' hit on you is no blow, and it vouches for their hit on the mob.
    local wasClass = STATE.class
    STATE.class = "SHAMAN"
    BT.buffShields = { ["Lightning Shield"] = { name = "Lightning Shield", id = 324, school = 8 } }
    BT.db.debug, BT.recorded = true, {}
    local function gripsOnYou() fire("UNIT_COMBAT", "player", "WOUND", "", Secret(2), 8) end
    Advance(3)
    wound(40, 1)
    for _ = 1, 3 do hiddenOn(2, 8) gripsOnYou() end
    Advance(1.3)
    assertEq(table.concat(lines("outgoing"), " / "), "40", "Windfury's three Grips hits: all hidden below 5")
    for _, r in ipairs(BT.recorded) do
        assertEq(r:find("shield of", 1, true), nil, "none named Lightning Shield: " .. r)
    end
    assertEq(BT.lastBlow == nil or GetTime() - BT.lastBlow > 2, true, "the Grips' hit on you is no blow")
    clear()
    -- GitHub #25: Sporid Cape (its tooltip unread on a Russian client) answers the same blow as
    -- Lightning Shield. The shield names one hit; the other isn't the shield's again.
    BT.recorded = {}
    BT.db.minDamage = 0
    Advance(3)
    blow()
    hiddenOn(13, 8)
    hiddenOn(1, 8)
    assertEq(#lines("outgoing"), 2, "both shown")
    local named = 0
    for _, r in ipairs(BT.recorded) do
        if r:find("shield of Lightning Shield", 1, true) then named = named + 1 end
    end
    assertEq(named, 1, "one blow: Lightning Shield named once")
    -- Two blows close together: each one's answer is the shield's
    clear()
    BT.recorded = {}
    blow()
    Advance(0.3)
    blow()
    hiddenOn(13, 8)
    hiddenOn(13, 8)
    assertEq(#lines("outgoing"), 2, "both shown")
    named = 0
    for _, r in ipairs(BT.recorded) do
        if r:find("shield of Lightning Shield", 1, true) then named = named + 1 end
    end
    assertEq(named, 2, "two blows: two of Lightning Shield's")
    BT.db.debug, BT.recorded, BT.buffShields = false, nil, nil
    BT.db.minDamage = 5
    STATE.class = wasClass
    clear()
    BT.db.minDamage = 0
    STATE.equipped[10] = nil
    fire("PLAYER_EQUIPMENT_CHANGED", 10, false)
    BT.struck, BT.db.merge = nil, true
    clear()
end

step("gear read in any language (1.29.0): hits back, chance on hit, poisons, /btf gear")
-- GitHub #25 and others: gear was read from English tooltip text only, so on a Russian client
-- Sporid Cape, procs and poisons were unknown. The game marks the effect lines (their type, or
-- its translated label), numbers are the same everywhere, and a word per language says the school.
do
    STATE.who.target = "mobA"
    freshFight()
    BT.db.merge, BT.db.minDamage = false, 0
    STATE.locale = "ruRU"
    ITEM_SPELL_TRIGGER_ONEQUIP = "Если на персонаже:"
    ITEM_SPELL_TRIGGER_ONPROC = "Вероятность при попадании:"
    -- Gear that hits back: an Equip line naming the attacker, one number and the school
    STATE.equipped[15] = { name = "Спороносный плащ", icon = 133762,
        lines = { "Если на персонаже: При получении удара в бою наносит атакующему 1 ед. урона от сил природы." } }
    -- Not one: a spell power line (a school and one number, but no attacker)
    STATE.equipped[11] = { name = "Кольцо", lines = { "Если на персонаже: Увеличивает урон от заклинаний сил природы на 12." } }
    fire("PLAYER_EQUIPMENT_CHANGED", 15, true)
    local cape = BT.itemShields[1]
    assertEq(cape and (cape.name .. " " .. cape.amount .. " " .. cape.school), "Спороносный плащ 1 8", "a Russian cape hits back for 1 Nature")
    assertEq(#BT.itemShields, 1, "the spell power ring isn't one")
    Advance(3)
    fire("UNIT_COMBAT", "player", "WOUND", "", 20, 1)
    fire("UNIT_COMBAT", "target", "WOUND", "", 1, 8)
    assertEq(last("outgoing"), "Спороносный плащ 1", "its hit is named after it")
    clear()
    -- Chance on hit, by the game's line type alone (no label to go by), with the Russian school word
    STATE.equipped[15], STATE.equipped[11] = nil, nil
    STATE.equipped[16] = { name = "Огненный меч", icon = 135271,
        lines = { { text = "Наносит цели от 95 до 105 ед. урона от огня.", type = 46 } } }
    fire("PLAYER_EQUIPMENT_CHANGED", 16, true)
    local proc = BT.itemProcs[1]
    assertEq(proc and (proc.name .. " " .. proc.school .. " " .. proc.most), "Огненный меч 4 105", "a Russian Fire proc, up to 105")
    -- Two schools on one line: not taken
    STATE.equipped[16].lines = { "Вероятность при попадании: 20 ед. урона от огня и 20 ед. урона от магии льда." }
    fire("PLAYER_EQUIPMENT_CHANGED", 16, true)
    assertEq(#BT.itemProcs, 0, "a line with two schools is left alone")
    -- A poison, by its spell's name in the game's language
    STATE.spellNames[8680] = "Мгновенный яд"
    STATE.equipped[16] = { name = "Кинжал", icon = 135641, lines = { "|cff00ff00Мгновенный яд III (30 мин)|r" } }
    fire("PLAYER_EQUIPMENT_CHANGED", 16, true)
    local poison = BT.itemProcs[1]
    assertEq(poison and (poison.name .. " " .. poison.id .. " " .. tostring(poison.poison)), "Мгновенный яд 8680 true",
        "a Russian Instant Poison")
    -- German: the school is part of the word ("Naturschaden")
    STATE.locale = "deDE"
    ITEM_SPELL_TRIGGER_ONEQUIP = "Anlegen:"
    STATE.equipped[16] = nil
    STATE.equipped[11] = { name = "Stachelring", lines = { "Anlegen: Fügt dem Angreifer 2 Naturschaden zu, wenn Ihr im Nahkampf getroffen werdet." } }
    fire("PLAYER_EQUIPMENT_CHANGED", 11, true)
    local ring = BT.itemShields[1]
    assertEq(ring and (ring.amount .. " " .. ring.school), "2 8", "a German ring hits back for 2 Nature")
    -- English isn't changed: the English text is still what's read there
    STATE.locale = "enUS"
    fire("PLAYER_EQUIPMENT_CHANGED", 11, true)
    assertEq(#BT.itemShields, 0, "on an English client a German line means nothing")
    -- /btf gear: what each item's lines were taken for, ready to copy
    STATE.locale = "ruRU"
    ITEM_SPELL_TRIGGER_ONEQUIP = "Если на персонаже:"
    STATE.equipped[11] = nil
    STATE.equipped[15] = { id = 6629, name = "Спороносный плащ", icon = 133762,
        lines = { "Если на персонаже: При получении удара в бою наносит атакующему 1 ед. урона от сил природы." } }
    STATE.equipped[13] = { id = 273840, name = "Глаз", lines = { "Если на персонаже: непонятная строка 2." } }
    local report = table.concat(BT:ReportGear(), "\n")
    assertEq(report:find("game language ruRU", 1, true) ~= nil, true, "the language")
    assertEq(report:find("slot 15: Спороносный плащ (item 6629)", 1, true) ~= nil, true, "each item with its ID")
    assertEq(report:find("-> hits back: 1 Nature", 1, true) ~= nil, true, "what its line was taken for")
    assertEq(report:find("непонятная строка 2. -> not understood", 1, true) ~= nil, true, "a line it couldn't read says so")
    assertEq(report:find("every hit (known by its item ID)", 1, true) ~= nil, true, "gear known by its ID")
    assertEq(#BT.recorded > 0, true, "ready for /btf copy")
    STATE.locale, ITEM_SPELL_TRIGGER_ONEQUIP, ITEM_SPELL_TRIGGER_ONPROC = nil, nil, nil
    STATE.spellNames[8680] = nil
    STATE.equipped = {}
    fire("PLAYER_EQUIPMENT_CHANGED", 15, false)
    BT.recorded = nil
    clear()
end

step("a hunter's pet and other hits while you shoot don't show your melee weapon (CurseForge)")
-- Tinter: "any damage not from my ranged weapon on hunter outputs with a symbol of my melee weapon.
-- Including pet/hawk damage." A physical hit nothing named got the main hand's icon. While you're
-- shooting (a ranged swing lately and no melee swing), it isn't your weapon's: with your pet on
-- that mob it's your pet's, marked (Pet); otherwise it gets the plain Attack icon.
do
    STATE.who.target = "mobA"
    freshFight()
    BT.db.merge = false
    SetIcons(true)
    STATE.spellNames[75], STATE.spellIcons[75], STATE.spellIcons[6603] = "Auto Shot", 132369, 135274
    BT.iconCache = nil
    STATE.equipped[16] = { name = "Axe", icon = 132400, lines = {} }
    BT.hands, BT.meleeAt, BT.swungAt, BT.flying = nil, nil, nil, nil
    -- Shooting: ranged swings (swingType 2)
    fire("PLAYER_SWING", 2.8, 2)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-as", 75)
    Advance(0.4)
    wound(70, 1)
    assertEq(last("outgoing"), "|T132369:0|t Auto Shot 70", "your Auto Shot, named")
    Advance(0.3)
    wound(33, 1)
    assertEq(last("outgoing"), "|T135274:0|t 33", "a physical hit with no pet: the Attack icon, not the axe")
    -- Your pet on the mob: its hits are your pet's
    STATE.pet = true
    STATE.unit.mobA.target = "pet"
    Advance(0.3)
    wound(21, 1)
    assertEq(last("outgoing"), "(Pet) 21", "your pet's hit: marked (Pet), no weapon icon")
    fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
    assertEq(last("outgoing"), "(Pet) Dodge", "and its dodged attack")
    BT.db.outPet = false
    Advance(0.3)
    wound(22, 1)
    assertEq(last("outgoing"), "(Pet) Dodge", "\"Pet\" off hides them")
    BT.db.outPet = true
    clear()
    -- In melee (a main hand swing lately), your hit is your axe's as before, pet or not
    fire("PLAYER_SWING", 2.6, 0)
    Advance(0.4)
    wound(50, 1)
    assertEq(last("outgoing"), "|T132400:0|t 50", "your own melee swing: the axe")
    Advance(0.5)
    wound(51, 1)
    assertEq(last("outgoing"), "|T132400:0|t 51", "and while you're in melee, a hit with no swing still is")
    STATE.pet, STATE.unit.mobA.target = false, "me"
    STATE.equipped[16] = nil
    SetIcons(false)
    BT.hands, BT.meleeAt, BT.swungAt = nil, nil, nil
    BT.db.merge = true
    clear()
end

step("wanding doesn't show your melee weapon (GitHub #40)")
-- A priest wanding saw their main hand's icon. A wand's miss (or resist) of its school was taken
-- for a swing; and a swing in the same moment as Shoot's cast is that shot, whatever hand the
-- game gives it.
do
    STATE.who.target = "mobA"
    freshFight()
    BT.db.merge = false
    SetIcons(true)
    STATE.spellNames[5019], STATE.spellIcons[5019], STATE.spellIcons[6603] = "Shoot", 135463, 135274
    BT.iconCache = nil
    STATE.equipped[16] = { name = "Mace", icon = 133476, lines = {} }
    BT.hands, BT.meleeAt, BT.swungAt, BT.flying = nil, nil, nil, nil
    -- the game calls the wand's swing a main hand one (0), in the frame of Shoot's cast
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-w1", 5019)
    fire("PLAYER_SWING", 1.6, 0)
    assertEq(BT.meleeAt, nil, "the swing with Shoot's cast isn't a melee one")
    Advance(0.5)
    wound(25, 32)
    assertEq(last("outgoing"), "|T135463:0|t Shoot 25", "the wand's bolt, named")
    Advance(1.1)
    fire("PLAYER_SWING", 1.6, 0)   -- (the other way round: the swing first)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-w2", 5019)
    assertEq(BT.meleeAt, nil, "nor one just before it")
    Advance(0.5)
    fire("UNIT_COMBAT", "target", "MISS", "", 0, 32)
    assertEq(last("outgoing"):find("133476", 1, true), nil, "the wand's miss: not the mace's icon")
    Advance(0.5)
    fire("UNIT_COMBAT", "target", "RESIST", "", 0, 32)
    assertEq((last("outgoing") or ""):find("133476", 1, true), nil, "nor a resist")
    -- In melee the mace is still yours
    clear()
    Advance(3)
    fire("PLAYER_SWING", 2.6, 0)
    Advance(0.4)
    wound(50, 1)
    assertEq(last("outgoing"), "|T133476:0|t 50", "a real melee swing: the mace")
    -- a miss of a magic school with nothing flying is still not a swing, even right after one
    fire("PLAYER_SWING", 2.6, 0)
    Advance(0.3)
    fire("UNIT_COMBAT", "target", "MISS", "", 0, 32)
    assertEq((last("outgoing") or ""):find("133476", 1, true), nil, "a magic miss: not the mace's")
    STATE.equipped[16] = nil
    SetIcons(false)
    BT.hands, BT.meleeAt, BT.swungAt, BT.flying = nil, nil, nil, nil
    BT.db.merge = true
    clear()
end

step("your pet's name instead of (Pet), and your hawk's hits on their own (CurseForge)")
-- Tinter: "Is there a way to separate damage coming from your hawk on hunter? And also a way to
-- add your pets name instead of just (pet)". Summon Hawk (Forever's Beast Mastery talent) sends
-- a hawk at your target: it dives (a physical hit) and keeps attacking for 18s, and its hits come
-- with no name, like your pet's.
do
    STATE.who.target = "mobA"
    freshFight()
    BT.db.merge = false
    SetIcons(true)
    STATE.spellNames[75], STATE.spellIcons[75], STATE.spellIcons[6603] = "Auto Shot", 132369, 135274
    STATE.spellNames[1293241], STATE.spellIcons[1293241] = "Summon Hawk", 132172
    BT.iconCache, BT.periodic = nil, nil
    BT.hands, BT.meleeAt, BT.swungAt, BT.flying, BT.hawks, BT.petName = nil, nil, nil, nil, nil, nil
    fire("PLAYER_SWING", 2.8, 2)
    -- Your pet, by its name
    STATE.pet, STATE.unit.pet = true, { name = "Fluffy" }
    STATE.unit.mobA.target = "pet"
    Advance(0.3)
    wound(21, 1)
    assertEq(last("outgoing"), "(Fluffy) 21", "your pet's hit, with its name")
    -- Its name hidden (a dungeon): the one read before stays
    STATE.unit.pet.secretName = true
    Advance(0.3)
    wound(22, 1)
    assertEq(last("outgoing"), "(Fluffy) 22", "a hidden name: the last one read")
    BT.petName = nil
    Advance(0.3)
    wound(23, 1)
    assertEq(last("outgoing"), "(Pet) 23", "never read: (Pet)")
    STATE.unit.pet.secretName = nil
    -- A readable line of your pet's has its name too
    log(real("pet's spell"))
    assertEq(last("outgoing"), "Bite (Fluffy) 20", "a pet's line, with its name")
    -- The hawk, with your pet on another mob
    STATE.unit.mobA.target = "me"
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hawk", 1293241)
    Advance(0.5)
    wound(120, 1)
    assertEq(last("outgoing"), "|T132172:0|t Summon Hawk 120", "the hawk's dive: named Summon Hawk")
    Advance(1.5)
    wound(30, 1)
    assertEq(last("outgoing"), "(Hawk) 30", "the hawk's next hit: (Hawk)")
    fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
    assertEq(last("outgoing"), "(Hawk) Dodge", "and its dodged attack")
    -- Your pet on that mob too: the game doesn't say which of the two hit
    STATE.unit.mobA.target = "pet"
    Advance(1)
    wound(31, 1)
    assertEq(last("outgoing"), "(Fluffy) 31", "pet and hawk both on it: your pet's name")
    BT.db.outPet = false
    Advance(0.3)
    wound(32, 1)
    assertEq(last("outgoing"), "(Fluffy) 31", "\"Pet\" off hides them")
    STATE.unit.mobA.target = "me"
    Advance(0.3)
    wound(35, 1)
    assertEq(last("outgoing"), "(Fluffy) 31", "and the hawk's hits too")
    STATE.unit.mobA.target = "pet"
    BT.db.outPet = true
    -- 18s after the cast the hawk has gone
    Advance(15)
    wound(33, 1)
    assertEq(last("outgoing"), "(Fluffy) 33", "the hawk gone: your pet's again")
    STATE.unit.mobA.target = "me"
    Advance(0.3)
    wound(34, 1)
    assertEq(last("outgoing"), "|T135274:0|t 34", "and with no pet on it, the Attack icon as before")
    -- Two hawks at most: a third cast lets the oldest go
    BT.flying = nil
    BT:SendHawk("x1")
    BT:SendHawk("x2")
    BT:SendHawk(BT.hawks[1].key)
    assertEq(#BT.hawks, 2, "two hawks out at most")
    STATE.pet, STATE.unit.pet, STATE.unit.mobA.target = false, nil, "me"
    SetIcons(false)
    BT.hands, BT.meleeAt, BT.swungAt, BT.hawks, BT.petName, BT.flying = nil, nil, nil, nil, nil, nil
    BT.db.merge = true
    clear()
end

step("wand hits show when their line comes a frame late (CurseForge)")
-- ModsAndAddonsAreGreat: wand damage didn't show consistently. With the "My actions" lines on,
-- 1.21.4 let only a line in the hit's own frame vouch for a hit, and a wand hit's line can come a
-- frame after it: that hit was dropped as "no line of yours with it". The shot's own line, from
-- your cast, now vouches for its hit.
do
    STATE.who.target = "mobA"
    freshFight()
    BT.db.merge = false
    STATE.spellNames[5019] = "Shoot"
    BT.flying, BT.flightLeast = nil, nil
    BT.hiddenSeen, BT.credits = true, nil
    local shown = 0
    for k = 1, 4 do
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-w" .. k, 5019)
        hidden(100 + k)   -- (the shot's line)
        Advance(0.4)
        fire("UNIT_COMBAT", "target", "WOUND", "", Secret(20), 32)
        BT:FlushHits(true)
        shown = shown + #BT.areas.outgoing.active
        Advance(0.02)
        hidden(200 + k)   -- (its hit's line, a frame later)
        Advance(1.2)
        clear()
    end
    assertEq(shown, 4, "every wand hit shows")
    -- Someone else's wand hit with no shot of yours on its way still isn't yours
    STATE.group = true
    Advance(2)
    hidden(300)
    Advance(0.5)
    fire("UNIT_COMBAT", "target", "WOUND", "", 25, 32)
    assertEq(#lines("outgoing"), 0, "a party member's wand hit isn't yours")
    STATE.group = false
    BT.hiddenSeen, BT.credits, BT.flying = nil, nil, nil
    BT.db.merge = true
    clear()
end

step("icons for swings and ranged attacks (issue #8)")
STATE.who.target, STATE.who.nameplate1 = "mobA", "mobA"
freshFight()
BT.flying = nil
BT.db.merge = false
STATE.spellNames[75], STATE.spellNames[3018], STATE.spellNames[2764], STATE.spellNames[5019] =
    "Auto Shot", "Shoot", "Throw", "Shoot"
STATE.spellIcons[75], STATE.spellIcons[3018], STATE.spellIcons[2764], STATE.spellIcons[5019] = 132369, 132222, 135427, 135463
STATE.spellIcons[6603] = 135274
BT.iconCache = nil
local namesWere = BT.db.outNames
local function cast(id) fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-ranged", id) end
SetIcons(true)
BT.db.outNames = true
-- A swing has your main hand weapon's icon, or the game's Attack with nothing in your hands
wound(55, 1)
assertEq(last("outgoing"), "|T135274:0|t 55", "a swing, bare handed: the Attack icon")
STATE.equipped[16] = { name = "Sword", icon = 135321, lines = {} }
Advance(2)
wound(56, 1)
assertEq(last("outgoing"), "|T135321:0|t 56", "with a sword: the sword's icon")
STATE.offSpeed = 1.4
Advance(2)
wound(57, 1)
assertEq(last("outgoing"), "|T135274:0|t 57", "two weapons: which hand isn't known, so the Attack icon")
STATE.offSpeed = nil
wound(0, 1, "DODGE")
assertEq(last("outgoing"), "|T135321:0|t Dodge", "a swing dodged, too")
-- Issue #15: the game's swing timer says which hand swung (PLAYER_SWING's swingType: 0 main,
-- 1 off), so each white hit shows the weapon that made it. The off hand's speed is secret where
-- unit stats are restricted, so the hand comes from the swing, not UnitAttackSpeed.
STATE.equipped[17] = { name = "Dagger", icon = 135641, lines = {} }
fire("PLAYER_EQUIPMENT_CHANGED", 17, true)
BT.hands = nil
Advance(2)
fire("PLAYER_SWING", 2.6, 0)
Advance(0.5)
wound(60, 1)
assertEq(last("outgoing"), "|T135321:0|t 60", "a main hand swing: the sword's icon")
Advance(0.2)
fire("PLAYER_SWING", 1.8, 1)
Advance(0.5)
wound(30, 1)
assertEq(last("outgoing"), "|T135641:0|t 30", "an off hand swing: the dagger's icon, not the sword's")
Advance(0.2)
fire("PLAYER_SWING", 1.8, 1)
Advance(0.4)
fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
assertEq(last("outgoing"), "|T135641:0|t Dodge", "the off hand's swing dodged: the dagger's icon too")
-- Both hands swinging before either lands: the hits come in the order swung
Advance(2)
fire("PLAYER_SWING", 2.6, 0)
Advance(0.1)
fire("PLAYER_SWING", 1.8, 1)
Advance(0.4)
wound(61, 1)
wound(31, 1)
assertEq(table.concat(lines("outgoing"), " / ", #lines("outgoing") - 1), "|T135321:0|t 61 / |T135641:0|t 31",
    "a main hand then an off hand swing: sword, then dagger")
-- A hit on another mob doesn't take your swing's hand (auto attacks only go at your target)
STATE.who.nameplate2 = "mobB"
Advance(2)
fire("PLAYER_SWING", 1.8, 1)
Advance(0.3)
fire("UNIT_COMBAT", "nameplate2", "WOUND", "", 25, 1)
wound(32, 1)
assertEq(last("outgoing"), "|T135641:0|t 32", "the off hand swing is still there for the hit on your target")
STATE.who.nameplate2 = nil
-- No swing to match (it came too long ago): with two weapons, the neutral Attack icon,
-- even though the off hand's speed can't be read (STATE.offSpeed nil)
Advance(2)
wound(62, 1)
assertEq(last("outgoing"), "|T135274:0|t 62", "two weapons, hand not known: the Attack icon")
-- A ranged swing (swingType 2) isn't a hand: it doesn't take the place of the main hand swing after it
fire("PLAYER_SWING", 3.0, 2)
Advance(0.1)
fire("PLAYER_SWING", 2.6, 0)
Advance(0.3)
wound(63, 1)
assertEq(last("outgoing"), "|T135321:0|t 63", "a ranged swing doesn't say a hand")
-- Off hand taken off: back to the main hand's icon
STATE.equipped[17] = nil
fire("PLAYER_EQUIPMENT_CHANGED", 17, false)
Advance(2)
wound(64, 1)
assertEq(last("outgoing"), "|T135321:0|t 64", "one weapon again: the sword's icon")
fire("UNIT_COMBAT", "target", "WOUND", "", 40, 4)
assertEq(last("outgoing"), "40", "a hit nothing named of another school: no icon (not a swing)")
log(swing(27))
assertEq(last("outgoing"), "|T135321:0|t 27", "a swing read from the combat log, too")
-- In Bear or Cat Form a druid fights with claws: the form's icon, not the weapon's
-- (for the form you're in, the game gives the stance bar's "on" star, not the form's icon)
STATE.spellIcons[5487], STATE.spellIcons[768] = 132276, 132115
STATE.form = { icon = 136116, spellId = 5487 }
Advance(2)
wound(28, 1)
assertEq(last("outgoing"), "|T132276:0|t 28", "Bear Form: the form's icon, not the star")
STATE.form = { icon = 136116, spellId = 768 }
Advance(2)
wound(29, 1)
assertEq(last("outgoing"), "|T132115:0|t 29", "Cat Form too")
STATE.form = { icon = 136116, spellId = 24858 }
Advance(2)
wound(30, 1)
assertEq(last("outgoing"), "|T135321:0|t 30", "another form (Moonkin) swings the weapon")
STATE.form = nil
clear()
-- Ranged attacks fly to the target: the hit that lands after one is it
Advance(2)
cast(75)
Advance(0.5)
wound(70, 1)
assertEq(last("outgoing"), "|T132369:0|t Auto Shot 70", "Auto Shot, by name and icon")
Advance(2)
wound(71, 1)
assertEq(last("outgoing"), "|T135321:0|t 71", "one hit for one shot: the next is a swing")
cast(3018)
Advance(0.6)
wound(30, 1, "CRITICAL")
assertEq(last("outgoing"), "|T132222:0|t Shoot 30", "a bow's Shoot")
cast(2764)
Advance(0.6)
wound(0, 1, "DODGE")
assertEq(last("outgoing"), "|T135427:0|t Throw Dodge", "a Throw dodged")
-- A wand's Shoot is of the wand's school: anything but physical
cast(5019)
Advance(0.6)
wound(20, 1)
assertEq(last("outgoing"), "|T135321:0|t 20", "a physical hit isn't the wand's")
fire("UNIT_COMBAT", "target", "WOUND", "", 21, 32)
assertEq(last("outgoing"), "|T135463:0|t Shoot 21", "a shadow wand's")
clear()
-- They're auto attacks: the "Auto attacks" switch hides them with the swings
BT.db.outSwings = false
Advance(2)
cast(75)
Advance(0.5)
wound(72, 1)
wound(57, 1)
assertEq(#lines("outgoing"), 0, "Auto Shot and the swing are hidden")
log(hit("Auto Shot", 75, 44))
assertEq(#lines("outgoing"), 0, "Auto Shot read from the combat log too")
log(hit("Claw", 16827, 50))
assertEq(last("outgoing"), "|T132140:0|t Claw 50", "a spell still shows")
BT.db.outSwings = true
STATE.equipped[16] = nil
STATE.who.nameplate1 = nil
BT.flying = nil
BT.db.merge = true
SetIcons(false)
BT.db.outNames = namesWere
clear()

step("dispels: what you took off, from the Combat Log line or from the cast")
assertEq(BT.DEFAULTS.nDispels, true, "on to start with")
BT.db.nDispels = true
BT.dispelLineAt = nil
clear()
log(real("cleanse a friend"))
assertEq(last("notify"), "Dispelled Corruption", "a debuff taken off a friend, by its name")
log(real("cleanse myself"))
assertEq(last("notify"), "Dispelled Corruption", "and off yourself")
log(real("dispel"))
assertEq(last("notify"), "Purged Power Word: Fortitude", "an enemy's buff")
log(real("spell steal"))
assertEq(last("notify"), "Stole Power Word: Fortitude", "Spellsteal")
local dispelCount = #lines("notify")
log(real("my buff is dispelled"))
assertEq(#lines("notify"), dispelCount, "someone else's dispel isn't yours")
BT.db.nDispels = false
log(real("cleanse a friend"))
assertEq(#lines("notify"), dispelCount, "off: nothing")
BT.db.nDispels = true
local rule = BT:AddSpellRule("Cleanse")
BT:SetSpellRule(rule, "hide", true)
log(real("cleanse a friend"))
assertEq(#lines("notify"), dispelCount, "hidden on the Spells tab: nothing")
BT:RemoveSpellRule(#BT.db.spellRules)
BT.db.nIcons = true
STATE.spellIcons[172] = 136118
log(real("cleanse a friend"))
assert(last("notify"):find("136118", 1, true) and last("notify"):find("Dispelled Corruption$"),
    "with icons on, the icon of what came off: " .. last("notify"))
SetIcons(false)
-- No "Dispelled" lines (the box isn't ticked): the cast shows by itself
BT.dispelLineAt = nil
STATE.spellNames[4987], STATE.spellIcons[4987] = "Cleanse", 135949
clear()
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-dsp1", 4987)
assertEq(#lines("notify"), 0, "the cast waits for its line")
Advance(0.6)
assertEq(last("notify"), "Cleanse", "no line came: the cast shows")
clear()
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-dsp2", 635)
Advance(0.6)
assertEq(#lines("notify"), 0, "a spell that takes nothing off says nothing")
BT.db.nDispels = false
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-dsp3", 4987)
Advance(0.6)
assertEq(#lines("notify"), 0, "off: no cast either")
BT.db.nDispels = true
-- The line comes with the cast: only the line shows, and from then on casts wait for lines
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-dsp4", 4987)
log(real("cleanse a friend"))
Advance(0.6)
assertEq(table.concat(lines("notify"), " / "), "Dispelled Corruption", "the line, not the cast as well")
clear()
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-dsp5", 4987)
Advance(0.6)
assertEq(#lines("notify"), 0, "lines are arriving: a cast with no line took nothing off")
BT.dispelLineAt = nil
clear()

step("ability alerts: Overpower, Revenge, Riposte")
assertEq(BT.DEFAULTS.nAlerts, true, "on to start with")
BT.db.nAlerts = true
BT.reactAt = nil
STATE.class, STATE.level = "WARRIOR", 20
-- Every alert shown since the last clear() (a notification can scroll away before it's looked at)
local shownAlerts = {}
local notifyWas = BT.Notify
BT.Notify = function(self, text, ...)
    if text:find("!$") then shownAlerts[#shownAlerts + 1] = text end
    return notifyWas(self, text, ...)
end
local clearWas = clear
clear = function() clearWas() shownAlerts = {} end
local function alerts() BT:FlushHits(true) return table.concat(shownAlerts, " / ") end
on("target", 0, 1, "DODGE")
assertEq(last("outgoing"), "Dodge", "your attack was dodged")
assertEq(alerts(), "Overpower!", "a warrior is told Overpower is open")
assert(isColor(BT.areas.notify.active[#BT.areas.notify.active], BT.TEXT_COLORS.alert), "in the alerts' color")
assertEq(BT.areas.notify.active[#BT.areas.notify.active].sticky, true, "and it stands out, like a crit")
Advance(0.5)
on("target", 0, 1, "DODGE")
assertEq(alerts(), "Overpower!", "not again straight away")
Advance(0.6)
on("target", 0, 1, "WOUND", "DODGE")
assertEq(alerts(), "Overpower! / Overpower!", "again a moment later")
on("target", 0, 1, "PARRY")
assertEq(alerts(), "Overpower! / Overpower!", "a parry doesn't open Overpower")
clear()
fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
assertEq(alerts(), "Revenge!", "you parried: Revenge")
assertEq(last("incoming"), "Parry", "and the parry still shows")
Advance(1.1)
fire("UNIT_COMBAT", "player", "WOUND", "BLOCK_REDUCED", 20, 1)
assertEq(alerts(), "Revenge! / Revenge!", "a blow you partly blocked: Revenge")
Advance(1.1)
fire("UNIT_COMBAT", "player", "WOUND", "", 20, 1)
fire("UNIT_COMBAT", "player", "MISS", "", 0, 1)
assertEq(alerts(), "Revenge! / Revenge!", "a blow that lands, or misses you, doesn't")
clear()
-- CurseForge (Quarnok, an Arms warrior): "I'm also getting Revenge procs... any thoughts on a
-- way to suppress those?" and "sometimes I'm getting procs when the button is not available"
STATE.spellNames[71], STATE.spellNames[2457] = "Defensive Stance", "Battle Stance"
STATE.spellNames[6572], STATE.spellNames[7384] = "Revenge", "Overpower"
STATE.form = { spellId = 2457 }   -- Battle Stance
Advance(1.1)
fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
assertEq(alerts(), "", "in Battle Stance a parry doesn't say Revenge (it needs Defensive Stance)")
STATE.form = { spellId = 71 }
Advance(1.1)
fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
assertEq(alerts(), "Revenge!", "in Defensive Stance it does")
Advance(1.1)
on("target", 0, 1, "DODGE")
assertEq(alerts(), "Revenge! / Overpower!", "Overpower in any stance (warriors switch to Battle Stance for it)")
clear()
-- Overpower on its cooldown: no alert (the global cooldown doesn't count)
STATE.cooldowns = { Overpower = { startTime = 1, duration = 5, isEnabled = true, isActive = true, modRate = 1 } }
Advance(1.1)
on("target", 0, 1, "DODGE")
assertEq(alerts(), "", "Overpower on its cooldown: no alert")
STATE.cooldowns = { Overpower = { startTime = 1, duration = 1.5, isEnabled = true, isActive = true, isOnGCD = true,
    modRate = 1 } }
Advance(1.1)
on("target", 0, 1, "DODGE")
assertEq(alerts(), "Overpower!", "only the global cooldown: it shows")
STATE.cooldowns = nil
clear()
-- Hidden on the Spells tab: no alert for it, the others still come
BT:AddSpellRule("Revenge")
BT:SetSpellRule(BT:SpellRule("Revenge"), "hide", true)
Advance(1.1)
fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
on("target", 0, 1, "DODGE")
assertEq(alerts(), "Overpower!", "Revenge hidden on the Spells tab: not announced")
BT:RemoveSpellRule(#BT.db.spellRules)
STATE.form = nil
BT.reactAt = nil
Advance(2)
clear()
-- With the combat lines readable, your dodged swing comes from its line
assert(flowing(), "(the combat lines are arriving)")
BT.reactAt = nil
log(real("swing fails: DODGE"))
assertEq(alerts(), "Overpower!", "a dodge in the combat lines")
Advance(2)
clear()
-- Sample text in a fight: its dodge opens nothing, and its numbers aren't the fight's (BT-009)
do
    clear()
    Advance(2)
    BT.fight = { start = GetTime(), damage = 0, heal = 0 }
    SlashCmdList.BATTLETEXTFOREVER("test")
    Advance(4)
    assertEq(alerts(), "Killing blow!", "the sample dodge doesn't say Overpower (the sample killing blow is all)")
    assertEq(BT.fight.damage .. "/" .. BT.fight.heal, "0/0", "and the fight's totals have none of the samples")
    assertEq(BT.fight.spells, nil, "nor its spells")
    BT.fight = nil
    clear()
end
-- Not a warrior, too low a level, or turned off
STATE.level = 10
BT.reactAt = nil
on("target", 0, 1, "DODGE")
assertEq(alerts(), "", "not before Overpower is learned (level 12)")
fire("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
assertEq(alerts(), "", "nor Revenge (level 14)")
STATE.level = 20
BT.db.nAlerts = false
on("target", 0, 1, "DODGE")
assertEq(alerts(), "", "Ability alerts turned off")
BT.db.nAlerts = true
STATE.class = "ROGUE"
Advance(1.1)
on("target", 0, 1, "DODGE")
fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
assertEq(alerts(), "", "a rogue without the talent: nothing")
STATE.knownSpells[14251] = true
Advance(1.1)
fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
assertEq(alerts(), "Riposte!", "with Riposte: when you parry")
fire("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
assertEq(alerts(), "Riposte!", "only a parry")
-- Without the game's deprecation fallbacks there's no IsPlayerSpell: C_SpellBook knows (BT-013)
do
    local isPlayerSpell, spellBook, enum = IsPlayerSpell, C_SpellBook, Enum.SpellBookSpellBank
    local GAME = getmetatable(_G).__index
    GAME.IsPlayerSpell = nil   -- (the game's globals, changed as the game would have them)
    local bank
    GAME.C_SpellBook = { IsSpellKnown = function(id, b) bank = b return STATE.knownSpells[id] == true end }
    Enum.SpellBookSpellBank = { Player = 0, Pet = 1 }
    Advance(1.1)
    fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
    assertEq(alerts(), "Riposte! / Riposte!", "the talent is known from C_SpellBook")
    assertEq(bank, 0, "asked about your own spells")
    GAME.IsPlayerSpell, GAME.C_SpellBook, Enum.SpellBookSpellBank = isPlayerSpell, spellBook, enum
    table.remove(shownAlerts)   -- (the checks below count from before this one)
end
STATE.knownSpells[14251] = nil
STATE.class = "HUNTER"
STATE.knownSpells[19306] = true
Advance(1.1)
fire("UNIT_COMBAT", "player", "PARRY", "", 0, 1)
assertEq(alerts(), "Riposte! / Counterattack!", "a hunter with Counterattack")
STATE.knownSpells[19306] = nil
clear()
-- In a group, a dodge with no line of yours could be anyone's
STATE.class = "WARRIOR"
STATE.group = true
BT.hiddenSeen, BT.hiddenAt, BT.credits, BT.reactAt = true, nil, nil, nil
on("target", 0, 1, "DODGE")
assertEq(alerts(), "", "someone else's attack dodged: no Overpower")
Advance(0.1)
hidden(61)
on("target", 0, 1, "DODGE")
assertEq(alerts(), "Overpower!", "yours, with its line")
STATE.group = false
BT.hiddenSeen, BT.hiddenAt, BT.credits = nil, nil, nil
-- With icons
SetIcons(true)
STATE.spellIcons[7384] = 132223
Advance(1.1)
on("target", 0, 1, "DODGE")
assertEq(last("notify"), "|T132223:0|t Overpower!", "with its icon when icons are on")
SetIcons(false)
STATE.class = "DRUID"
STATE.who.target, STATE.who.nameplate1, STATE.who.nameplate2 = nil, nil, nil
clear()
BT.Notify, clear = notifyWas, clearWas

step("ability alerts: Execute, Hammer of Wrath, lit-up spells")
do
    local shown = {}
    local notifyWas = BT.Notify
    BT.Notify = function(self, text, ...)
        if text:find("!$") then shown[#shown + 1] = text end
        return notifyWas(self, text, ...)
    end
    local function alerts()
        local s = table.concat(shown, " / ")
        shown = {}
        return s
    end
    local function usable(name, yes, noPower) STATE.usable[name] = { yes, noPower or false } end
    local function check() fire("SPELL_UPDATE_USABLE") Advance(0.05) end   -- (looked at once the frame is over)
    BT.reactAt, BT.usableNow, BT.usableLearned = nil, nil, nil
    STATE.class, STATE.level = "WARRIOR", 30
    STATE.unit.mobE = { enemy = true, guid = "Creature-0-1-2-3-100-0000E1", target = "me" }
    STATE.unit.mobF = { enemy = true, guid = "Creature-0-1-2-3-100-0000F1", target = "me" }
    STATE.who.target = "mobE"
    usable("Execute", true)
    check()
    assertEq(alerts(), "", "usable from the start: the game's answer may not depend on the target, so no alert yet")
    usable("Execute", false)
    check()
    assertEq(alerts(), "", "not usable with rage to spare: the target is too healthy")
    usable("Execute", true)
    fire("UNIT_HEALTH", "target") Advance(0.05)
    assertEq(alerts(), "Execute!", "it turns usable: Execute!")
    -- A burst of the game's "usable" events (crafting, bags changing): one look, once the frame is over
    local asked, realUsable = 0, C_Spell.IsSpellUsable
    C_Spell.IsSpellUsable = function(...) asked = asked + 1 return realUsable(...) end
    for _ = 1, 20 do fire("SPELL_UPDATE_USABLE") end
    assertEq(asked, 0, "nothing asked while the burst arrives")
    Advance(0.05)
    assertEq(asked, 1, "one look for twenty events")
    STATE.class = "MAGE"
    asked = 0
    for _ = 1, 20 do fire("SPELL_UPDATE_USABLE") end
    Advance(0.05)
    assertEq(asked, 0, "a class with no such ability isn't asked at all")
    STATE.class = "WARRIOR"
    C_Spell.IsSpellUsable = realUsable
    alerts()
    assert(isColor(BT.areas.notify.active[#BT.areas.notify.active], BT.TEXT_COLORS.alert), "in the alerts' color")
    Advance(2)
    check()
    assertEq(alerts(), "", "once, not every time the game asks")
    usable("Execute", false, true)
    check()
    usable("Execute", true)
    Advance(2)
    check()
    assertEq(alerts(), "", "rage spent and back on the same mob: not again")
    -- A new target that's already low
    Advance(2)
    STATE.who.target = "mobF"
    fire("PLAYER_TARGET_CHANGED") Advance(0.05)
    assertEq(alerts(), "Execute!", "a new target that's already low")
    -- Low, but not enough rage: the alert waits until it can be pressed
    Advance(2)
    STATE.who.target = "mobE"
    usable("Execute", false, true)
    fire("PLAYER_TARGET_CHANGED") Advance(0.05)
    assertEq(alerts(), "", "not enough rage yet")
    usable("Execute", true)
    check()
    assertEq(alerts(), "Execute!", "the rage is there: now")
    -- Not on a friend or nothing, not before level 24, not turned off, not other classes
    Advance(2)
    STATE.who.target = nil
    fire("PLAYER_TARGET_CHANGED") Advance(0.05)
    assertEq(alerts(), "", "no target")
    STATE.unit.friend = { enemy = false, guid = "Player-1-0000F0" }
    STATE.who.target = "friend"
    fire("PLAYER_TARGET_CHANGED") Advance(0.05)
    assertEq(alerts(), "", "a friendly target")
    STATE.who.target = "mobE"
    STATE.level = 20
    fire("PLAYER_TARGET_CHANGED") Advance(0.05)
    assertEq(alerts(), "", "not learned yet (level 24)")
    STATE.level = 30
    BT.db.nAlerts = false
    fire("PLAYER_TARGET_CHANGED") Advance(0.05)
    assertEq(alerts(), "", "Ability alerts turned off")
    BT.db.nAlerts = true
    STATE.class, STATE.level = "PALADIN", 50
    fire("PLAYER_TARGET_CHANGED") Advance(0.05)
    assertEq(alerts(), "", "a paladin has no Execute")
    usable("Hammer of Wrath", false)
    check()
    usable("Hammer of Wrath", true)
    check()
    assertEq(alerts(), "Hammer of Wrath!", "and has Hammer of Wrath")
    -- A hidden answer is no answer
    Advance(2)
    STATE.usable["Hammer of Wrath"] = { Secret(true), Secret(false) }
    fire("PLAYER_TARGET_CHANGED") Advance(0.05)
    assertEq(alerts(), "", "the game hides it: nothing")
    STATE.usable = {}

    -- Procs and lit-up buttons
    STATE.class, STATE.level = "DRUID", 30
    clear()
    shown = {}
    fire("SPELL_ACTIVATION_OVERLAY_SHOW", 16870)
    assertEq(alerts(), "Clearcasting!", "a proc's overlay")
    fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 5221)
    assertEq(alerts(), "", "the button it lights up at the same moment says nothing more")
    Advance(0.5)
    fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 5221)
    assertEq(alerts(), "Shred!", "a button lighting up on its own")
    fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 5221)
    assertEq(alerts(), "", "not twice in a second")
    fire("SPELL_ACTIVATION_OVERLAY_SHOW", Secret(16870))
    fire("SPELL_ACTIVATION_OVERLAY_SHOW", 999999)
    assertEq(alerts(), "", "a hidden or unknown spell: nothing")
    BT.db.nAlerts = false
    Advance(2)
    fire("SPELL_ACTIVATION_OVERLAY_SHOW", 16870)
    assertEq(alerts(), "", "turned off")
    BT.db.nAlerts = true
    -- Procs the game doesn't light up, by the buff they put on you (CurseForge, xnmd: Missile
    -- Barrage, Revelation), when the game lets the buff be read
    STATE.class = "MAGE"
    Advance(2)
    STATE.buffs = {}
    fire("UNIT_AURA", "player")
    assertEq(alerts(), "", "no proc yet")
    STATE.buffs = { { name = "Missile Barrage", spellId = 400589, duration = 15 } }
    fire("UNIT_AURA", "player")
    assertEq(alerts(), "Missile Barrage!", "Missile Barrage comes up")
    Advance(2)
    fire("UNIT_AURA", "player")
    assertEq(alerts(), "", "once while it lasts")
    STATE.buffs = {}
    fire("UNIT_AURA", "player")
    Advance(2)
    STATE.buffs = { { name = "Missile Barrage", spellId = 400589, duration = 15 } }
    fire("UNIT_AURA", "player")
    assertEq(alerts(), "Missile Barrage!", "again once it's been used up")
    -- In a fight: a buff the game hides says nothing (and isn't taken as gone), one it shows does
    STATE.buffs = {}
    fire("UNIT_AURA", "player")
    Advance(2)
    COMBAT, STATE.buffsHidden = true, true
    STATE.buffs = { { name = "Revelation", spellId = 1248806, duration = 15 } }
    fire("UNIT_AURA", "player")
    assertEq(alerts(), "", "a hidden buff: nothing")
    STATE.openBuffs = { Revelation = true }
    fire("UNIT_AURA", "player")
    assertEq(alerts(), "Revelation!", "Revelation, when the game shows it")
    STATE.openBuffs = nil
    Advance(2)
    fire("UNIT_AURA", "player")
    STATE.openBuffs = { Revelation = true }
    fire("UNIT_AURA", "player")
    assertEq(alerts(), "", "hidden for a moment isn't gone: the same Revelation says nothing again")
    STATE.openBuffs = nil
    Advance(2)
    STATE.buffs = { { name = "Missile Barrage", spellId = 400589, duration = 15 } }
    fire("UNIT_AURA", "player")
    assertEq(alerts(), "", "Missile Barrage hidden: nothing")
    -- The fight ends with it still on: it isn't new any more, so nothing
    COMBAT, STATE.buffsHidden = false, false
    fire("UNIT_AURA", "player")
    assertEq(alerts(), "", "not after the fight")
    STATE.buffs = {}
    fire("UNIT_AURA", "player")
    BT.db.nAlerts = false
    Advance(2)
    STATE.buffs = { { name = "Hot Streak", spellId = 48108, duration = 10 } }
    fire("UNIT_AURA", "player")
    assertEq(alerts(), "", "turned off with the other alerts")
    BT.db.nAlerts = true
    STATE.buffs = {}
    fire("UNIT_AURA", "player")
    -- A mage's procs aren't looked for on another class (Revelation, a weapon enchant, is)
    STATE.class = "WARRIOR"
    Advance(2)
    STATE.buffs = { { name = "Hot Streak", spellId = 48108, duration = 10 } }
    fire("UNIT_AURA", "player")
    assertEq(alerts(), "", "a warrior: no Hot Streak")
    STATE.buffs = { { name = "Revelation", spellId = 1248806, duration = 15 } }
    fire("UNIT_AURA", "player")
    assertEq(alerts(), "Revelation!", "but Revelation, on any class")
    STATE.buffs = {}
    fire("UNIT_AURA", "player")
    -- Overpower from a dodge and from its button lighting up: once
    STATE.class, STATE.level = "WARRIOR", 30
    Advance(2)
    fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1)
    BT:FlushHits(true)
    fire("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", 7384)
    assertEq(alerts(), "Overpower!", "a dodge and the button lighting up: one Overpower")
    STATE.class = "DRUID"
    STATE.who.target = nil
    BT.Notify = notifyWas
    clear()
end

step("combo points")
do
    assertEq(BT.DEFAULTS.nCombo, true, "on to start with")
    local function cp(n, kind)
        STATE.combo = n
        fire("UNIT_POWER_UPDATE", "player", kind or "COMBO_POINTS")
        return table.concat(lines("notify"), " / ")
    end
    BT.combo = nil
    assertEq(cp(1), "1 CP", "the first one")
    assert(isColor(BT.areas.notify.active[1], BT.TEXT_COLORS.combo), "in the combo points' color")
    assertEq(cp(2), "1 CP / 2 CP", "the next")
    assertEq(cp(5), "1 CP / 2 CP / 5 CP: Finish it!", "all five: finish it")
    assertEq(BT.areas.notify.active[3].sticky, true, "and that one stands out, like a crit")
    assertEq(cp(0), "1 CP / 2 CP / 5 CP: Finish it!", "spending them shows nothing")
    clear()
    assertEq(cp(1), "1 CP", "building again")
    STATE.combo = 3
    fire("UNIT_POWER_UPDATE", "player", "ENERGY")
    assertEq(table.concat(lines("notify"), " / "), "1 CP", "energy isn't combo points")
    STATE.comboHidden = true
    assertEq(cp(4), "1 CP", "hidden by the game: nothing")
    STATE.comboHidden = nil
    BT.db.nCombo = false
    assertEq(cp(4), "1 CP", "turned off")
    BT.db.nCombo = true
    assertEq(cp(4), "1 CP", "turned back on: the count was kept, so the same 4 doesn't show")
    assertEq(cp(5), "1 CP / 5 CP: Finish it!", "and the next one does")
    -- Back to a target that still has its points: no gain to show (BT-030)
    cp(0)   -- (on another target, with none)
    clear()
    STATE.combo = 3
    fire("PLAYER_TARGET_CHANGED")   -- back to the one with three
    assertEq(cp(3), "", "switching back to points already on a target says nothing")
    assertEq(cp(4), "4 CP", "the next real one does")
    STATE.combo, BT.combo = 0, 0
    clear()
end

step("hide or recolor a spell")
do
    STATE.unit.mobR = { enemy = true, guid = "Creature-0-1-2-3-100-0000R1", target = "me" }
    STATE.who.target = "mobR"
    assertEq(#BT.DEFAULTS.spellRules, 0, "nothing on the list to start with")
    assert(flowing(), "(the combat lines are arriving)")
    local rule = assert(BT:AddSpellRule("  Claw "), "added")
    assertEq(rule.name, "Claw", "without the spaces round it")
    assertEq(select(2, BT:AddSpellRule("claw")), "claw is already on the list", "once only, whatever the case")
    assertEq(select(2, BT:AddSpellRule("   ")), "type a spell's name first", "a name is needed")
    log(hit("Claw", 16827, 50))
    assertEq(last("outgoing"), "Claw 50", "on the list but nothing chosen: as usual")
    BT:SetSpellRule(rule, "hide", true)
    log(hit("Claw", 16827, 51))
    log(swing(30))
    assertEq(table.concat(lines("outgoing"), " / "), "Claw 50 / 30", "hidden: its hits don't show, others do")
    -- From UNIT_COMBAT, named by the cast
    clear()
    BT:SetSpellRule(rule, "hide", false)
    BT:SetSpellRule(rule, "color", { 0.1, 0.2, 0.3 })
    log(hit("Claw", 16827, 52))
    assert(isColor(newest(), { 0.1, 0.2, 0.3 }), "its own color")
    log(hit("Shred", 5221, 70))
    assert(not isColor(newest(), { 0.1, 0.2, 0.3 }), "other spells keep theirs")
    log(hit("Claw", 16827, 1, "Physical", "(Critical)"))
    assert(isColor(newest(), { 0.1, 0.2, 0.3 }), "crits too")
    clear()
    -- A heal
    local heal = assert(BT:AddSpellRule("Healing Touch"))
    BT:SetSpellRule(heal, "hide", true)
    log(healMe("Healing Touch", 5185, 250))
    assertEq(#lines("heal"), 0, "a hidden heal on you")
    -- Hidden hits still count in the fight
    fire("PLAYER_REGEN_DISABLED")
    BT:SetSpellRule(rule, "hide", true)
    log(hit("Claw", 16827, 60))
    log(healMe("Healing Touch", 5185, 100))
    Advance(10)
    fire("PLAYER_REGEN_ENABLED")
    assertEq(last("notify"), "60 damage (6 DPS), 100 healed in 10s", "hidden, but counted in the summary")
    -- Shared with Export and Import, checked on the way in
    local text = BT:ExportSettings()
    local t = assert(BT:ReadSettings(text))
    assertEq(#t.spellRules, 2, "both spells go with the settings")
    assertEq(t.spellRules[1].name .. " " .. tostring(t.spellRules[1].hide) .. " " .. t.spellRules[1].color[3],
        "Claw true 0.3", "with what was chosen")
    local junk = BT.Serialize({ spellRules = { { name = "Fireball", color = { 5, -1, 0.5 } }, { hide = true },
        "Frostbolt", { name = string.rep("x", 80) } } })
    t = assert(BT:ReadSettings("BTF1:" .. junk))
    assertEq(#t.spellRules, 1, "only real entries come in")
    assertEq(table.concat(t.spellRules[1].color, ","), "1,0,0.5", "a color kept to its range")
    assertEq(t.spellRules[1].hide, false, "hide only when it says so")
    -- The Spells tab
    BT:RemoveSpellRule(2)
    BT:RemoveSpellRule(1)
    clear()
    BT:OpenConfig()
    local win = BT.config
    win:ShowTab("spells")
    assertEq(win.spellRows[1] == nil or not win.spellRows[1]:IsShown(), true, "an empty list")
    win.spellBox:SetText("Rake")
    win.spellAdd.__scripts.OnClick(win.spellAdd)
    assertEq(BT.db.spellRules[1].name, "Rake", "typed and added")
    assertEq(win.spellBox:GetText(), "", "the box empties")
    local row = win.spellRows[1]
    assertEq(row.name:GetText(), "Rake", "on the list")
    -- (Tyler's screenshot, 1.40.2: "Usual color" ran under Remove; it stops short of it now)
    assertEq(row.swatch.label.__point == "RIGHT" and row.swatch.label.__rel == row.remove, true,
        "the color label ends at Remove")
    assertEq(row.hide:IsOn(), false, "not hidden yet")
    row.hide.__scripts.OnClick(row.hide)
    assertEq(BT.db.spellRules[1].hide, true, "Hide switched on")
    assertEq(row.hide:IsOn(), true, "and it shows")
    STATE.picked = { 0.4, 0.5, 0.6 }
    row.swatch.__scripts.OnClick(row.swatch, "LeftButton")
    ColorPickerFrame.info.swatchFunc()
    assertEq(table.concat(BT.db.spellRules[1].color, ","), "0.4,0.5,0.6", "a color picked")
    row.swatch.__scripts.OnClick(row.swatch, "RightButton")
    assertEq(BT.db.spellRules[1].color, nil, "right-click: its usual color again")
    win.spellBox:SetText("rake")
    win.spellAdd.__scripts.OnClick(win.spellAdd)
    assertEq(#BT.db.spellRules, 1, "the same spell isn't added twice")
    row.remove.__scripts.OnClick(row.remove)
    assertEq(#BT.db.spellRules, 0, "removed")
    assertEq(row:IsShown(), false, "and off the list")
    for i = 1, 14 do BT:AddSpellRule("Spell " .. i) end
    BT:RefreshConfig()
    assertEq(win.spellRows[14]:IsShown(), true, "a long list scrolls")
    wipe(BT.db.spellRules)
    BT.rulesByName = nil
    BT:RefreshConfig()
    win:Hide()
    STATE.who.target = nil
    clear()
end

step("the last fight, spell by spell")
do
    STATE.unit.mobL = { enemy = true, guid = "Creature-0-1-2-3-100-0000L1", target = "me" }
    STATE.who.target = "mobL"
    BT.lastFight = nil
    local f = BT:OpenLastFight()
    assertEq(f.title:GetText(), "Last fight", "before any fight")
    assert(f.shown[1].note:find("No fight yet", 1, true), "says so")
    f:Hide()
    fire("PLAYER_REGEN_DISABLED")
    log(hit("Claw", 16827, 50, "Physical", "(Critical)"))
    Advance(1)
    log(hit("Claw", 16827, 30))
    log(swing(20))
    BT:ShowUnitHit({ kind = "damage", n = 15, school = 4, unit = "target" }, "hit", nil)   -- a fire hit nothing names
    log(healMe("Healing Touch", 5185, 200))
    Advance(9)
    fire("PLAYER_REGEN_ENABLED")
    local rows, fight = BT:FightBreakdown()
    local got = {}
    for _, r in ipairs(rows) do
        got[#got + 1] = ("%s %d %d %d %d %d%%"):format(r.name, r.hits, r.crits, r.total, r.biggest, r.share)
    end
    assertEq(table.concat(got, " / "), "Claw 2 1 80 50 70% / Auto attack 1 0 20 20 17% / Unnamed Fire 1 0 15 15 13%"
        .. " / Healing Touch 1 0 200 200 100%", "by spell: damage first, biggest first, then heals")
    assertEq(fight.damage, 115, "the fight's damage")
    SlashCmdList.BATTLETEXTFOREVER("last")
    f = BT.lastWindow
    assertEq(f:IsShown(), true, "/btf last opens it")
    assertEq(f.title:GetText(), "Last fight: 115 damage (12 DPS), 200 healed in 10s", "with the fight's line")
    assertEq(#f.shown, 6, "a heading for damage and one for healing, and four spells")
    assertEq(f.rows[2].cells[1]:GetText(), "|T132140:0|t Claw", "the spell, with its icon")
    assertEq(f.rows[2].cells[4]:GetText(), "80", "its total")
    assertEq(f.rows[2].cells[5]:GetText(), "70%", "its share")
    assertEq(f.rows[5].cells[1]:GetText(), "Healing", "heals after damage")
    -- A fight with nothing done keeps the one before
    fire("PLAYER_REGEN_DISABLED")
    Advance(3)
    fire("PLAYER_REGEN_ENABLED")
    assertEq(BT.lastFight, fight, "an empty fight doesn't replace it")
    -- With the summary off, it's still kept
    BT.db.nSummary = false
    fire("PLAYER_REGEN_DISABLED")
    log(swing(40))
    fire("PLAYER_REGEN_ENABLED")
    assertEq(BT.lastFight.damage, 40, "kept with the summary off")
    BT:OpenLastFight()
    assertEq(f.rows[3].cells[1]:IsShown(), false, "fewer rows: the old ones are hidden")
    BT.db.nSummary = true
    f:Hide()
    STATE.who.target = nil
    clear()
end

step("buffs gained and lost")
local INTELLECT = { name = "Arcane Intellect", spellId = 1459, icon = 135932, duration = 1800 }
local MOTW = { name = "Mark of the Wild", spellId = 1126, icon = 136078, duration = 1800 }
SetIcons(true)
STATE.buffs = {}
fire("UNIT_AURA", "player")
clear()
assertEq(BT.db.nBuffs, false, "off to begin with")
STATE.buffs = { INTELLECT }
fire("UNIT_AURA", "player")
assertEq(last("notify"), nil, "nothing while it's off")
BT.db.nBuffs = true
STATE.buffs = { INTELLECT, MOTW }
fire("UNIT_AURA", "player")
assertEq(last("notify"), "|T136078:0|t +Mark of the Wild", "a buff gained, with its icon")
assert(isColor(BT.areas.notify.active[#BT.areas.notify.active], BT.TEXT_COLORS.buff), "in the buffs' color")
STATE.buffs = { MOTW }
fire("UNIT_AURA", "player")
assertEq(last("notify"), "|T135932:0|t -Arcane Intellect", "and one lost")
fire("UNIT_AURA", "player")
assertEq(#lines("notify"), 2, "nothing when nothing changed")
clear()
-- Left out: food and drink, buffs with no time limit, and seals (they have their own lines)
STATE.buffs = { MOTW, { name = "Drink", spellId = 430, duration = 18 }, { name = "Brown Horse", spellId = 458, duration = 0 },
    { name = "Seal of Righteousness", spellId = 21084, duration = 30 } }
fire("UNIT_AURA", "player")
assertEq(table.concat(lines("notify"), " / "), "|T132325:0|t +Seal of Righteousness", "only the seal's own line")
STATE.buffs = { MOTW }
fire("UNIT_AURA", "player")
clear()
-- In a fight the buffs are hidden; what changed shows when it ends
fire("PLAYER_REGEN_DISABLED")
STATE.buffsHidden = true
STATE.buffs = { MOTW, INTELLECT }
fire("UNIT_AURA", "player")
assertEq(#lines("notify"), 1, "nothing in the fight (only +Combat)")
STATE.buffsHidden = false
fire("PLAYER_REGEN_ENABLED")
assertEq(table.concat(lines("notify"), " / "), "+Combat / -Combat / |T135932:0|t +Arcane Intellect", "the fight's changes, once it's over")
clear()
-- A buff you put on yourself in a fight shows as you cast it (the game says it's one);
-- when it ran out shows after the fight
STATE.spellNames[5171], STATE.spellIcons[5171] = "Slice and Dice", 132306
STATE.spellNames[16827] = "Claw"
STATE.buffs = { MOTW, INTELLECT }
fire("UNIT_AURA", "player")
clear()
fire("PLAYER_REGEN_DISABLED")
COMBAT, STATE.buffsHidden = true, true
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-snd", 5171)
assertEq(last("notify"), "|T132306:0|t +Slice and Dice", "Slice and Dice shows in the fight, as it's cast")
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-claw", 16827)
assertEq(last("notify"), "|T132306:0|t +Slice and Dice", "an attack isn't a buff")
STATE.spellNames[4321], STATE.selfBuffs = "Ice Barrier", { [4321] = true }
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-ib", 4321)
assertEq(last("notify"), "+Ice Barrier", "a spell the game calls a buff on you only")
STATE.selfBuffs = nil
COMBAT, STATE.buffsHidden = false, false
fire("PLAYER_REGEN_ENABLED")   -- it ran out during the fight
local ended = table.concat(lines("notify"), " / ")
assert(ended:find("-Slice and Dice", 1, true) and ended:find("-Ice Barrier", 1, true), "and their end shows once the fight is over: " .. ended)
clear()
fire("PLAYER_REGEN_DISABLED")
COMBAT, STATE.buffsHidden = true, true
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-snd2", 5171)
COMBAT, STATE.buffsHidden = false, false
STATE.buffs = { MOTW, INTELLECT, { name = "Slice and Dice", spellId = 5171, icon = 132306, duration = 21 } }
fire("PLAYER_REGEN_ENABLED")   -- still on after the fight
assertEq(table.concat(lines("notify"), " / "), "+Combat / |T132306:0|t +Slice and Dice / -Combat", "no second line for it")
STATE.buffs = { MOTW, INTELLECT }
fire("UNIT_AURA", "player")
assertEq(last("notify"), "|T132306:0|t -Slice and Dice", "and when it runs out out of the fight, that shows")
clear()
-- Without the game's word for it, a buff seen turning up as you cast its spell is learned
STATE.spellNames[1234] = "Battle Trance"
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-bt", 1234)
STATE.buffs = { MOTW, INTELLECT, { name = "Battle Trance", spellId = 1234, duration = 10 } }
fire("UNIT_AURA", "player")
assertEq(BT.db.learnedBuffs["Battle Trance"], true, "learned out of a fight")
STATE.buffs = { MOTW, INTELLECT }
fire("UNIT_AURA", "player")
-- A buff cast on a friend that you happen to get too isn't learned as yours alone (BT-012)
do
    STATE.spellNames[1243] = "Power Word: Fortitude"
    STATE.unit.friendA = STATE.unit.friendA or { enemy = false }
    local was = STATE.who.target
    STATE.who.target = "friendA"
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pwf", 1243)
    STATE.buffs = { MOTW, INTELLECT, { name = "Power Word: Fortitude", spellId = 1243, duration = 1800 } }
    fire("UNIT_AURA", "player")
    assertEq(BT.db.learnedBuffs["Power Word: Fortitude"], nil, "cast with a friend targeted: not learned")
    -- And one learned earlier isn't shown when it's cast on a friend in a fight
    BT.db.learnedBuffs["Power Word: Fortitude"] = true
    clear()
    fire("PLAYER_REGEN_DISABLED")
    COMBAT, STATE.buffsHidden = true, true
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pwf2", 1243)
    assertEq(table.concat(lines("notify"), " / "), "+Combat", "learned, but cast on a friend: not your buff")
    STATE.who.target = was
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pwf3", 1243)
    assertEq(last("notify"), "+Power Word: Fortitude", "with no friend targeted, it is")
    COMBAT, STATE.buffsHidden = false, false
    fire("PLAYER_REGEN_ENABLED")
    BT.db.learnedBuffs["Power Word: Fortitude"] = nil
    STATE.buffs = { MOTW, INTELLECT }
    fire("UNIT_AURA", "player")
    clear()
end
clear()
fire("PLAYER_REGEN_DISABLED")
COMBAT, STATE.buffsHidden = true, true
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-bt2", 1234)
assertEq(last("notify"), "+Battle Trance", "and shown as it's cast in the next fight")
COMBAT, STATE.buffsHidden = false, false
fire("PLAYER_REGEN_ENABLED")
clear()
STATE.buffs = { INTELLECT }
fire("UNIT_AURA", "player")
STATE.buffs = {}
fire("UNIT_AURA", "player")
clear()

-- Dying drops your buffs: no wall of lines
STATE.dead = true
STATE.buffs = {}
fire("UNIT_AURA", "player")
assertEq(#lines("notify"), 0, "nothing when you die")
STATE.dead = false
STATE.buffs = { INTELLECT }
fire("UNIT_AURA", "player")
assertEq(last("notify"), "|T135932:0|t +Arcane Intellect", "buffs after you're back are new again")
STATE.buffs = {}
fire("UNIT_AURA", "player")
BT.db.nBuffs = false
SetIcons(false)
clear()

step("colors, each area's look, short numbers")
BT.db.healArea = true
-- Colors: a change shows on the next line, and Reset puts them back
local colorSwatch
for _, f in ipairs(ALL_FRAMES) do if f.key == "heal" and f.fill then colorSwatch = f end end
assert(colorSwatch, "a swatch for heals")
STATE.picked = { 0.1, 0.2, 0.9 }
colorSwatch.__scripts.OnClick(colorSwatch)
assert(ColorPickerFrame.shown, "clicking it opens the game's color picker")
ColorPickerFrame.info.swatchFunc()
assertEq(BT.db.colors.heal[3], 0.9, "the pick is saved")
fire("UNIT_COMBAT", "player", "HEAL", "", 120, 8)
Advance(0.3)
local healed = BT.areas.heal.active[#BT.areas.heal.active]
assert(isColor(healed, { 0.1, 0.2, 0.9 }), "and a heal shows in it")
ColorPickerFrame.info.cancelFunc()
assertEq(BT.db.colors.heal, nil, "cancel puts back what it was")
assertEq(BT.TEXT_COLORS.heal[2], BT.DEFAULT_COLORS.heal[2], "the starting color")
BT:SetColor("inDamage", 0.5, 0.5, 0.5)
assertEq(BT.TEXT_COLORS.inDamage[1], 0.5, "any color can change")
for _, f in ipairs(ALL_FRAMES) do
    if f.__kind == "Button" and f:GetText() == "Reset colors" and f ~= BT.confirmWindow.yes then f.__scripts.OnClick(f) end
end
assertEq(BT.db.colors.inDamage ~= nil, true, "Reset colors asks first")
assert(BT.confirmWindow.text:GetText():find("text color", 1, true), "what it's asking")
BT.confirmWindow.yes.__scripts.OnClick(BT.confirmWindow.yes)
assertEq(next(BT.db.colors), nil, "Reset colors forgets them all")
assertEq(BT.TEXT_COLORS.inDamage[1], BT.DEFAULT_COLORS.inDamage[1], "back to how they started")
clear()
-- Each area's own size and opacity
BT.db.healSize, BT.db.healAlpha = 50, 40
fire("UNIT_COMBAT", "player", "HEAL", "", 120, 8)
Advance(1)
local healLine = BT.areas.heal.active[#BT.areas.heal.active]
assertEq(healLine.size, math.floor(BT.db.fontSize * 0.5 + 0.5), "the Healing area's text at half size")
assert(healLine.__alpha <= 0.4 + 1e-9, "and at its opacity (got " .. tostring(healLine.__alpha) .. ")")
fire("UNIT_COMBAT", "player", "WOUND", "", 30, 1)
Advance(1)
assertEq(BT.areas.incoming.active[#BT.areas.incoming.active].size, BT.db.fontSize, "other areas keep theirs")
BT.db.healSize, BT.db.healAlpha = 100, 100
clear()
-- Short numbers
BT.db.shortNumbers = true
fire("UNIT_COMBAT", "player", "WOUND", "", 12345, 1)
assertEq(last("incoming"), "-12.3k", "12,345 in short")
fire("UNIT_COMBAT", "player", "WOUND", "", 2000000, 1)
assertEq(last("incoming"), "-2m", "a round million without the .0")
fire("UNIT_COMBAT", "player", "WOUND", "", 9999, 1)
assertEq(last("incoming"), "-9,999", "under ten thousand stays as it is")
BT.db.shortNumbers = false
clear()

step("who you healed")
STATE.who.target = "friend"
STATE.unit.friend.name = "Mage"
local whoN = 0
local function healedWho(...)
    whoN = whoN + 1
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-w-" .. whoN, 5185)
    fire("UNIT_COMBAT", ...)
end
local namesWas, iconsWas = BT.db.healNames, BT.db.healIcons
BT.db.healNames, BT.db.healIcons = false, false
healedWho("target", "HEAL", "", 120, 2)
assertEq(last("heal"), "+120 |cffc9f7ccMage|r", "the name after a heal you do")
STATE.unit.friend.secretName = true
healedWho("target", "HEAL", "", 121, 2)
assertEq(last("heal"), "+121", "a hidden name is left out")
STATE.unit.friend.secretName = nil
-- A heal of yours from a line the game lets you read says who too (BT-029)
do
    local guidWas = STATE.unit.friend.guid
    STATE.unit.friend.guid = "Player-5555-0FRIEND1"
    local FRIEND = "|Hunit:Player-5555-0FRIEND1:Mage|hMage|h"
    if log(ME .. "Your|h |Hspell:5185:0:SPELL_HEAL|h|cffffffffHealing Touch|r|h |Haction:SPELL_HEAL|h|cff7f7f7fhealed|r|h "
            .. FRIEND .. " |cffffffff150|r |cffffffffNature|r. ") then
        assertEq(last("heal"), "+150 |cffc9f7ccMage|r", "a read heal on your target, named")
    else
        error("(the combat lines should be arriving here)")
    end
    STATE.unit.friend.guid = guidWas
end
BT.db.healWho = false
healedWho("target", "HEAL", "", 122, 2)
assertEq(last("heal"), "+122", "and none when it's turned off")
BT.db.healWho = true
STATE.unit.friend.name = nil
STATE.who.target = nil
BT.db.healArea = false
clear()

step("heals on someone else are yours only when you healed them")
-- A player you're targeting heals by some means of their own (the game says "+7" on them, not who did it)
BT.db.healNames, BT.db.healIcons = true, false
STATE.who.target = "friend"
STATE.unit.friend.name = "Invisibly"
fire("UNIT_COMBAT", "target", "HEAL", "", 7, 1)
assertEq(#lines("outgoing") + #lines("heal"), 0, "someone else's heal on your target isn't yours")
-- Your heal-over-time on them: its ticks are yours
fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-r-1", 774)
Advance(3)
fire("UNIT_COMBAT", "target", "HEAL", "", 40, 8)
assertEq(last("outgoing"), "Rejuvenation +40 |cffc9f7ccInvisibly|r", "your Rejuvenation's tick, named")
Advance(0.5)
fire("UNIT_COMBAT", "target", "HEAL", "", 7, 1)
assertEq(last("outgoing"), "Rejuvenation +40 |cffc9f7ccInvisibly|r", "but not another heal between its ticks")
Advance(2.5)
fire("UNIT_COMBAT", "target", "HEAL", "", 41, 1)
assertEq(last("outgoing"), "Rejuvenation +41 |cffc9f7ccInvisibly|r",
    "its tick with Physical as its school (the game doesn't always give a heal its school)")
Advance(3)
fire("UNIT_COMBAT", "target", "HEAL", "", 42, 2)
assert(not tostring(last("outgoing")):find("Rejuvenation +42", 1, true), "a Holy heal on its beat isn't it")
-- Tranquility's heals the same way
do
    local now = GetTime()
    BT.areaOn = { Tranquility = { id = 740, name = "Tranquility", at = now, ends = now + 10, heal = true, school = 8 } }
    assertEq(BT:AreaFor({ kind = "heal", school = 1, time = now + 2 }) ~= nil, true, "Tranquility's heal with Physical")
    assertEq(BT:AreaFor({ kind = "heal", school = 2, time = now + 2 }), nil, "not a Holy one")
    assertEq(BT:AreaFor({ kind = "damage", school = 1, time = now + 2 }), nil, "nor a swing")
    BT.areaOn = nil
end
STATE.unit.friend.name = nil
STATE.who.target = nil
BT.db.healNames, BT.db.healIcons = namesWas, iconsWas
clear()

step("settings for this character only")
assertEq(BT:OwnSettings(), false, "shared settings to begin with")
local shared = BattleTextForeverDB
BT.db.fontSize = 22
BT:SetOwnSettings(true)
assertEq(BattleTextForeverCharDB.own, true, "this character has its own now")
assert(BT.db ~= shared, "in a table of its own")
assertEq(BT.db.fontSize, 22, "starting from a copy of the shared ones")
BT.db.fontSize = 30
assertEq(shared.fontSize, 22, "changing them leaves the shared ones alone")
BT.db.areas.heal.x = 99
assertEq(shared.areas.heal.x, 0, "even inside tables")
BT:SetOwnSettings(false)
assert(BT.db == shared, "turned off: back to the shared ones")
assertEq(BT.db.fontSize, 22, "as they were")
BT:SetOwnSettings(true)
assertEq(BT.db.fontSize, 30, "turning it on again brings back this character's own")
assertEq(BT.db.areas.heal.x, 99, "all of them")
BT:SetOwnSettings(false)
shared.fontSize = 20
BT:ApplySettings()
assertClean("after switching settings")

step("/btf check")
-- Names as Forever has them (from a /btf check in game, 1.8.0)
local periodicNames = BT:SpellLists()
assert(periodicNames["Bane of Agony"], "a warlock's Bane of Agony ticks are known by Forever's name")
assert(BT:SelfBuffList()["Sweeping Strikes"], "Sweeping Strikes is a buff on you only")
LOG = {}
local problems, report = BT:CheckGameData()
assert(#report > 20, "it checks every spell, skill, text and icon (" .. #report .. ")")
local missing = 0
for _, l in ipairs(report) do if l:find("^PROBLEM") then missing = missing + 1 end end
assertEq(problems, missing, "the count matches the report")
assert(table.concat(LOG, "\n"):find("/btf copy", 1, true) or problems == 0, "it says where the full report is")
STATE.missingFiles = { ["Interface\\Icons\\Spell_Holy_Heal"] = true }
local before2 = problems
problems, report = BT:CheckGameData()
assertEq(problems, before2 + 1, "a missing icon is a problem")
assert(table.concat(report, "\n"):find("PROBLEM icon Interface\\Icons\\Spell_Holy_Heal", 1, true), "named in the report")
STATE.missingFiles = nil
assert(BT.recorded and #BT.recorded == #report, "/btf copy shows the report")

step("resting when idle, and nothing left behind")
clear()
Advance(0.1)
assertEq(BT.driver:IsShown(), false, "with no text on screen, the animation rests")
BT:Emit("outgoing", "12", { 1, 1, 1 })
assertEq(BT.driver:IsShown(), true, "a new line wakes it")
Advance(0.5)
assert(BT.areas.outgoing.active[1].__pos[2] < 0, "and the line moves")
clear()
Advance(0.1)
assertEq(BT.driver:IsShown(), false, "it rests again once the line is gone")
-- A line that can be added to is forgotten once it's gone
BT:Emit("outgoing", "Claw 50", { 1, 1, 1 }, { key = "cast:1", amount = 50, format = function(t) return "Claw " .. t end })
assert(BT.areas.outgoing.recent["cast:1"], "remembered while it's showing")
clear()
assertEq(BT.areas.outgoing.recent["cast:1"], nil, "forgotten when it's gone")
-- Damage-over-time spells are forgotten after a fight, mob and all
STATE.unit.mobA = { enemy = true, guid = "Creature-0-1-2-3-100-00000A", target = "me" }
STATE.who.target = "mobA"
BT:OnSpellcast(1822)   -- Rake
assert(BT.dots and BT.dots["Creature-0-1-2-3-100-00000A"], "Rake remembered on the mob")
Advance(50)
fire("PLAYER_REGEN_ENABLED")
assertEq(BT.dots["Creature-0-1-2-3-100-00000A"], nil, "forgotten once it's long over")
STATE.who.target = nil
clear()

step("broken combat log lines")
-- Lines cut short or garbled never cause an error, and plain words aren't hits
local made = 0
for _, entry in ipairs(REAL) do
    local raw = entry.raw
    for cut = 1, #raw, 7 do
        local ok, info = pcall(Parser.Parse, Parser, raw:sub(1, cut))
        assert(ok, "a line cut short doesn't break the parser: " .. tostring(info))
        if info and info.amount ~= nil then assert(type(info.amount) == "number", "an amount is a number") end
        made = made + 1
    end
end
assert(made > 1000, "a good many tried (" .. made .. ")")
for _, junk in ipairs({ "|H", "|Hunit:|h", "|Haction:SPELL_DAMAGE|hhit|h", "|Hspell:abc:0:X|h|h |h", "||||", "|c|r|T|t",
    "You hit nothing for nothing.", string.rep("|Hunit:x|h", 50), "\0\1\2" }) do
    local ok, info = pcall(Parser.Parse, Parser, junk)
    assert(ok, "garbage doesn't break the parser: " .. junk)
    assert(not (info and info.kind == "damage" and info.amount), "and isn't read as a hit: " .. junk)
end

step("each side area lines up left, centered or right")
clear()
assertEq(BT.DEFAULTS.outAlign .. "," .. BT.DEFAULTS.inAlign, "LEFT,RIGHT", "as before to start with")
BT.db.outAlign = "RIGHT"
BT:Emit("outgoing", "12", { 1, 1, 1 })
BT:Emit("outgoing", "34", { 1, 1, 1 }, { crit = true })
local byText = {}
for _, o in ipairs(BT.areas.outgoing.active) do byText[o.text:GetText()] = o end
assertEq(byText["12"].anchor, "RIGHT", "Right: lines line up on the right")
assertEq(byText["12"].text.__justify, "RIGHT", "and the text with them")
assertEq(byText["34"].anchor, "LEFT", "a crit that stays in place, on the other side")
clear()
BT.db.outAlign = "CENTER"
BT:Emit("outgoing", "56", { 1, 1, 1 }, { crit = true })
assertEq(BT.areas.outgoing.active[1].anchor, "CENTER", "Center: crits too")
clear()
BT.db.inAlign = "SIDEWAYS"
BT:Emit("incoming", "-7", { 1, 1, 1 })
assertEq(BT.areas.incoming.active[1].anchor, "RIGHT", "an unknown setting: the area's own")
BT.db.outAlign, BT.db.inAlign = "LEFT", "RIGHT"
clear()

step("fonts other addons share (LibSharedMedia)")
local shared = { ["Avant Garde"] = "Interface\\AddOns\\SomeUI\\Fonts\\AvantGarde.ttf",
    ["Friz Quadrata"] = "Fonts\\FRIZQT__.TTF" }
local callback
local lib = {
    List = function(_, kind)
        if kind == "sound" then return { "None", "Air Horn" } end
        return { "Friz Quadrata", "Avant Garde" }
    end,
    Fetch = function(_, kind, name)
        if kind == "sound" then return name == "Air Horn" and "Interface\\AddOns\\SomeUI\\Sounds\\AirHorn.ogg" or nil end
        return kind == "font" and shared[name] or nil
    end,
    RegisterCallback = function(_, _, fn) callback = fn end,
}
rawset(_G, "LibStub", function(name, silent) return name == "LibSharedMedia-3.0" and lib or nil end)
local before = #BT.FONTS
BT:AddSharedFonts()
assertEq(#BT.FONTS, before + 1, "a shared font is added, one BattleText has already isn't twice")
assertEq(BT.FONTS[#BT.FONTS].name, "Avant Garde", "under the name it's shared as")
local keys = BT.config.fontDropdown.keys
assertEq(keys[#keys], "Avant Garde", "and it's in the font list")
BT.db.font = "Avant Garde"
assertEq(BT:FontPath(), shared["Avant Garde"], "picking it uses that addon's file")
-- And sounds: at the end of the crit and kill sound lists, played from their file
assertEq(BT.SOUNDS[#BT.SOUNDS].name, "Air Horn", "a shared sound is in the sound list")
for _, snd in ipairs(BT.SOUNDS) do assert(snd.key ~= "lsm:None", "LibSharedMedia's \"None\" isn't") end
local soundKeys = BT.config.critSoundDropdown.keys
assertEq(soundKeys[#soundKeys], "lsm:Air Horn", "the crit sound list has it")
assertEq(BT.config.killSoundDropdown.keys[#BT.config.killSoundDropdown.keys], "lsm:Air Horn", "and the kill sound list")
STATE.soundFiles = {}
BT:SetAlertSound("crit", "lsm:Air Horn")
assertEq(STATE.soundFiles[1], "Interface\\AddOns\\SomeUI\\Sounds\\AirHorn.ogg", "picking it plays its file")
BT.db.critSound = BT.DEFAULTS.critSound
table.remove(BT.SOUNDS) table.remove(soundKeys)
shared["Later Font"] = "Interface\\AddOns\\SomeUI\\Fonts\\Later.ttf"
lib.List = function() return { "Avant Garde", "Later Font" } end
callback(nil, "font", "Later Font")
assertEq(BT.FONTS[#BT.FONTS].name, "Later Font", "a font shared later is added when it's shared")
BT.db.font = "Default"
assertEq(BT.config.critFontDropdown.keys[#BT.config.critFontDropdown.keys], "Later Font",
    "the Crit font list has shared fonts too")
while #BT.FONTS > before do
    table.remove(BT.FONTS) table.remove(keys) table.remove(BT.config.critFontDropdown.keys)
end
rawset(_G, "LibStub", nil)
BT.sharedFontsHooked = nil

step("Masque: icons on lines follow the player's Masque skin")
;(function()
clear()
local added = {}
local addedSize
local masqueGroup = { AddButton = function(_, b, regions)
    added[#added + 1] = { b = b, regions = regions }
    addedSize = b.__size and b.__size[1]
end }
local masque = { Group = function(_, addon) masqueGroup.addon = addon return masqueGroup end }
rawset(_G, "LibStub", function(name, silent) return name == "Masque" and masque or nil end)
BT.masque = nil
local blank = "|T" .. BT.ICON_BLANK .. ":0|t"
local o = BT:Emit("outgoing", "+250 |T135920:0|t Holy Light", { 1, 1, 1 })
assertEq(masqueGroup.addon, "BattleText Forever", "one Masque group, under BattleText's name")
assertEq(o.text:GetText(), "+250 " .. blank .. " Holy Light", "the icon in the text is a blank of its size")
assertEq(o.icons[1].Icon.__texture, 135920, "a Masque icon shows the spell's icon instead")
assertEq(o.icons[1]:IsShown(), true, "and it's shown")
local scale = o.fontSize / 36
assertEq(o.icons[1].__pos[1], #"+250 " * 7 / scale, "over the blank: as far in as the text before it is wide (in the icon's scale)")
assertEq(o.icons[1].__size[1], 36, "Masque's own size, when it's added: Masque sizes the skin once, by that")
assertEq(o.icons[1].__scale, scale, "then scaled to the line's font size, so the skin shrinks with it")
assert(addedSize == 36, "the icon is 36 before Masque skins it")
assertEq(#added, 1, "the icon is added to the Masque group")
assertEq(added[1].regions.Icon, o.icons[1].Icon, "with its icon texture as Masque's Icon")
local two = BT:Emit("outgoing", "|T135315:0:0:0:0:64:64:5:59:5:59|t 55 / |T135315:0|t Shadowfang 30", { 1, 1, 1 })
assertEq(two.text:GetText(), blank .. " 55 / " .. blank .. " Shadowfang 30", "every icon in a line, zoomed or not")
assertEq(two.icons[1].__pos[1], 0, "the first at the start")
assertEq(two.icons[2].__pos[1], #(blank .. " 55 / ") * 7 / (two.fontSize / 36), "the second after the text before it")
clear()
local plain
for _ = 1, 4 do plain = BT:Emit("outgoing", "Dodge", { 1, 1, 1 }) end
for _, line in ipairs(BT.areas.outgoing.active) do
    for _, b in ipairs(line.icons or {}) do assertEq(b:IsShown(), false, "a line without icons shows none from before") end
end
local count = #added
BT:Emit("outgoing", "|T132140:0|t Claw 51", { 1, 1, 1 })
assert(#added - count <= 1, "a line from the pool keeps its Masque icons")
clear()
rawset(_G, "LibStub", nil)
BT.masque = nil
local without = BT:Emit("outgoing", "+250 |T135920:0|t Holy Light", { 1, 1, 1 })
assertEq(without.text:GetText(), "+250 |T135920:0|t Holy Light", "without Masque, the icon stays in the text")
clear()
BT.masque = nil
end)()

step("Layout: each kind of text in the area you pick")
clear()
local wasRoutes = {}
for _, r in ipairs(BT.ROUTES) do wasRoutes[r.key] = BT.db["route" .. r.key] end
local healWas = BT.db.healArea
BT.db.healArea = nil
-- To start with: as before
assertEq(BT:Area("OutDamage") .. "," .. BT:Area("InDamage") .. "," .. BT:Area("OutHeals") .. "," .. BT:Area("Notify"),
    "outgoing,incoming,heal,notify", "each in its usual area")
-- The player's own wish: heals with damage, notifications in the Outgoing area
BT.db.routeOutHeals, BT.db.routeInHeals, BT.db.routeNotify = "outgoing", "incoming", "outgoing"
fire("UNIT_COMBAT", "player", "HEAL", "", 120, 2)
Advance(0.3)
assertEq(last("incoming"), "+120", "heals you get, in the Incoming area")
assertEq(#lines("heal"), 0, "none in the Healing area")
BT:Notify("+103 XP", BT.TEXT_COLORS.xp)
assertEq(last("outgoing"), "+103 XP", "notifications where they were sent")
assertEq(#lines("notify"), 0, "and not in their usual area")
fire("UNIT_COMBAT", "player", "WOUND", "", 40, 1)
assertEq(last("incoming"), "-40", "damage you take stays where it was")
clear()
BT.db.routeInDamage = "notify"
fire("UNIT_COMBAT", "player", "WOUND", "", 41, 1)
assertEq(last("notify"), "-41", "any kind can go to any area")
BT.db.routeInDamage = "nowhere"
fire("UNIT_COMBAT", "player", "WOUND", "", 42, 1)
assertEq(last("incoming"), "-42", "an area that doesn't exist: the usual one")
clear()
-- The Layout tab: a dropdown for each kind
local dropdowns = BT.config.routeDropdowns
assertEq(dropdowns.OutDamage:GetText(), "Outgoing (right)", "areas named for where they start")
local menu = openMenu(dropdowns.InPower)
for _, item in ipairs(menu) do if item.text == "Notifications (top)" then item.pick() end end
assertEq(BT.db.routeInPower, "notify", "picking one sets it")
-- An area nothing is sent to: its look greyed out, saying why
BT:RefreshConfig()
for _, f in ipairs(ALL_FRAMES) do
    if f.key == "healSize" then assertEq(f.disabled, true, "the Healing area's look, with nothing sent there") end
end
-- Saved settings from before 1.16.0: "Own area for heals" off becomes heals with damage
local old = { healArea = false }
BT:MoveOldSettings(old)
assertEq(old.routeOutHeals .. "," .. old.routeInHeals, "outgoing,incoming", "the old setting carries over")
assertEq(old.healArea, nil, "and goes")
-- Shared settings: only real areas are taken
BT:ImportSettings('BTF1:{routeOutDamage="notify",routeInDamage="sideways"}')
assertEq(BT.db.routeOutDamage, "notify", "a route is shared")
assertEq(BT.db.routeInDamage, "nowhere", "one to an area that doesn't exist isn't taken")
for k, v in pairs(wasRoutes) do BT.db["route" .. k] = v end
BT.db.healArea = healWas
BT:RefreshConfig()
clear()

local function newestOf(area) BT:FlushHits(true) local a = BT.areas[area].active return a[#a] end
---------------------------------------------------------------------------
step("cooldowns ready: \"Kick ready\" when a spell of yours comes off its cooldown")
do
    clear()
    assertEq(BT.DEFAULTS.nCooldowns, true, "on to start with")
    BT.db.nCooldowns, BT.db.enabled = true, true
    BT.cooling, BT.cdCast = nil, nil
    STATE.spellNames[1766], STATE.spellNames[1752], STATE.spellNames[1784] = "Kick", "Sinister Strike", "Stealth"
    STATE.spellNames[8643] = "Kidney Shot"
    STATE.cooldowns = {}
    local function notifyText()
        local out = {}
        for _, l in ipairs(lines("notify")) do out[#out + 1] = l end
        return table.concat(out, " / ")
    end
    local function cast(id, cd)
        STATE.cooldowns[id] = cd
        fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-cd" .. id, id)
        fire("SPELL_UPDATE_COOLDOWN")
        Advance(0.2)
    end
    -- Kick: a cooldown of its own
    cast(1766, { duration = 10, isEnabled = true, isActive = true, isOnGCD = false })
    Advance(1)
    assertEq(notifyText(), "", "nothing while it's cooling")
    STATE.cooldowns[1766] = nil
    Advance(0.3)
    assertEq(notifyText(), "Kick ready", "Kick ready when it's over")
    assert(isColor(newestOf("notify"), BT.TEXT_COLORS.alert), "in the alerts' color")
    Advance(0.6)
    assertEq(notifyText(), "Kick ready", "once")
    clear()
    -- Only the global cooldown: nothing
    cast(1752, { duration = 1.5, isEnabled = true, isActive = true, isOnGCD = true })
    STATE.cooldowns[1752] = nil
    Advance(1)
    assertEq(notifyText(), "", "a spell with only the global cooldown isn't announced")
    cast(1752, { duration = Secret(1.5), isEnabled = true, isActive = true, isOnGCD = true })
    STATE.cooldowns[1752] = nil
    Advance(1)
    assertEq(notifyText(), "", "nor when the game hides how long the global cooldown is")
    -- A short cooldown: nothing
    cast(1766, { duration = 6, isEnabled = true, isActive = true, isOnGCD = false })
    STATE.cooldowns[1766] = nil
    Advance(1)
    assertEq(notifyText(), "", "nor one shorter than 8 seconds")
    -- In a fight the game hides how long: it's announced all the same
    cast(8643, { duration = Secret(20), startTime = Secret(1), isEnabled = true, isActive = true, isOnGCD = false })
    Advance(19.6)
    assertEq(notifyText(), "", "a hidden length: still cooling")
    STATE.cooldowns[8643] = nil
    Advance(0.3)
    assertEq(notifyText(), "Kidney Shot ready", "and ready when the game says it's over")
    clear()
    -- GitHub #34: in a fight the game hid both isOnGCD and the length of Concussion Blow (12809),
    -- so its cooldown was never watched
    STATE.spellNames[12809] = "Concussion Blow"
    cast(12809, { duration = Secret(45), startTime = Secret(1), isEnabled = true, isActive = true })
    Advance(44.6)
    assertEq(notifyText(), "", "isOnGCD and length hidden: still cooling")
    STATE.cooldowns[12809] = nil
    Advance(0.3)
    assertEq(notifyText(), "Concussion Blow ready", "and ready when it's over (GitHub #34)")
    clear()
    cast(1752, { duration = Secret(1.5), startTime = Secret(1), isEnabled = true, isActive = true })
    Advance(1.1)
    STATE.cooldowns[1752] = nil
    Advance(1)
    assertEq(notifyText(), "", "the global cooldown alone with isOnGCD hidden isn't announced")
    -- CurseForge (1.21.5): "Shoot ready" after every wand shot. Shoot, Auto Shot and Throw repeat
    -- on their own (their cooldown is the weapon's speed, its length hidden in a fight)
    STATE.spellNames[5019], STATE.spellNames[75] = "Shoot", "Auto Shot"
    cast(5019, { duration = Secret(1.6), startTime = Secret(1), isEnabled = true, isActive = true, isOnGCD = false })
    Advance(1.2)
    STATE.cooldowns[5019] = nil
    Advance(0.3)
    cast(5019, { duration = Secret(1.6), startTime = Secret(1), isEnabled = true, isActive = true, isOnGCD = false })
    Advance(1.2)
    STATE.cooldowns[5019] = nil
    Advance(0.3)
    cast(5019, { duration = Secret(1.6), startTime = Secret(1), isEnabled = true, isActive = true, isOnGCD = false })
    Advance(1.2)
    STATE.cooldowns[5019] = nil
    Advance(0.3)
    cast(75, { duration = Secret(2.8), startTime = Secret(1), isEnabled = true, isActive = true, isOnGCD = false })
    Advance(2.6)
    STATE.cooldowns[75] = nil
    Advance(0.3)
    assertEq(notifyText(), "", "no \"Shoot ready\" or \"Auto Shot ready\" after each shot")
    -- Nor any short cooldown whose length the game hides: it's timed from the cast
    STATE.spellNames[9999] = "Quick Jab"
    cast(9999, { duration = Secret(4), startTime = Secret(1), isEnabled = true, isActive = true, isOnGCD = false })
    Advance(3.6)
    STATE.cooldowns[9999] = nil
    Advance(0.3)
    assertEq(notifyText(), "", "a hidden cooldown over within 8 seconds isn't announced")
    -- (a spell the game says repeats on its own isn't watched at all)
    STATE.autoRepeat = { [9998] = true }
    STATE.spellNames[9998] = "Odd Shot"
    cast(9998, { duration = 10, isEnabled = true, isActive = true, isOnGCD = false })
    Advance(9.6)
    STATE.cooldowns[9998] = nil
    Advance(0.3)
    assertEq(notifyText(), "", "an auto repeat spell isn't announced")
    STATE.autoRepeat = nil
    clear()
    -- Held until you come out (Stealth): it starts later
    cast(1784, { duration = 0, isEnabled = false, isActive = false })
    Advance(3)
    assertEq(notifyText(), "", "held: not ready while it hasn't started")
    STATE.cooldowns[1784] = { duration = 0, isEnabled = true, isActive = false }
    Advance(0.3)
    assertEq(notifyText(), "", "nor as it's let go, before it has started")
    STATE.cooldowns[1784] = { duration = 0, isEnabled = false, isActive = false }
    Advance(0.3)
    STATE.cooldowns[1784] = { duration = 10, isEnabled = true, isActive = true, isOnGCD = false }
    Advance(2)
    assertEq(notifyText(), "", "started: cooling")
    STATE.cooldowns[1784] = nil
    Advance(0.3)
    assertEq(notifyText(), "Stealth ready", "ready when it's over")
    clear()
    -- Hidden on the Spells tab, or turned off
    BT.db.spellRules = { { name = "Kick", hide = true } }
    BT.rulesByName = nil
    cast(1766, { duration = 10, isEnabled = true, isActive = true, isOnGCD = false })
    STATE.cooldowns[1766] = nil
    Advance(0.5)
    assertEq(notifyText(), "", "a spell hidden on the Spells tab")
    BT.db.spellRules = {}
    BT.rulesByName = nil
    BT.db.nCooldowns = false
    cast(1766, { duration = 10, isEnabled = true, isActive = true, isOnGCD = false })
    STATE.cooldowns[1766] = nil
    Advance(0.5)
    assertEq(notifyText(), "", "Cooldowns ready turned off")
    BT.db.nCooldowns = true
    STATE.cooldowns = nil
    clear()
end

---------------------------------------------------------------------------
step("interrupts: \"Interrupted Frostbolt\" when you stop an enemy's cast")
do
    clear()
    assertEq(BT.DEFAULTS.nInterrupts, true, "on to start with")
    BT.db.nInterrupts = true
    BT.kick, BT.interrupted = nil, nil
    STATE.spellNames[1766] = "Kick"
    local whoWas, unitWas, petWas = STATE.who, STATE.unit, STATE.pet
    STATE.who = { target = "caster", nameplate4 = "caster", nameplate5 = "other" }
    STATE.unit = { caster = { enemy = true, guid = "Creature-0-1-2-3-4-000099" },
        other = { enemy = true, guid = "Creature-0-1-2-3-4-000098" } }
    local ME_GUID = "Player-5555-0ABCDEF1"
    local function said()
        local out = {}
        for _, l in ipairs(lines("notify")) do out[#out + 1] = l end
        return table.concat(out, " / ")
    end
    fire("UNIT_SPELLCAST_INTERRUPTED", "target", "Cast-c1", 116, ME_GUID)
    fire("UNIT_SPELLCAST_INTERRUPTED", "nameplate4", "Cast-c1", 116, ME_GUID)
    assertEq(said(), "Interrupted Frostbolt", "yours, shown once though the game says it for each name")
    assertEq(newestOf("notify").sticky, true, "and it stands out")
    fire("UNIT_SPELLCAST_INTERRUPTED", "nameplate5", "Cast-c2", 116, "Player-5555-0FFFFFF2")
    assertEq(said(), "Interrupted Frostbolt", "someone else's interrupt isn't shown")
    fire("UNIT_SPELLCAST_INTERRUPTED", "player", "Cast-c3", 116, "Creature-0-1-2-3-4-000099")
    assertEq(said(), "Interrupted Frostbolt", "your own cast being stopped isn't")
    clear()
    -- Your pet's
    STATE.pet = true
    fire("UNIT_SPELLCAST_INTERRUPTED", "target", "Cast-c4", 116, "Pet-0-1-2-3-4-000002")
    assertEq(said(), "(Pet) Interrupted Frostbolt", "your pet's interrupt")
    STATE.pet = petWas
    clear()
    -- The game hides who: an interrupt of yours just before your target's cast stopped
    fire("UNIT_SPELLCAST_INTERRUPTED", "target", "Cast-c5", 116, Secret(ME_GUID))
    assertEq(said(), "", "hidden, with no interrupt of yours: nothing")
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-k5", 1766)
    Advance(0.1)
    fire("UNIT_SPELLCAST_INTERRUPTED", "nameplate5", "Cast-c6", 116, Secret(ME_GUID))
    assertEq(said(), "", "hidden, on a mob that isn't your target: nothing")
    fire("UNIT_SPELLCAST_INTERRUPTED", "target", "Cast-c7", 116, Secret(ME_GUID))
    assertEq(said(), "Interrupted Frostbolt", "hidden, just after your Kick: yours")
    clear()
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-k8", 1766)
    Advance(0.8)
    fire("UNIT_SPELLCAST_INTERRUPTED", "target", "Cast-c8", Secret(116), nil)
    assertEq(said(), "", "too long after your Kick")
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-k9", 1766)
    fire("UNIT_SPELLCAST_INTERRUPTED", "target", Secret("Cast-c9"), Secret(116), nil)
    assertEq(said(), "Interrupted!", "the stopped spell hidden too: just Interrupted!")
    clear()
    BT.db.nInterrupts = false
    fire("UNIT_SPELLCAST_INTERRUPTED", "target", "Cast-c10", 116, ME_GUID)
    assertEq(said(), "", "Interrupts turned off")
    BT.db.nInterrupts = true
    STATE.who, STATE.unit = whoWas, unitWas
    clear()
end

---------------------------------------------------------------------------
step("smallest crit: a small crit shows as a normal line")
do
    clear()
    assertEq(BT.DEFAULTS.minCrit, 0, "off to start with: every crit stands out")
    BT.db.minCrit, BT.db.sticky = 100, true
    fire("UNIT_COMBAT", "player", "WOUND", "CRITICAL", 40, 1)
    local small = newestOf("incoming")
    assertEq(small.sticky, false, "a crit for 40 doesn't hold in place")
    fire("UNIT_COMBAT", "player", "WOUND", "CRITICAL", 150, 1)
    assertEq(newestOf("incoming").sticky, true, "a crit for 150 still does")
    assert(newestOf("incoming").size > small.size, "and is bigger")
    fire("UNIT_COMBAT", "player", "WOUND", "CRITICAL", Secret(40), 1)
    assertEq(newestOf("incoming").sticky, true, "a hidden number keeps the crit's look")
    clear()
    -- No crit sound for a small one
    BT.db.soundCrit = true
    STATE.sounds = {}
    BT.alertAt = nil
    BT:ShowCombat({ kind = "damage", fromMe = true, event = "SPELL_DAMAGE", spell = "Claw", spellId = 1082,
        amount = 40, crit = true })
    assertEq(#STATE.sounds, 0, "a small crit plays no crit sound")
    Advance(1)
    BT:ShowCombat({ kind = "damage", fromMe = true, event = "SPELL_DAMAGE", spell = "Claw", spellId = 1082,
        amount = 150, crit = true })
    assertEq(#STATE.sounds, 1, "a big one does")
    BT.db.soundCrit, BT.db.minCrit = false, 0
    clear()
end

---------------------------------------------------------------------------
step("Holy Shock heals while the lines flow (a CurseForge comment: 9 in 10 went missing)")
do
    clear()
    local whoWas, unitWas, helpfulWas = STATE.who, STATE.unit, STATE.helpful
    STATE.who = { target = "friend" }
    STATE.unit = { friend = { guid = "Player-5555-0FRIEND1" }, ally = { guid = "Player-5555-0FRIEND2" },
        mob = { enemy = true, guid = "Creature-0-1-2-3-4-000097", target = "me" } }
    STATE.group = false
    STATE.spellNames[1311606], STATE.spellIcons[1311606] = "Holy Shock", 135972
    STATE.spellNames[9999901], STATE.spellIcons[9999901] = "Holy Shock", 135972   -- (the heal the server casts for it: its ID on Forever isn't known)
    STATE.helpful = { [9999901] = true }
    BT.db.healNames, BT.db.healIcons, BT.db.healWho, BT.db.healArea = true, false, false, false
    BT.hiddenSeen, BT.hiddenAt, BT.credits = true, GetTime(), {}
    Advance(1)
    -- Holy Shock's cast, and the heal the server casts for it, in the frame its heal lands
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hs1", 1311606)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hs2", 9999901)
    hidden(31)
    fire("UNIT_COMBAT", "target", "HEAL", "", 112, 2)
    assertEq(last("outgoing"), "Holy Shock +112", "the cast and its heal share a name: one cast, and the heal is named")
    Advance(1)
    -- The heal a frame after the cast
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hs3", 1311606)
    Advance(0.05)
    hidden(32)
    fire("UNIT_COMBAT", "target", "HEAL", "", 114, 2)
    assertEq(last("outgoing"), "Holy Shock +114", "a heal a moment after your cast on that friend is still yours")
    Advance(1)
    fire("UNIT_COMBAT", "target", "HEAL", "", 7, 1)
    assertEq(last("outgoing"), "Holy Shock +114", "but not someone else's heal on them later")
    -- On an enemy it hurts: the two casts are still one, and its hit is named
    STATE.who.target = "mob"
    Advance(1)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hs4", 1311606)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hs5", 9999901)
    hidden(33)
    fire("UNIT_COMBAT", "target", "WOUND", "", 133, 2)
    assertEq(last("outgoing"), "Holy Shock 133", "Holy Shock's damage, named")
    fire("UNIT_COMBAT", "player", "HEAL", "", 50, 2)
    Advance(0.3)
    assertEq(last("incoming"), "+50", "and someone's heal on you then isn't your Holy Shock")
    -- On yourself (no friend targeted): the game may not call it helpful, it's still your heal
    STATE.who.target = nil
    STATE.helpful = {}
    Advance(1)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hs6", 1311606)
    fire("UNIT_COMBAT", "player", "HEAL", "", 116, 2)
    Advance(0.3)
    assertEq(last("incoming"), "+116 Holy Shock", "Holy Shock on yourself, named")
    clear()

    -- Light's Vigil: on a party member, then your Holy Shock on them heals them and their party
    STATE.helpful = { [9999901] = true, [1310911] = true }
    STATE.spellNames[1310911], STATE.spellIcons[1310911] = "Light's Vigil", 236251
    STATE.group, STATE.who = true, { target = "friend", party1 = "friend", party2 = "ally" }
    BT.hiddenSeen, BT.hiddenAt, BT.credits = true, GetTime(), {}
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-lv1", 1310911)
    fire("UNIT_COMBAT", "player", "HEAL", "", 40, 2)
    Advance(0.3)
    assertEq(last("incoming"), "+40", "Light's Vigil heals nothing as it's cast")
    Advance(5)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hs7", 1311606)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hs8", 9999901)
    hidden(34) fire("UNIT_COMBAT", "target", "HEAL", "", 115, 2)
    fire("UNIT_COMBAT", "party1", "HEAL", "", 115, 2)   -- (the same heal under its other name)
    hidden(35) fire("UNIT_COMBAT", "target", "HEAL", "", 330, 2)
    hidden(36) fire("UNIT_COMBAT", "party2", "HEAL", "", 331, 2)
    fire("UNIT_COMBAT", "player", "HEAL", "", 332, 2)
    Advance(0.3)
    assertEq(table.concat(lines("outgoing"), " / "), "Holy Shock +115 / Light's Vigil +330 / Light's Vigil +331",
        "Holy Shock's heal, then the Vigil's on them and on the rest of the party")
    assertEq(last("incoming"), "+332 Light's Vigil", "and on you")
    Advance(1)
    fire("UNIT_COMBAT", "party2", "HEAL", "", 333, 2)
    assertEq(last("outgoing"), "Light's Vigil +331", "a heal on the party later is someone else's")
    clear()
    -- The Vigil is set off only by your Holy Shock on the one who has it
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-lv2", 1310911)
    Advance(2)
    STATE.who.target = "ally"
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hs9", 1311606)
    hidden(37) fire("UNIT_COMBAT", "target", "HEAL", "", 117, 2)
    fire("UNIT_COMBAT", "party2", "HEAL", "", 117, 2)
    fire("UNIT_COMBAT", "party1", "HEAL", "", 334, 2)
    assertEq(table.concat(lines("outgoing"), " / "), "Holy Shock +117",
        "a Holy Shock on someone else leaves the Vigil waiting, and a heal on its friend isn't yours")
    STATE.group = false
    STATE.who, STATE.unit, STATE.helpful = whoWas, unitWas, helpfulWas
    BT.db.healWho = true
    clear()
end

---------------------------------------------------------------------------
step("Life Tap: the health it costs and the mana it gives (issue #26)")
do
    -- The game sends only the cast: no combat log line, no UNIT_COMBAT. The mana is read off the bar.
    local function tap(id) fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-lt", id or 1456) end
    local function mana(n) STATE.mana = n fire("UNIT_POWER_UPDATE", "player", "MANA") end
    STATE.spellNames[1456], STATE.spellNames[11689] = "Life Tap", "Life Tap"
    STATE.mana, STATE.manaMax = 500, 2000
    fire("UNIT_POWER_UPDATE", "player", "MANA")
    local powerWas = BT.db.inPower
    BT.db.inPower = true
    clear()
    Advance(1)
    tap()
    mana(700)
    assertEq(table.concat(lines("incoming"), " / "), "-200 Life Tap / +200 Mana Life Tap",
        "the mana it gave, and the same in health")
    clear()
    -- The mana can come in just before the cast's event, in the same frame
    Advance(1)
    mana(900)
    tap(11689)
    assertEq(table.concat(lines("incoming"), " / "), "-200 Life Tap / +200 Mana Life Tap", "either way round")
    clear()
    -- Or a moment after
    Advance(1)
    tap()
    Advance(0.2)
    mana(1100)
    assertEq(table.concat(lines("incoming"), " / "), "-200 Life Tap / +200 Mana Life Tap", "a frame or two late")
    clear()
    -- Or well after it, the server being slow (1.27.0 waited only 0.5s: issue #26, no mana in game)
    Advance(1)
    tap()
    Advance(1.1)
    mana(1150)
    assertEq(table.concat(lines("incoming"), " / "), "-50 Life Tap / +50 Mana Life Tap", "a second late")
    clear()
    -- Or a few frames before the cast's own event
    Advance(1)
    mana(1300)
    Advance(0.15)
    tap()
    assertEq(table.concat(lines("incoming"), " / "), "-150 Life Tap / +150 Mana Life Tap", "the mana ahead of the cast")
    clear()
    -- With no mana event at all, the bar itself is read
    Advance(1)
    tap()
    STATE.mana = 1350
    Advance(0.3)
    assertEq(table.concat(lines("incoming"), " / "), "-50 Life Tap / +50 Mana Life Tap", "no event: the bar says")
    mana(1350)
    clear()
    -- The game's quicker mana event counts too
    Advance(1)
    tap()
    STATE.mana = 1400
    fire("UNIT_POWER_FREQUENT", "player", "MANA")
    assertEq(table.concat(lines("incoming"), " / "), "-50 Life Tap / +50 Mana Life Tap", "UNIT_POWER_FREQUENT")
    mana(1350)
    clear()
    -- /btf debug writes down what the mana did around it
    BT.db.debug, BT.recorded = true, {}
    Advance(1)
    tap()
    Advance(0.2)
    mana(1400)
    local said = table.concat(BT.recorded, " | ")
    assert(said:find("LIFE TAP mana 1350/2000", 1, true), said)
    assert(said:find("MANA 1350 -> 1400", 1, true), said)
    assert(said:find("LIFE TAP mana event: mana 50", 1, true), said)
    BT.db.debug, BT.recorded = false, {}
    mana(1300)
    clear()
    -- Regen and drinking aren't Life Tap
    Advance(1)
    mana(1150)
    Advance(1)
    tap()
    Advance(2)
    mana(1200)
    assertEq(table.concat(lines("incoming"), " / "), "", "mana long before or after it isn't its")
    clear()
    -- Mana nearly full: the gain is cut short, so the health is the description's number
    STATE.spellDescriptions[1456] = "Converts 200 health into 200 mana."
    mana(1900)
    Advance(1)
    tap()
    mana(2000)
    assertEq(table.concat(lines("incoming"), " / "), "-200 Life Tap / +100 Mana Life Tap", "capped at full mana")
    clear()
    -- Already full: no mana, but the health still went
    Advance(1)
    tap()
    Advance(2)
    assertEq(table.concat(lines("incoming"), " / "), "-200 Life Tap", "full mana: only the health")
    clear()
    -- ...and with no description to read, nothing is made up
    STATE.spellDescriptions[1456] = nil
    tap()
    Advance(2)
    assertEq(table.concat(lines("incoming"), " / "), "", "no number to show")
    -- Hidden mana (as in game, issue #26: "LIFE TAP mana hidden" on every cast): the description
    -- says both, right away
    mana(1000)
    Advance(1)
    STATE.manaHidden = true
    STATE.spellDescriptions[1456] = "Converts |cffffffff315|r health into |cffffffff315|r mana."
    tap()
    assertEq(table.concat(lines("incoming"), " / "), "-315 Life Tap / +315 Mana Life Tap",
        "while the game hides your mana")
    mana(1200)
    Advance(2)
    assertEq(table.concat(lines("incoming"), " / "), "-315 Life Tap / +315 Mana Life Tap", "and only once")
    clear()
    STATE.spellDescriptions[1456] = nil
    tap()
    Advance(2)
    assertEq(table.concat(lines("incoming"), " / "), "", "hidden and no description: nothing made up")
    STATE.manaHidden = nil
    mana(1200)
    -- Power gains off (as it starts): only the health
    BT.db.inPower = false
    Advance(1)
    tap()
    mana(1400)
    assertEq(table.concat(lines("incoming"), " / "), "-200 Life Tap", "the mana follows Power gains")
    clear()
    -- If the game does send its own line for the mana, that one shows instead
    BT.db.inPower = true
    Advance(1)
    tap()
    fire("UNIT_COMBAT", "player", "ENERGIZE", "", 200, 0)
    mana(1600)
    assertEq(table.concat(lines("incoming"), " / "), "+200 / -200 Life Tap", "not twice")
    BT.db.inPower = powerWas
    STATE.spellNames[1456], STATE.spellNames[11689] = nil, nil
    STATE.mana, STATE.manaMax = 1000, 1000
    fire("UNIT_POWER_UPDATE", "player", "MANA")
    clear()
end

---------------------------------------------------------------------------
step("Penance and Renew on a friend in a group (issue #29)")
do
    clear()
    local whoWas, unitWas, groupWas = STATE.who, STATE.unit, STATE.group
    STATE.who = { target = "friend", softfriend = "friend", nameplate1 = "mob" }
    STATE.unit = { friend = { guid = "Player-5555-0FRIEND1" },
        mob = { enemy = true, guid = "Creature-0-1-2-3-4-000129", target = "me" } }
    STATE.group = true
    STATE.spellNames[6077], STATE.spellIcons[6077] = "Renew", 135953
    STATE.spellNames[402174], STATE.spellIcons[402174] = "Penance", 237545
    STATE.spellNames[402289], STATE.spellIcons[402289] = "Penance", 237545
    BT.db.healNames, BT.db.healIcons, BT.db.healWho, BT.db.healArea = true, false, false, false
    BT.hiddenSeen, BT.hiddenAt, BT.credits = true, GetTime(), {}
    BT.areaOn, BT.dots = nil, nil
    Advance(1)
    -- Renew on the friend; its tick lands in the same frame as a party member's hit on a mob
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-rn1", 6077)
    hidden(40)
    Advance(3)
    fire("UNIT_COMBAT", "nameplate1", "WOUND", "", 70, 1)
    fire("UNIT_COMBAT", "target", "HEAL", "", 45, 1)
    fire("UNIT_COMBAT", "softfriend", "HEAL", "", 45, 1)
    hidden(41)
    Advance(0.3)
    assertEq(table.concat(lines("outgoing"), " / "), "Renew +45",
        "the tick takes its line first: the party member's hit isn't yours, your Renew is")
    -- The next tick's line comes a frame late: it still vouches for the tick
    Advance(2.7)
    fire("UNIT_COMBAT", "target", "HEAL", "", 46, 1)
    Advance(0.02)
    hidden(47)
    Advance(0.3)
    assertEq(last("outgoing"), "Renew +46", "a tick whose line comes a frame late")
    -- With no line with it (only an older one, of something else), a heal on the beat isn't yours
    Advance(2.18)
    hidden(48)
    Advance(0.5)
    fire("UNIT_COMBAT", "target", "HEAL", "", 47, 1)
    Advance(0.3)
    assert(not table.concat(lines("outgoing"), " / "):find("+47", 1, true),
        "a heal on the beat with no line of yours isn't your tick")
    clear()
    -- Penance on the friend: two casts of the same name, its heals land a moment later and each second
    Advance(5)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn1", 402174)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn2", 402289)
    hidden(42)
    Advance(0.34)
    fire("UNIT_COMBAT", "target", "HEAL", "", 50, 1)
    fire("UNIT_COMBAT", "softfriend", "HEAL", "", 50, 1)
    hidden(43)
    Advance(1)
    fire("UNIT_COMBAT", "target", "HEAL", "", 51, 2)
    hidden(44)
    Advance(1)
    fire("UNIT_COMBAT", "target", "HEAL", "", 52, 1)
    hidden(45)
    Advance(0.3)
    assertEq(table.concat(lines("outgoing"), " / "), "Penance +50 / Penance +51 / Penance +52", "Penance's heals, named")
    clear()
    -- Long after the channel, someone else's heal on the friend isn't yours
    Advance(4)
    fire("UNIT_COMBAT", "target", "HEAL", "", 60, 1)
    Advance(0.3)
    assertEq(#lines("outgoing"), 0, "nor is a heal after Penance has ended")
    -- On an enemy it hurts
    STATE.who = { target = "mob", nameplate1 = "mob" }
    Advance(2)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn3", 402174)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn4", 402289)
    Advance(0.3)
    fire("UNIT_COMBAT", "target", "WOUND", "", 80, 2)
    hidden(46)
    Advance(0.3)
    assertEq(last("outgoing"), "Penance 80", "Penance's damage, named")
    clear()
    -- On yourself (nothing targeted): its heals on you are named
    STATE.who = {}
    STATE.group = false
    Advance(4)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn5", 402174)
    Advance(0.35)
    fire("UNIT_COMBAT", "player", "HEAL", "", 55, 1)
    Advance(0.3)
    assertEq(last("incoming"), "+55 Penance", "Penance on yourself, named")
    Advance(4)
    fire("UNIT_COMBAT", "player", "HEAL", "", 56, 1)
    Advance(0.3)
    assertEq(last("incoming"), "+56", "and not a heal on you after it ended")
    STATE.who, STATE.unit, STATE.group = whoWas, unitWas, groupWas
    BT.areaOn, BT.dots = nil, nil
    clear()
end

step("heals cast with a mouseover macro (CurseForge: Renew, Penance, Prayer of Mending)")
;(function()   -- (a function: the file is near Lua's limit of locals)
    clear()
    local whoWas, unitWas, groupWas = STATE.who, STATE.unit, STATE.group
    -- A boss targeted; the healer heals the party with the mouse over their frames
    STATE.who = { target = "mob", nameplate1 = "mob", party1 = "friend", party2 = "buddy" }
    STATE.unit = { friend = { guid = "Player-5555-0FRIEND1", name = "Friendo" },
        buddy = { guid = "Player-5555-0BUDDY01", name = "Buddy" },
        mob = { enemy = true, guid = "Creature-0-1-2-3-4-000129", target = "friend", name = "Boss" } }
    STATE.group = true
    STATE.spellNames[6077], STATE.spellIcons[6077] = "Renew", 135953
    STATE.spellNames[402174], STATE.spellIcons[402174] = "Penance", 237545
    STATE.spellNames[402289], STATE.spellIcons[402289] = "Penance", 237545
    STATE.spellNames[33076], STATE.spellIcons[33076] = "Prayer of Mending", 135944
    STATE.spellNames[2061], STATE.spellIcons[2061] = "Flash Heal", 135907
    BT.db.healNames, BT.db.healIcons, BT.db.healWho, BT.db.healArea = true, false, false, false
    BT.hiddenSeen, BT.hiddenAt, BT.credits = true, GetTime(), {}
    BT.areaOn, BT.dots, BT.selfHots, BT.mending, BT.sent = nil, nil, nil, nil, nil
    local function mouse(id) STATE.who.mouseover = id end
    local function sent(name, id) fire("UNIT_SPELLCAST_SENT", "player", name, "Cast-s" .. id, id) end
    Advance(1)
    -- Renew on the friend under the mouse: the mouse has moved on when it finishes (an instant here)
    mouse("friend")
    sent("Friendo", 6077)
    mouse(nil)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-rn1", 6077)
    hidden(40)
    assertEq(BT.selfHots and BT.selfHots.Renew, nil, "it isn't taken as a Renew on yourself")
    Advance(3)
    fire("UNIT_COMBAT", "party1", "HEAL", "", 45, 2)
    hidden(41)
    Advance(0.3)
    assertEq(last("outgoing"), "Renew +45", "its tick on the friend is yours, named")
    Advance(2.7)
    fire("UNIT_COMBAT", "player", "HEAL", "", 30, 2)
    Advance(0.3)
    assertEq(last("incoming"), "+30", "and a heal on you on its beat isn't your Renew")
    clear()
    -- Penance on the friend under the mouse, with the boss targeted: heals, not damage
    Advance(2)
    mouse("friend")
    sent("Friendo", 402174)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn1", 402174)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn2", 402289)
    mouse(nil)
    hidden(42)
    Advance(0.34)
    fire("UNIT_COMBAT", "party1", "HEAL", "", 50, 2)
    hidden(43)
    Advance(1)
    fire("UNIT_COMBAT", "party1", "HEAL", "", 51, 2)
    hidden(44)
    Advance(0.3)
    assertEq(table.concat(lines("outgoing"), " / "), "Penance +50 / Penance +51", "Penance's heals on the friend, named")
    Advance(0.3)
    fire("UNIT_COMBAT", "player", "HEAL", "", 20, 2)
    Advance(0.3)
    assertEq(last("incoming"), "+20", "and it isn't healing you")
    clear()
    -- A friend targeted, the mouse over another: the cast goes where the game says, to the mouse's
    STATE.who.target = "buddy"
    Advance(2)
    mouse("friend")
    sent("Friendo", 6077)
    mouse(nil)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-rn2", 6077)
    hidden(45)
    Advance(3)
    fire("UNIT_COMBAT", "target", "HEAL", "", 60, 2)
    fire("UNIT_COMBAT", "party2", "HEAL", "", 60, 2)
    Advance(0.3)
    assert(not table.concat(lines("outgoing"), " / "):find("Renew", 1, true), "a heal on your target isn't that Renew")
    clear()
    -- The game hides names: a friend under the mouse while a boss is targeted is who it went to
    STATE.who.target = "mob"
    BT.dots = nil
    Advance(2)
    mouse("buddy")
    sent(Secret("Buddy"), 6077)
    mouse(nil)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-rn3", 6077)
    hidden(46)
    Advance(3)
    fire("UNIT_COMBAT", "party2", "HEAL", "", 47, 2)
    hidden(47)
    Advance(0.3)
    assertEq(last("outgoing"), "Renew +47", "with the name hidden, the friend under the mouse")
    clear()
    -- A spell sent to no one (an empty name) and no friend targeted: on you, as before
    BT.dots, BT.selfHots = nil, nil
    Advance(2)
    mouse("friend")
    sent("", 6077)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-rn4", 6077)
    mouse(nil)
    assert(BT.selfHots and BT.selfHots.Renew, "an empty name changes nothing: Renew on yourself")
    BT.selfHots = nil
    clear()
    -- Flash Heal under the mouse with no target: its heal a frame later on the friend is yours
    STATE.who.target = nil
    STATE.helpful = STATE.helpful or {}
    STATE.helpful[2061] = true
    Advance(2)
    mouse("friend")
    sent("Friendo", 2061)
    mouse(nil)
    Advance(1.5)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-fh1", 2061)
    hidden(48)
    Advance(0.05)
    fire("UNIT_COMBAT", "party1", "HEAL", "", 300, 2)
    Advance(0.3)
    assertEq(last("outgoing"), "Flash Heal +300", "a heal landing a frame after its cast on the mouse's friend")
    clear()
    -- Prayer of Mending on the friend: it heals them when they're hurt, then jumps
    STATE.who.target = "mob"
    Advance(2)
    mouse("friend")
    sent("Friendo", 33076)
    mouse(nil)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pm1", 33076)
    hidden(49)
    Advance(0.3)
    assertEq(#lines("outgoing"), 0, "casting it heals nothing")
    Advance(3)
    fire("UNIT_COMBAT", "party2", "HEAL", "", 70, 2)
    hidden(50)
    Advance(0.3)
    assertEq(#lines("outgoing"), 0, "its first heal is on the friend it was put on, not anyone")
    Advance(4)
    fire("UNIT_COMBAT", "party1", "HEAL", "", 80, 2)
    hidden(51)
    Advance(0.3)
    assertEq(last("outgoing"), "Prayer of Mending +80", "its heal on the friend, named")
    Advance(5)
    fire("UNIT_COMBAT", "party1", "HEAL", "", 81, 2)
    hidden(52)
    Advance(0.3)
    assert(not table.concat(lines("outgoing"), " / "):find("+81", 1, true), "it has jumped: not the same friend again")
    Advance(5)
    fire("UNIT_COMBAT", "party2", "HEAL", "", 82, 2)
    Advance(0.6)
    assert(not table.concat(lines("outgoing"), " / "):find("+82", 1, true), "a heal with no line of yours isn't it")
    Advance(1)
    fire("UNIT_COMBAT", "party2", "HEAL", "", 83, 2)
    hidden(53)
    Advance(0.3)
    assertEq(last("outgoing"), "Prayer of Mending +83", "its jump to another group member, named")
    Advance(1)
    fire("UNIT_COMBAT", "party1", "HEAL", "", 84, 8)
    hidden(54)
    Advance(0.3)
    assert(not table.concat(lines("outgoing"), " / "):find("+84", 1, true), "a Nature heal isn't it")
    Advance(31)
    fire("UNIT_COMBAT", "party1", "HEAL", "", 85, 2)
    hidden(55)
    Advance(0.3)
    assert(not table.concat(lines("outgoing"), " / "):find("+85", 1, true), "nor a heal after it has faded")
    STATE.who, STATE.unit, STATE.group = whoWas, unitWas, groupWas
    BT.areaOn, BT.dots, BT.selfHots, BT.mending, BT.sent = nil, nil, nil, nil, nil
    clear()
end)()

step("mouseover heals when the game hides names (GitHub #29: Penance on a party member)")
;(function()   -- (a function: the file is near Lua's limit of locals)
    clear()
    local whoWas, unitWas, groupWas = STATE.who, STATE.unit, STATE.group
    -- In a dungeon the game hides every unit's name: SENT names the friend, but nothing can be
    -- matched to it (the player's log: "SENT 402174 to ?", every Penance heal on party1 dropped)
    STATE.who = { nameplate1 = "mob", party1 = "friend", party2 = "buddy" }
    STATE.unit = { friend = { guid = "Player-5555-0FRIEND1", name = "Friendo", secretName = true },
        buddy = { guid = "Player-5555-0BUDDY01", name = "Buddy", secretName = true },
        mob = { enemy = true, guid = "Creature-0-1-2-3-4-000129", target = "friend", name = "Boss", secretName = true } }
    STATE.group = true
    STATE.spellNames[402174], STATE.spellIcons[402174] = "Penance", 237545
    STATE.spellNames[402289], STATE.spellIcons[402289] = "Penance", 237545
    STATE.spellNames[9474], STATE.spellIcons[9474] = "Flash Heal", 135907
    STATE.helpful = STATE.helpful or {}
    STATE.helpful[9474] = true
    BT.db.healNames, BT.db.healIcons, BT.db.healWho, BT.db.healArea = true, false, false, false
    BT.hiddenSeen, BT.hiddenAt, BT.credits = true, GetTime(), {}
    BT.areaOn, BT.dots, BT.selfHots, BT.mending, BT.sent = nil, nil, nil, nil, nil
    local function mouse(id) STATE.who.mouseover = id end
    local function sent(name, id) fire("UNIT_SPELLCAST_SENT", "player", name, "Cast-s" .. id, id) end
    local function heal(unit, n, crit) fire("UNIT_COMBAT", unit, "HEAL", crit and "CRITICAL" or "", n, 1) end
    Advance(1)
    -- 1. Penance with the mouseover macro on party1, nothing targeted (the log, 958.30 on)
    mouse("friend")
    sent("Friendo", 402174)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn1", 402174)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn2", 402289)
    assertEq(BT.sent and BT.sent.unit, "party1", "with the names hidden, the friend under the mouse is who it went to")
    mouse(nil)
    Advance(0.55)
    heal("party1", 50, true)
    hidden(6)
    Advance(0.3)
    assertEq(last("outgoing"), "Penance +50", "its first heal (a crit), named")
    Advance(0.17)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn3", 402289)
    Advance(0.5)
    heal("party1", 51)
    hidden(7)
    Advance(0.53)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn4", 402289)
    Advance(0.45)
    heal("party1", 52)
    hidden(7)
    Advance(0.3)
    assertEq(table.concat(lines("outgoing"), " / "), "Penance +51 / Penance +52",
        "and its next heals, named")
    assertEq(#lines("incoming"), 0, "and none of it is shown as healing you")
    clear()
    -- 2. Flash Heal on yourself, no target and no mouseover: the heal comes before the cast, in one frame
    Advance(2)
    sent("Me", 9474)
    Advance(1.33)
    heal("player", 300)
    hidden(8)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-fh1", 9474)
    Advance(0.3)
    assertEq(last("incoming"), "+300 Flash Heal", "Flash Heal on yourself, named")
    clear()
    -- 3. Flash Heal on party1, targeted
    STATE.who.target, STATE.who.softfriend = "friend", "friend"
    Advance(5)
    sent("Friendo", 9474)
    Advance(1.36)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-fh2", 9474)
    heal("party1", 400)
    heal("target", 400)
    heal("softfriend", 400)
    hidden(9)
    Advance(0.3)
    assertEq(table.concat(lines("outgoing"), " / "), "Flash Heal +400", "Flash Heal on your target, named once")
    clear()
    -- A friend targeted and another under the mouse, names hidden: it can't be told, so your target
    BT.dots = nil
    Advance(5)
    mouse("buddy")
    local debugWas = BT.db.debug
    BT.db.debug, BT.recorded = true, {}
    sent("Buddy", 402174)
    BT.db.debug = debugWas
    assertEq(BT.sent, nil, "with a friend targeted, the mouse doesn't decide it")
    assert(BT.recorded[1]:find("SENT 402174 to ? (names hidden, mouse on a friend, target a friend)", 1, true),
        "the debug log says why: " .. tostring(BT.recorded[1]))
    mouse(nil)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn5", 402174)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn6", 402289)
    -- 4. (Penance on the targeted friend, as in the log at 975.86)
    Advance(0.44)
    heal("party1", 60)
    heal("target", 60)
    heal("softfriend", 60)
    hidden(7)
    Advance(0.3)
    assertEq(last("outgoing"), "Penance +60", "Penance on your target, named")
    STATE.who, STATE.unit, STATE.group = whoWas, unitWas, groupWas
    BT.areaOn, BT.dots, BT.selfHots, BT.mending, BT.sent = nil, nil, nil, nil, nil
    clear()
end)()

step("mouseover heals when SENT's name matches no one (GitHub #29, open world, Penance 1240720)")
;(function()   -- (a function: the file is near Lua's limit of locals)
    clear()
    local whoWas, unitWas, groupWas = STATE.who, STATE.unit, STATE.group
    STATE.who = { party1 = "friend", party2 = "buddy" }
    STATE.unit = { friend = { guid = "Player-5555-0FRIEND1", name = "Friendo" },
        buddy = { guid = "Player-5555-0BUDDY01", name = "Buddy" } }
    STATE.group = true
    STATE.spellNames[1240720], STATE.spellIcons[1240720] = "Penance", 237545
    STATE.spellNames[1240723], STATE.spellIcons[1240723] = "Penance", 237545
    STATE.spellNames[9474], STATE.spellIcons[9474] = "Flash Heal", 135907
    STATE.helpful = STATE.helpful or {}
    STATE.helpful[9474] = true
    BT.db.healNames, BT.db.healIcons, BT.db.healWho, BT.db.healArea = true, false, false, false
    BT.hiddenSeen, BT.hiddenAt, BT.credits = true, GetTime(), {}
    BT.areaOn, BT.dots, BT.selfHots, BT.mending, BT.sent = nil, nil, nil, nil, nil
    local function mouse(id) STATE.who.mouseover = id end
    local function sent(name, id) fire("UNIT_SPELLCAST_SENT", "player", name, "Cast-s" .. id, id) end
    local function heal(unit, n) fire("UNIT_COMBAT", unit, "HEAL", "", n, 1) end
    Advance(1)
    -- The log (528.80): "SENT 1240720 to ? (no name match, mouse on a friend, target not a friend)"
    mouse("friend")
    sent("Somethingelse", 1240720)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn1", 1240720)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn2", 1240723)
    assertEq(BT.sent and BT.sent.unit, "party1", "a name that matches no one: the friend under the mouse")
    mouse(nil)
    Advance(0.24)
    heal("party1", 50)
    hidden(9)
    Advance(0.75)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn3", 1240723)
    Advance(0.26)
    heal("party1", 51)
    hidden(7)
    Advance(0.73)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-pn4", 1240723)
    Advance(0.3)
    heal("party1", 52)
    hidden(7)
    Advance(0.3)
    assertEq(table.concat(lines("outgoing"), " / "), "Penance +50 / Penance +51 / Penance +52",
        "Penance's heals on the friend under the mouse, named")
    assertEq(#lines("incoming"), 0, "and none on you")
    clear()
    -- Flash Heal on yourself (535.92): the heal before the cast, in one frame
    Advance(2)
    sent("Somethingelse", 9474)
    Advance(1.32)
    heal("player", 300)
    hidden(14)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-fh1", 9474)
    Advance(0.3)
    assertEq(last("incoming"), "+300 Flash Heal", "Flash Heal on yourself, named")
    clear()
    -- Names the game might send another way: with the realm, in another case, or as a GUID
    for _, name in ipairs({ "Buddy-Realm", "buddy", "Player-5555-0BUDDY01" }) do
        mouse("friend")
        sent(name, 9474)
        mouse(nil)
        assertEq(BT.sent and BT.sent.unit, "party2", "SENT's " .. name .. " is the buddy, not the mouse's friend")
        Advance(7)
    end
    STATE.who, STATE.unit, STATE.group = whoWas, unitWas, groupWas
    BT.areaOn, BT.dots, BT.selfHots, BT.mending, BT.sent = nil, nil, nil, nil, nil
    clear()
end)()

step("heals on a player outside your group (GitHub #29: mouseover Penance on a stranger)")
;(function()   -- (a function: the file is near Lua's limit of locals)
    clear()
    local whoWas, unitWas, groupWas, classWas = STATE.who, STATE.unit, STATE.group, STATE.class
    STATE.who = {}
    STATE.unit = { stranger = { guid = "Player-5555-0STRANG1", name = "Strangey" } }
    STATE.group, STATE.class = false, "PRIEST"
    STATE.spellNames[1240720], STATE.spellIcons[1240720] = "Penance", 237545
    STATE.spellNames[1240723], STATE.spellIcons[1240723] = "Penance", 237545
    STATE.spellNames[1243], STATE.spellIcons[1243] = "Power Word: Fortitude", 135987
    STATE.helpful = STATE.helpful or {}
    STATE.helpful[1243] = true
    BT.db.healNames, BT.db.healIcons, BT.db.healWho, BT.db.healArea = true, false, false, false
    BT.hiddenSeen, BT.hiddenAt, BT.credits = true, GetTime(), {}
    BT.areaOn, BT.dots, BT.selfHots, BT.mending, BT.sent, BT.strangerHeal = nil, nil, nil, nil, nil, nil
    local function sent(name, id) fire("UNIT_SPELLCAST_SENT", "player", name, "Cast-s" .. id, id) end
    local function cast(id) fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-" .. id, id) end
    local function penance(plate)
        -- The player's log (708.65 on): SENT and both casts in one frame, then each tick's cast, and
        -- 0.12 to 0.24s later its hidden line (with a nameplate, UNIT_COMBAT in the line's frame)
        STATE.who.mouseover = "stranger"
        sent("Strangey", 1240720)
        cast(1240720)
        cast(1240723)
        assertEq(BT.sent and BT.sent.unit, "mouseover", "a stranger has no lasting name: the mouse's")
        STATE.who.mouseover = nil
        for i, wait in ipairs({ 0.24, 0.12, 0.14 }) do
            if i > 1 then cast(1240723) end
            Advance(wait)
            if plate then fire("UNIT_COMBAT", "nameplate1", "HEAL", "", 49 + i, 1) end
            hidden(147 + i)
            Advance(1 - wait)
        end
    end
    Advance(1)
    -- 1. No nameplate: the game sends nothing but the locked lines. They show, as they are.
    penance(false)
    assertEq(table.concat(lines("outgoing"), " / "), "|Ky148|k / |Ky149|k / |Ky150|k",
        "each tick's combat log line, shown as the game wrote it")
    assertEq(#lines("incoming"), 0, "and nothing on you")
    clear()
    -- With icons on, Penance's icon before it
    BT.db.healIcons = true
    penance(false)
    assert(last("outgoing"):find("^|T.-|t ?|Ky150|k$"), "the spell's icon, then the line: " .. tostring(last("outgoing")))
    BT.db.healIcons = false
    clear()
    -- 2. With their nameplate up: the game's heals come, named as before, and no line is shown
    STATE.who.nameplate1 = "stranger"
    penance(true)
    assertEq(table.concat(lines("outgoing"), " / "), "Penance +50 / Penance +51 / Penance +52",
        "the nameplate's heals, named, and no line twice")
    STATE.who.nameplate1 = nil
    clear()
    -- 3. Not a heal (a buff on them): its line isn't shown
    STATE.who.mouseover = "stranger"
    sent("Strangey", 1243)
    cast(1243)
    STATE.who.mouseover = nil
    Advance(0.15)
    hidden(160)
    Advance(0.5)
    assertEq(#lines("outgoing"), 0, "a buff's line isn't a heal")
    -- 4. A line long after the cast isn't the heal's
    STATE.who.mouseover = "stranger"
    sent("Strangey", 1240720)
    cast(1240720)
    cast(1240723)
    STATE.who.mouseover = nil
    Advance(0.8)
    hidden(161)
    Advance(0.5)
    assertEq(#lines("outgoing"), 0, "a line 0.8s after the cast isn't its heal")
    clear()
    -- 5. Heals you do turned off: nothing
    BT.db.outHeals = false
    penance(false)
    assertEq(#lines("outgoing"), 0, "heals you do off: no lines")
    BT.db.outHeals = true
    clear()
    STATE.who, STATE.unit, STATE.group, STATE.class = whoWas, unitWas, groupWas, classWas
    BT.areaOn, BT.dots, BT.selfHots, BT.mending, BT.sent, BT.strangerHeal = nil, nil, nil, nil, nil, nil
end)()

step("healers get the names over friendly players (GitHub #29)")
;(function()
    local cv = STATE.cvars
    local classWas = STATE.class
    local P, N = "nameplateShowFriendlyPlayers", "nameplateShowOnlyNameForFriendlyPlayerUnits"
    local function fresh(on, names)
        cv[P], cv[N] = on, names
        BT.db.friendPlatesSet, BT.db.savedPlateCVars, BT.db.friendPlates = nil, nil, true
    end
    STATE.class = "PRIEST"
    fresh("0", "0")
    BT:ApplySettings()
    assertEq(cv[P] .. cv[N], "11", "a priest gets friendly player nameplates, names only")
    assertEq(BT.db.friendPlatesSet, true, "once")
    -- The player turns them off again (Shift-V): they stay off
    cv[P] = "0"
    BT:ApplySettings()
    assertEq(cv[P], "0", "turned off by the player: left off")
    -- Turning the option off puts back what BattleText changed
    fresh("0", "0")
    BT:ApplySettings()
    BT.db.friendPlates = false
    BT:ApplySettings()
    assertEq(cv[P] .. cv[N], "00", "the option off: the nameplate settings as they were")
    assertEq(BT.db.friendPlatesSet, nil, "and on again would turn them on again")
    -- Already on, with health bars: the player's look is left alone, and so is it when the option goes off
    fresh("1", "0")
    BT:ApplySettings()
    assertEq(cv[P] .. cv[N], "10", "already showing: unchanged")
    BT.db.friendPlates = false
    BT:ApplySettings()
    assertEq(cv[P] .. cv[N], "10", "and still unchanged with the option off")
    -- BattleText turned off: put back too
    fresh("0", "0")
    BT:ApplySettings()
    BT.db.enabled = false
    BT:ApplySettings()
    assertEq(cv[P] .. cv[N], "00", "BattleText off: put back")
    BT.db.enabled = true
    -- Not a healer: nothing changes
    STATE.class = "WARRIOR"
    fresh("0", "0")
    BT:ApplySettings()
    assertEq(cv[P] .. cv[N], "00", "a warrior's nameplates are left alone")
    -- In a fight it waits for the fight to end (nameplate settings can't change then)
    STATE.class = "DRUID"
    fresh("0", "0")
    COMBAT = true
    BT:ApplySettings()
    assertEq(cv[P], "0", "not in a fight")
    COMBAT = false
    fire("PLAYER_REGEN_ENABLED")
    assertEq(cv[P] .. cv[N], "11", "after it")
    -- Reset all puts them back first (then turns them on again, as a new start would)
    BT.db.friendPlates = false
    BT:ApplySettings()
    cv[P], cv[N] = nil, nil
    BT.db.friendPlatesSet, BT.db.savedPlateCVars, BT.db.friendPlates = nil, nil, true
    BT:ApplySettings()
    assertEq(BT.db.friendPlatesSet, nil, "a game without the setting: nothing done")
    STATE.class = classWas
end)()

step("a font of their own for crits")
-- CurseForge (beefsupreme3954, a healer): "it would be great to select a separate font for crits"
;(function()
    local function newestIn(area) local act = BT.areas[area].active return act[#act] end
    local was = { BT.db.font, BT.db.critFont }
    BT.db.font = "Default"
    assertEq(BT.db.critFont, "", "crits use the same font as other lines at first")
    local d = BT.config.critFontDropdown
    assert(d, "the Text tab has a Crit font list")
    assertEq(d.keys[1], "", "its first choice is the same font as other lines")
    assertEq(d:GetText(), "Same as other lines", "and it says so")
    local inList = {}
    for _, k in ipairs(d.keys) do inList[k] = true end
    for _, f in ipairs(BT.FONTS) do assert(inList[f.name], "every font is a crit font choice: " .. f.name) end
    assertEq(#d.keys, #BT.FONTS + 1, "and nothing else")
    clear()
    BT:SetCritFont("Bangers")
    assertEq(BT.db.critFont, "Bangers", "picked")
    local crit = newestIn("notify")
    assertEq(crit.text:GetText(), "Crit", "picking one shows a crit")
    assert(crit.fontPath:find("Bangers%-Regular%.ttf$"), "in that font")
    BT:RefreshConfig()
    assertEq(d:GetText(), "Bangers", "and the list shows it")
    clear()
    BT:Emit("outgoing", "120", BT.TEXT_COLORS.spell, { crit = true })
    assert(newestIn("outgoing").fontPath:find("Bangers%-Regular%.ttf$"), "crits use the crit font")
    BT:Emit("outgoing", "40", BT.TEXT_COLORS.spell)
    assertEq(newestIn("outgoing").fontPath, BT:FontPath(), "other lines keep the font")
    assert(not BT:FontPath():find("Bangers", 1, true), "(which isn't the crit font)")
    BT.db.font = "Lato"
    assert(BT:FontPath():find("Lato%-Bold%.ttf$"), "changing the font changes other lines")
    assert(BT:FontPath(true):find("Bangers%-Regular%.ttf$"), "but not crits")
    BT.db.critFont = ""
    assertEq(BT:FontPath(true), BT:FontPath(), "back to the same as other lines")
    -- It goes through settings sharing like any other choice
    assertEq(BT:Choices("critFont")["Bangers"], true, "a font name is a crit font choice")
    assertEq(BT:Choices("critFont")[""], true, "and so is the same as other lines")
    assertEq(BT:Choices("critFont")["Comic Sans"], nil, "a font BattleText doesn't have isn't")
    BT.db.font, BT.db.critFont = was[1], was[2]
    clear()
end)()

step("translations: the addon's own text in the player's language")
;(function()   -- (a function: the file is near Lua's limit of locals)
    -- The language files list every line the addon writes, and are up to date
    -- (lua5.1 tests/tools/make_locales.lua writes them)
    MAKE_LOCALES_LIBRARY = true
    local M = dofile(ADDON_DIR .. "/tests/tools/make_locales.lua")
    MAKE_LOCALES_LIBRARY = nil
    local keys = M.Keys()
    assert(#keys > 300, "the options, chat and on-screen text are all translatable (" .. #keys .. " lines)")
    local codes = M.Locales()
    assertEq(table.concat(codes, " "), "deDE esES esMX frFR itIT koKR ptBR ruRU zhCN zhTW",
        "a file for each language the game comes in (but English)")
    for _, code in ipairs(codes) do
        local found, order, src = M.Read(code)
        assertEq(src, M.Make(code), "Locales/" .. code .. ".lua is up to date: run lua5.1 tests/tools/make_locales.lua")
        assertEq(#order, #keys, code .. " has every line")
        -- A translation keeps the %s and %d of its English (or the line breaks in game)
        for english, text in pairs(found) do
            if text ~= "" then
                assertEq(M.Codes(text), M.Codes(english), code .. ": the %s and %d codes in " .. english)
            end
        end
    end
    assertEq(M.Codes("%s damage (%s DPS), 50%% %d"), "%s %s %d", "codes are read in order, %% isn't one")

    -- A language file does nothing in another language
    local function runLocale(code, locale)
        local wrote = 0
        local chunk = assert(loadstring(read_file(ADDON_DIR .. "/Locales/" .. code .. ".lua")))
        setfenv(chunk, setmetatable({ GetLocale = function() return locale end }, { __index = _G }))
        chunk(ADDON, { L = setmetatable({}, { __newindex = function() wrote = wrote + 1 end }) })
        return wrote
    end
    assertEq(runLocale("koKR", "enUS"), 0, "the Korean file is skipped in an English game")
    assertEq(runLocale("koKR", "koKR"), #keys, "and read in a Korean one")

    -- L: the English when there's no translation, or it's still ""
    local L = ns.L
    assertEq(L["Some text nobody translated"], "Some text nobody translated", "untranslated: the English")
    L["Crit"] = ""
    assertEq(L["Crit"], "Crit", "an empty translation shows the English")
    assertEq(rawget(L, "Crit"), nil, "and isn't kept")

    -- A translation shows on screen, in chat and with its numbers filled in
    L["Crit"] = "치명타"
    L["%s damage (%s DPS)"] = "피해 %s (초당 %s)"
    L["%s in %ss"] = "%s, %s초"
    clear()
    BT:SetOutline("critOutline", BT.db.critOutline)
    assertEq(last("notify"), "치명타", "the sample crit line, translated")
    assertEq(BT:FightLine({ damage = 4820, heal = 0, secs = 38 }), "피해 4,820 (초당 127), 38초", "the fight summary, translated")
    rawset(L, "Crit", nil)
    rawset(L, "%s damage (%s DPS)", nil)
    rawset(L, "%s in %ss", nil)
    assertEq(BT:FightLine({ damage = 4820, heal = 0, secs = 38 }), "4,820 damage (127 DPS) in 38s", "and English again")
    clear()
end)()

step("German fits the options window (buttons grow, controls make room for long labels)")
;(function()
    -- The German file, read into L for a second options window
    local found = {}
    local chunk = assert(loadstring(read_file(ADDON_DIR .. "/Locales/deDE.lua")))
    setfenv(chunk, setmetatable({ GetLocale = function() return "deDE" end }, { __index = _G }))
    chunk(ADDON, { L = setmetatable({}, { __newindex = function(_, k, v) found[k] = v end }) })
    local L = ns.L
    for k, v in pairs(found) do L[k] = v end
    local english = BT.config
    BT.config = nil
    BT:BuildConfig()
    local win = BT.config
    -- Buttons are as wide as their text, never narrower than in English
    for _, name in ipairs({ "sampleButton", "resetButton", "resetAllButton", "exportButton", "importButton" }) do
        local b = win[name]
        assert(b.__size[1] >= b:GetTextWidth() + 16, name .. " fits " .. tostring(b.__text))
    end
    assertEq(win.resetButton.__text, "Positionen zurücksetzen", "(in German)")
    -- The footer: the buttons stay inside it, and the hint makes way when there's no room for it
    local left = (ns.Theme.WINDOW.W - 2) - 14 - win.closeButton:GetWidth() - 16 - win.resetAllButton:GetWidth() - 8
        - win.resetButton:GetWidth() - 8 - win.sampleButton:GetWidth()
    assert(left >= 14, "the footer buttons fit (" .. left .. ")")
    local hintW = win.footerHint:GetStringWidth()
    assertEq(win.footerHint:IsShown(), 14 + hintW + 12 <= left, "the hint shows only with room for it")
    assert(win.resetButton.__size[1] > 120, "so it grew")
    assertEq(english.exportButton.__size[1], 90, "a short word keeps the usual width (English)")
    -- A sound list starts after its switch's label, keeping its right edge
    local function after(d, swX, label)
        local labelRight = swX + 38 + #label * 7
        assert(d.__pos[1] >= labelRight + 8, label .. ": the list starts after it (" .. tostring(d.__pos[1]) .. ")")
        assertEq(d.__pos[1] + d.__size[1], swX + 244, label .. ": and ends where it always does")
    end
    after(win.lowHealthDropdown, 12, "Wenig Gesundheit")
    after(win.killSoundDropdown, 270, "Todesstoß-Sound")
    assertEq(win.lowManaDropdown.__pos[1], 270 + 118, "a short label keeps the list in its place")
    BT.config = nil
    -- With long notes that run off the page, the share note goes on the buttons' tooltips
    local heightWas = STUB_METHODS.GetStringHeight
    STUB_METHODS.GetStringHeight = function() return 90 end
    BT:BuildConfig()
    STUB_METHODS.GetStringHeight = heightWas
    local share = BT.config.shareCard
    assertEq(BT.config.knowCard.__size[2], 134, "Good to know grows with its text")
    assertEq(BT.config.shareNote:IsShown(), false, "the share note is left out")
    assert(-share.__pos[2] + share.__size[2] <= ns.Theme.WINDOW.BODY_H, "so the page still fits")
    -- Back to English
    for k in pairs(found) do rawset(L, k, nil) end
    BT.config = english
    clear()
end)()

step("Spanish fits the options window (GitHub #42, Javat00), and card titles are upper case in any language")
;(function()
    local Upper = ns.Theme.Upper
    assertEq(Upper("Opciones básicas"), "OPCIONES BÁSICAS", "Spanish: accented letters too (string.upper leaves them)")
    assertEq(Upper("Añadir un hechizo"), "AÑADIR UN HECHIZO", "and ñ")
    assertEq(Upper("Größe"), "GRÖßE", "German")
    assertEq(Upper("Здоровье ёж"), "ЗДОРОВЬЕ ЁЖ", "Russian")
    assertEq(Upper("a ÷ b"), "A ÷ B", "a sign stays as it is")
    -- The Spanish file, read into L for a second options window (Latin American Spanish is the same file)
    assertEq(read_file(ADDON_DIR .. "/Locales/esMX.lua"):match("\n\n%-%- Core.*"),
        read_file(ADDON_DIR .. "/Locales/esES.lua"):match("\n\n%-%- Core.*"), "esMX has the same lines as esES")
    local found = {}
    local chunk = assert(loadstring(read_file(ADDON_DIR .. "/Locales/esES.lua")))
    setfenv(chunk, setmetatable({ GetLocale = function() return "esES" end }, { __index = _G }))
    chunk(ADDON, { L = setmetatable({}, { __newindex = function(_, k, v) found[k] = v end }) })
    local L = ns.L
    for k, v in pairs(found) do L[k] = v end
    local english = BT.config
    BT.config = nil
    BT:BuildConfig()
    local win = BT.config
    assertEq(english.critOutlineDropdown.__pos[1], 110, "English: the Text tab's lists at their usual place")
    local labelRight = 12 + #"Contorno de críticos" * 7
    assert(win.critOutlineDropdown.__pos[1] >= labelRight + 8, "Spanish: they start after \"Contorno de críticos\"")
    assertEq(win.fontDropdown.__pos[1], win.critOutlineDropdown.__pos[1], "all four lists line up")
    assert(win.critOutlineDropdown.__pos[1] + 220 <= ns.Theme.WINDOW.PAGE_W - 12, "and stay inside the card")
    -- A sound list with a long label: the label goes on two lines instead of being cut short
    local kill = win.killSoundDropdown
    assertEq(kill.__size[1], 80, "the kill sound list keeps its least width")
    local killLabel = found["Kill sound"]
    assertEq(killLabel, "Sonido de golpe de gracia", "(in Spanish)")
    local wrapped = false
    for _, f in ipairs(ALL_FRAMES) do
        if f.__text == killLabel and f.__wrap == true then wrapped = true end
    end
    assert(wrapped, "the label wraps")
    for k in pairs(found) do rawset(L, k, nil) end
    BT.config = english
    clear()
end)()

step("spell lists made again once in another language, if a name was missing at login (review L6)")
;(function()
    local names = STATE.spellNames
    STATE.locale = "deDE"
    STATE.spellNames = setmetatable({}, { __index = names })
    STATE.spellNames[1079] = false
    BT.periodic, BT.seals, BT.listsMissing, BT.listsRemade = nil, nil, nil, nil
    BT:SpellLists()
    assertEq(BT.periodic["Zerfetzen"], nil, "no German name for Rip at login")
    STATE.spellNames[1079] = "Zerfetzen"
    fire("PLAYER_REGEN_DISABLED")
    assert(BT.periodic["Zerfetzen"], "made again as the fight starts: Rip by its German name")
    assert(BT.periodic["Rip"], "and its English one")
    fire("PLAYER_REGEN_ENABLED")
    STATE.spellNames, STATE.locale = names, nil
    BT.periodic, BT.seals, BT.listsMissing = nil, nil, nil
    clear()
end)()

step("the lines stop after they've started (review L1), and heals on the group with none of yours going (P1)")
;(function()
    clear()
    BT.startHidden, BT.startNeeded, BT.startButton.wanted = nil, nil, nil
    BT.db.debug = false
    BT:NoteHiddenLine(GetTime())
    BT.started = true
    COMBAT = true
    for i = 1, 7 do
        fire("PLAYER_SWING", 2.6, 0)
        Advance(3)
    end
    assert(BT.hiddenSeen, "7 swings over 21 seconds with no line: not enough to say")
    fire("PLAYER_SWING", 2.6, 0)
    assertEq(BT.hiddenSeen, nil, "8 casts and swings over 20 seconds in a fight with no line: the lines have stopped")
    assertEq(BT.started, nil, "and BattleText isn't started any more")
    COMBAT = false
    fire("PLAYER_REGEN_ENABLED")
    assertEq(BT.startButton:IsShown(), true, "the Start button shows after the fight")
    BT:NoteHiddenLine(GetTime())
    fire("COMBAT_LOG_MESSAGE", Secret("a line"), nil, nil, nil, 0)
    assert(BT.hiddenSeen and BT.started, "the next line puts it back")
    assertEq(BT.startButton:IsShown(), false, "and the button goes")
    COMBAT = true
    for i = 1, 12 do
        fire("PLAYER_SWING", 2.6, 0)
        if i % 4 == 0 then BT:NoteHiddenLine(GetTime()) end
        Advance(3)
    end
    assert(BT.started, "a line now and then: the lines are still flowing")
    COMBAT = false
    -- Out of a fight, nothing is counted
    for i = 1, 10 do fire("PLAYER_SWING", 2.6, 0) Advance(3) end
    assert(BT.hiddenSeen, "out of a fight: not counted")

    -- A heal on a party member with no helpful cast of yours in the last 45 seconds: turned away at once
    STATE.group = true
    STATE.unit.healMate = { friend = true, guid = "Player-1-0000000F" }
    STATE.who.party1 = "healMate"
    BT.healsLiveAt = nil
    BT.db.debug = true
    BT.recorded = {}
    fire("UNIT_COMBAT", "party1", "HEAL", "", 300, 2)
    assert(table.concat(BT.recorded, "\n"):find("no heal of yours going", 1, true), "a heal on the group, none of yours going")
    BT.healsLiveAt = GetTime() - 46
    BT.recorded = {}
    fire("UNIT_COMBAT", "party1", "HEAL", "", 300, 2)
    assert(table.concat(BT.recorded, "\n"):find("no heal of yours going", 1, true), "your last helpful cast 46 seconds ago")
    BT.healsLiveAt = GetTime() - 40
    BT.recorded = {}
    fire("UNIT_COMBAT", "party1", "HEAL", "", 300, 2)
    assert(not table.concat(BT.recorded, "\n"):find("no heal of yours going", 1, true), "40 seconds ago: it may be your heal over time")
    BT.db.debug = false
    STATE.group = false
    STATE.who.party1 = nil
    BT:FlushHits(true)
    clear()
end)()

step("a hit for nothing never shows as \"Heroic Strike 0\" (Tyler, in game)")
;(function()
    STATE.group = false
    STATE.unit.hsMob = { enemy = true, guid = "Creature-0-1-2-3-100-0000HS", target = "me" }
    STATE.who.target = "hsMob"
    freshFight()
    BT.db.merge = true
    SetIcons(false)
    local function newest() local a = BT.areas.outgoing.active return a[#a] and a[#a].text.__shown end
    STATE.spellNames[78] = "Heroic Strike"
    -- Hidden amounts: the game writes the number, and a 0 is left blank, the whole line with it
    Advance(5)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hs1", 78)
    fire("UNIT_COMBAT", "target", "WOUND", "", Secret(0), 1)
    BT:FlushHits(true)
    Advance(0.4)   -- (an attack on the next swing waits for a second part: see below)
    assertEq(newest(), "", "a hidden 0 writes nothing: not \"Heroic Strike 0\"")
    Advance(5)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hs2", 78)
    fire("UNIT_COMBAT", "target", "WOUND", "", Secret(57), 1)
    BT:FlushHits(true)
    Advance(0.4)
    assertEq(newest(), "Heroic Strike <secret>", "a hidden hit still shows its number")
    -- Heroic Strike comes in two parts on Forever: a hit for nothing, then the attack (Tyler's /btf
    -- debug). Mostly in one frame; sometimes the attack comes a frame later, with its lines.
    local function shownSince(n)
        local out, a = {}, BT.areas.outgoing.active
        for k = n + 1, #a do out[#out + 1] = a[k].text.__shown end
        return table.concat(out, " / ")
    end
    clear()
    Advance(5)
    hidden(140)   -- (the lines are flowing)
    fire("PLAYER_SWING", 2.6, 0)
    Advance(0.4)
    fire("UNIT_COMBAT", "target", "WOUND", "", Secret(13), 1)   -- a white hit
    BT:FlushHits(true)
    assertEq(shownSince(0), "<secret>", "the swing before it")
    -- In one frame (782.71): cast, the part for nothing, the swing, the line, the attack
    Advance(2)
    clear()
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hs3", 78)
    fire("UNIT_COMBAT", "target", "WOUND", "", Secret(0), 1)
    fire("PLAYER_SWING", 2.6, 0)
    hidden(141)
    fire("UNIT_COMBAT", "target", "WOUND", "", Secret(25), 1)
    BT:FlushHits(true)
    Advance(0.4)
    assertEq(shownSince(0), "Heroic Strike <secret>", "one frame: the attack named, the part for nothing left out")
    -- Split (832.59 / 832.74): the attack and its lines come 0.15s after the cast
    Advance(2)
    clear()
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hs4", 78)
    fire("UNIT_COMBAT", "target", "WOUND", "", Secret(0), 1)
    fire("PLAYER_SWING", 2.6, 0)
    BT:FlushHits(true)
    Advance(0.15)
    hidden(154)
    hidden(155)
    fire("UNIT_COMBAT", "target", "WOUND", "", Secret(25), 1)
    BT:FlushHits(true)
    Advance(0.4)
    assertEq(shownSince(0), "Heroic Strike <secret>",
        "split: the late attack is Heroic Strike, not a swing, and the part for nothing isn't shown")
    -- No second part comes: the one hit was the attack
    Advance(2)
    clear()
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-hs5", 78)
    fire("UNIT_COMBAT", "target", "WOUND", "", Secret(25), 1)
    fire("PLAYER_SWING", 2.6, 0)
    hidden(160)
    BT:FlushHits(true)
    Advance(0.4)
    assertEq(shownSince(0), "Heroic Strike <secret>", "alone, it's shown after the wait")
    -- A swing well after it is a swing again
    Advance(2)
    clear()
    fire("PLAYER_SWING", 2.6, 0)
    hidden(161)
    Advance(0.4)
    fire("UNIT_COMBAT", "target", "WOUND", "", Secret(13), 1)
    BT:FlushHits(true)
    assertEq(shownSince(0), "<secret>", "the next white hit")
    -- A hidden 0 joining a line keeps the hits before it (the count goes on)
    Advance(5)
    clear()
    BT:Emit(BT:Area("OutDamage"), "Whirlwind ", { 1, 1, 1 }, { key = "ww", secret = Secret(40) })
    BT:Emit(BT:Area("OutDamage"), "Whirlwind ", { 1, 1, 1 }, { key = "ww", secret = Secret(0) })
    assertEq(newest(), "Whirlwind  |cffb0b0b0(2 hits)|r", "the line stays, with no 0 in it")
    BT:Emit(BT:Area("OutDamage"), "Whirlwind ", { 1, 1, 1 }, { key = "ww", secret = Secret(41) })
    assertEq(newest(), "Whirlwind <secret> |cffb0b0b0(3 hits)|r", "and the next hit's number shows")
    -- A readable line "for 0" is a miss: absorbed, blocked or resisted when the line says so
    Advance(5)
    clear()
    log(hit("Heroic Strike", 78, 0, "Physical"))
    assertEq(last("outgoing"), "Heroic Strike Miss", "0 with nothing said: a miss")
    Advance(1)
    log(hit("Heroic Strike", 78, 0, "Physical", "(57 Absorbed)"))
    assertEq(last("outgoing"), "Heroic Strike Absorb", "all of it absorbed")
    Advance(1)
    log(hit("Heroic Strike", 78, 0, "Physical", "(57 Blocked)"))
    assertEq(last("outgoing"), "Heroic Strike Block", "all of it blocked")
    Advance(1)
    log(hit("Heroic Strike", 78, 12, "Physical"))
    assertEq(last("outgoing"), "Heroic Strike 12", "a real hit is a hit")
    SetIcons(true)
    STATE.who.target = nil
    clear()
end)()

-- Fonts and the game's language (1.35.0, CurseForge, Barmy): most of the bundled fonts have no
-- Russian letters, so Russian names showed blank. A Russian game is offered only the fonts that
-- have them, the game's fonts switch to their Cyrillic copies, and Korean and Chinese games get Default.
;(function()
    local dropdown = BT.config.fontDropdown
    local function has(list, name)
        for _, n in ipairs(list) do if n == name then return true end end
        return false
    end
    BT.fontPathCache = nil
    STATE.locale = "enUS"
    assertEq(#BT:FontNames(), #BT.FONTS, "an English game is offered every font")
    STATE.locale = "ruRU"
    local names = BT:FontNames()
    assertEq(table.concat(names, ", "), "Default, Friz Quadrata, Arial Narrow, Morpheus, Skurri, Fira Sans, Lato, "
        .. "Press Start 2P, PT Sans Narrow, Russo One, Ubuntu", "a Russian game: only the fonts with Russian letters")
    BT.db.font = "Friz Quadrata"
    assertEq(BT:FontPath(), "Fonts\\FRIZQT___CYR.TTF", "the game's Friz Quadrata is its Cyrillic copy")
    BT.db.font = "Skurri"
    assertEq(BT:FontPath(), "Fonts\\SKURRI_CYR.TTF", "Skurri too")
    BT.db.font = "Lato"
    assertEq(BT:FontPath(), "Interface\\AddOns\\BattleTextForever\\Fonts\\Lato-Bold.ttf", "a bundled font with the letters is itself")
    BT.db.font = "Bangers"
    assertEq(BT:FontPath(), STANDARD_TEXT_FONT, "one without them draws in the game's font")
    BT:RefreshConfig()
    assertEq(dropdown:GetText(), "Default", "and the options say Default")
    assertEq(BT.db.font, "Bangers", "the setting itself is kept")
    BT.db.critFont = "Anton"
    assertEq(BT:FontPath(true), STANDARD_TEXT_FONT, "the crit font too")
    BT:RefreshConfig()
    assertEq(BT.config.critFontDropdown:GetText(), "Default", "and its option says Default")
    STATE.locale = "koKR"
    assertEq(table.concat(BT:FontNames(), ", "), "Default", "a Korean game: none of the fonts have its letters")
    BT.db.font = "Lato"
    assertEq(BT:FontPath(), STANDARD_TEXT_FONT, "so lines are in the game's font")
    STATE.locale = "zhCN"
    assertEq(has(BT:FontNames(), "Friz Quadrata"), false, "Chinese the same")
    BT.FONTS[#BT.FONTS + 1] = { name = "A shared font", path = "Interface\\AddOns\\Pack\\Font.ttf", shared = true }
    assertEq(has(BT:FontNames(), "A shared font"), true, "fonts other addons share are always offered")
    table.remove(BT.FONTS)
    STATE.locale = "enUS"
    BT.db.font = "Friz Quadrata"
    assertEq(BT:FontPath(), "Fonts\\FRIZQT__.TTF", "an English game keeps the usual file")
    BT.db.font, BT.db.critFont = "Default", ""
    BT:RefreshConfig()
    clear()
end)()

step("line order: {icon} {damage} {name} (CurseForge, xSky7)")
;(function()
    clear()
    local I = "|Tx:0|t "   -- (an icon as BT:IconTag writes it, space and all)
    local function parts(key, icon, name, pet) return table.concat({ BT:LineParts(key, icon, name, pet) }, "#") end
    assertEq(BT.db.outFormat, "{icon} {name} {damage}", "the usual order to start with")
    assertEq(parts("outFormat", I, "Fireball"), "|Tx:0|t Fireball #", "as before: icon, name, number")
    assertEq(parts("outFormat", "", nil), "#", "a swing with nothing to name it: just the number")
    assertEq(parts("outFormat", I, nil), "|Tx:0|t #", "names off: no gap")
    assertEq(parts("outFormat", "", "Claw", "(Fluffy) "), "Claw (Fluffy) #", "your pet's mark goes with the name")
    assertEq(parts("outFormat", "", nil, "(Fluffy) "), "(Fluffy) #", "a pet's swing")
    BT.db.outFormat = "{icon} {damage} {name}"
    assertEq(parts("outFormat", I, "Fireball"), "|Tx:0|t # Fireball", "the number before the name")
    assertEq(parts("outFormat", I, nil), "|Tx:0|t #", "names off: no space left after the number")
    assertEq(parts("outFormat", "", nil), "#", "nor with neither")
    BT.db.outFormat = "{DAMAGE} - {name}"
    assertEq(parts("outFormat", I, "Fireball"), "# - Fireball", "words between parts stay; any case")
    BT.db.outFormat = "{icon} {name}"
    assertEq(parts("outFormat", I, "Fireball"), "|Tx:0|t Fireball #", "no {damage}: the number goes at the end")
    BT.db.outFormat = "{damage} {damage} {name}"
    assertEq(parts("outFormat", "", "Fireball"), "# Fireball", "the number shows once")
    BT.db.outFormat = "|cffff0000{name} {damage}"
    assertEq(parts("outFormat", "", "Fireball"), "||cffff0000Fireball #", "a typed | is only a |")
    BT.db.outFormat = "   "
    assertEq(parts("outFormat", I, "Fireball"), "|Tx:0|t Fireball #", "an empty box is the usual order")
    BT.db.outFormat = "{icon} {damage} {name}"
    assertEq(parts("healFormat", I, "Flash Heal"), "|Tx:0|t Flash Heal #", "heals have an order of their own")

    -- On screen: a line you can read, one added up, a miss, a heal
    SetIcons(false)
    local function newestText(area) BT:FlushHits(true) local act = BT.areas[area].active return act[#act].text.__shown end
    BT.db.merge = false
    BT:ShowCombat({ kind = "damage", fromMe = true, event = "SPELL_DAMAGE", spell = "Claw", spellId = 1082, amount = 40 })
    assertEq(newestText("outgoing"), "40 Claw", "the number, then the name")
    BT:ShowCombat({ kind = "damage", fromMe = true, event = "SPELL_DAMAGE", spell = "Claw", spellId = 1082,
        amount = 40, absorbed = 5 })
    assertEq(newestText("outgoing"), "40 Claw |cffb0b0b0(5 absorbed)|r", "notes stay at the end")
    BT.db.merge = true
    clear()
    Advance(5)
    BT:ShowCombat({ kind = "damage", fromMe = true, event = "SPELL_DAMAGE", spell = "Claw", spellId = 1082, amount = 40 })
    BT:ShowCombat({ kind = "damage", fromMe = true, event = "SPELL_DAMAGE", spell = "Claw", spellId = 1082, amount = 30 })
    assertEq(newestText("outgoing"), "70 Claw |cffb0b0b0(x2)|r", "hits added up keep the order")
    BT:ShowCombat({ kind = "miss", fromMe = true, spell = "Claw", spellId = 1082, missType = "DODGE" })
    assertEq(newestText("outgoing"), "Dodge Claw", "a miss too")
    BT.db.healFormat = "{damage} {name}"
    BT:ShowCombat({ kind = "heal", fromMe = true, spell = "Flash Heal", spellId = 2061, amount = 120 })
    assertEq(newestText(BT:HealArea("outgoing")), "+120 Flash Heal", "a heal by its own order")

    -- A hidden number: the game writes it, still between the parts, and a hidden 0 still writes nothing
    STATE.group = false
    STATE.unit.orderMob = { enemy = true, guid = "Creature-0-1-2-3-100-0000LO", target = "me" }
    STATE.who.target = "orderMob"
    freshFight()
    STATE.spellNames[78] = "Heroic Strike"
    Advance(5)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-lo1", 78)
    fire("UNIT_COMBAT", "target", "WOUND", "", Secret(57), 1)
    BT:FlushHits(true)
    Advance(0.4)
    assertEq(newestText("outgoing"), "<secret> Heroic Strike", "a hidden number before the name")
    Advance(5)
    fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-lo2", 78)
    fire("UNIT_COMBAT", "target", "WOUND", "", Secret(0), 1)
    BT:FlushHits(true)
    Advance(0.4)
    assertEq(newestText("outgoing"), "", "a hidden 0 still writes nothing at all")
    BT.db.outFormat, BT.db.healFormat = BT.LINE_FORMAT, BT.LINE_FORMAT
    SetIcons(true)
    clear()
end)()
---------------------------------------------------------------------------
step("an icon of your own for a spell (Spells tab, GitHub #44)")
;(function()
    clear()
    wipe(BT.db.spellRules)
    BT.rulesByName = nil
    STATE.spellIcons[12162], STATE.spellIcons[1822] = 132090, 132122
    STATE.spellNames[12162] = "Deep Wounds"
    -- What can be typed: a spell's ID or name, or an icon's name as Wowhead shows it
    assertEq(BT:IconFrom(" 12162 "), 132090, "by spell ID")
    assertEq(BT:IconFrom("Rake"), nil, "a name the game doesn't place gives nothing")
    STATE.spellIcons.Rake = 132122
    assertEq(BT:IconFrom("Rake"), 132122, "by name, for a spell the game knows")
    assertEq(BT:IconFrom("ability_backstab"), "Interface\\Icons\\ability_backstab", "an icon's file name")
    assertEq(BT:IconFrom("Not A Spell"), nil, "nothing for anything else")
    assertEq(BT:IconFrom("bad|cff_x"), nil, "no | in an icon's name")
    assertEq(BT:IconFrom(""), nil, "nor nothing")
    assertEq(BT.SafeIcon("Interface\\Icons\\x:0|t|cffff0000"), nil, "a path that would break the line isn't used")
    -- On your lines
    local rule = BT:AddSpellRule("Claw")
    local ok, why = BT:SetSpellIcon(rule, "Not A Spell")
    assertEq(ok, nil, "a name with no icon isn't taken")
    assert(why:find("Not A Spell", 1, true), "and chat says which")
    assertEq(BT:SetSpellIcon(rule, "12162"), true, "an ID is")
    assertEq(rule.icon .. " " .. rule.iconFrom, "132090 12162", "kept with what was typed")
    SetNames(true) SetIcons(true)
    Advance(1)
    log(hit("Claw", 16827, 51))
    assertEq(last("outgoing"), "|T132090:0|t Claw 51", "Claw shows with the icon given it")
    BT.db.outFormat = "{damage} {name} {icon}"
    Advance(1)
    log(hit("Claw", 16827, 52))
    assertEq(last("outgoing"), "52 Claw |T132090:0|t", "where Line order puts the icon")
    BT.db.outFormat = BT.LINE_FORMAT
    BT.db.iconZoom = true
    Advance(1)
    log(hit("Claw", 16827, 53))
    assertEq(last("outgoing"), "|T132090:0:0:0:0:64:64:5:59:5:59|t Claw 53", "Icon zoom too")
    BT.db.iconZoom = false
    SetIcons(false)
    Advance(1)
    log(hit("Claw", 16827, 54))
    assertEq(last("outgoing"), "Claw 54", "icons off: none")
    SetIcons(true)
    -- (a spell the game has no icon for still gets one)
    local thrill = BT:AddSpellRule("Fire Spit")
    BT:SetSpellIcon(thrill, "ability_backstab")
    assertEq(BT:SpellParts("in", "", "Fire Spit"), "|TInterface\\Icons\\ability_backstab:0|t ", "a spell without one of its own")
    assertEq(BT:SpellParts("in", "|T1:0|t ", "Fireball"), "|T1:0|t ", "a spell not given one keeps its own")
    -- Masque puts its skinned icon over it, like any other
    local masqueGroup = { AddButton = function() end }
    rawset(_G, "LibStub", function(name) return name == "Masque" and { Group = function() return masqueGroup end } or nil end)
    BT.masque = nil
    Advance(1)
    log(hit("Claw", 16827, 55))
    local line = BT.areas.outgoing.active[#BT.areas.outgoing.active]
    assertEq(line.icons and line.icons[1].Icon.__texture, 132090, "with Masque: the skinned icon is the one given")
    rawset(_G, "LibStub", nil)
    BT.masque = nil
    clear()
    -- Shared with Export and Import, checked on the way in
    local t = assert(BT:ReadSettings(BT:ExportSettings()))
    assertEq(t.spellRules[1].icon .. " " .. t.spellRules[1].iconFrom, "132090 12162", "the icon goes with the settings")
    assertEq(t.spellRules[2].icon, "Interface\\Icons\\ability_backstab", "a named one too")
    t = assert(BT:ReadSettings("BTF1:" .. BT.Serialize({ spellRules = { { name = "Claw", icon = "x:0|t|Hbad", iconFrom = "x" },
        { name = "Rake", icon = -5 } } })))
    assertEq(tostring(t.spellRules[1].icon) .. tostring(t.spellRules[1].iconFrom) .. tostring(t.spellRules[2].icon),
        "nilnilnil", "an icon that would break the line isn't taken")
    -- The Spells tab: click the icon, pick one from the grid (as in Outfitter Forever), Use;
    -- right-click: its own again
    STATE.spellBook = { { name = "Claw", icon = 132140 }, { name = "Rake", icon = 132122 },
        { name = "Shred", icon = 136231 }, { name = "Rip", icon = 132152 } }
    STATE.macroIcons, STATE.macroItemIcons = {}, { 135274, 135275 }
    for i = 1, 100 do STATE.macroIcons[i] = 136000 + i end
    STATE.iconPaths[136007] = "Interface\\Icons\\Ability_Sword_Swing"
    STATE.spellIcons.Claw = 132140   -- (the game knows Claw by name)
    BT:OpenConfig()
    local win = BT.config
    win:ShowTab("spells")
    BT:RefreshConfig()
    local row = win.spellRows[1]
    assertEq(row.icon.tex.__texture, 132090, "the row shows the icon given")
    row.icon.__scripts.OnClick(row.icon, "LeftButton")
    local f = _G.BattleTextForeverIconPicker
    assertEq(f and f:IsShown(), true, "a click opens the icon picker")
    assertEq(f.title:GetText(), "Icon for Claw", "for that spell")
    local function shown()
        local out = {}
        for _, b in ipairs(f.buttons) do if b:IsShown() then out[#out + 1] = b.tex.__texture end end
        return table.concat(out, " ")
    end
    -- (Claw's own icon first, then the rest of your spellbook, each once)
    assertEq(shown(), "132140 132122 136231 132152", "your spells' icons to start with")
    f.setButtons.abilities.__scripts.OnClick(f.setButtons.abilities)
    assertEq(select(2, shown():gsub("%d+", "")), 60, "the game's ability icons: a page of 60")
    assertEq(f.bar:IsShown(), true, "with a scroll bar for the rest")
    f.grid.__scripts.OnMouseWheel(f.grid, -1)
    assertEq(f.buttons[1].tex.__texture, 136011, "the mouse wheel scrolls a row")
    f.bar:SetValue(999)
    f.grid.__scripts.OnMouseWheel(f.grid, -1)
    assertEq(f.buttons[1].tex.__texture, 136041, "no further than the last page")
    f.setButtons.items.__scripts.OnClick(f.setButtons.items)
    assertEq(shown(), "135274 135275", "item icons")
    f.setButtons.all.__scripts.OnClick(f.setButtons.all)
    assertEq(f.buttons[1].tex.__texture, 136001, "all of them")
    f.search:SetText("sword") f.search.__scripts.OnTextChanged(f.search)
    assertEq(shown(), "136007", "the search keeps icons by their file name")
    f.setButtons.spells.__scripts.OnClick(f.setButtons.spells)
    f.search:SetText("ra") f.search.__scripts.OnTextChanged(f.search)
    assertEq(shown(), "132122", "and your spells by name")
    f.search:SetText("12162") f.search.__scripts.OnTextChanged(f.search)
    assertEq(shown(), "132090", "a spell's ID shows its icon")
    f.search:SetText("") f.search.__scripts.OnTextChanged(f.search)
    f.buttons[2].__scripts.OnClick(f.buttons[2])
    assertEq(f.buttons[2].picked:IsShown(), true, "a click picks one")
    assertEq(rule.icon, 132090, "not used yet")
    f.cancel.__scripts.OnClick(f.cancel)
    assertEq(f:IsShown() or rule.icon ~= 132090, false, "Cancel leaves it as it was")
    row.icon.__scripts.OnClick(row.icon, "LeftButton")
    f.buttons[2].__scripts.OnClick(f.buttons[2])
    f.use.__scripts.OnClick(f.use)
    assertEq(tostring(rule.icon) .. " " .. tostring(rule.iconFrom), "132122 Rake", "Use: the picked one, from Rake")
    assertEq(f:IsShown(), false, "the picker closes")
    assertEq(row.icon.tex.__texture, 132122, "and the row shows it")
    row.icon.__scripts.OnClick(row.icon, "LeftButton")
    assertEq(f.buttons[2].picked:IsShown(), true, "opened again: the icon in use is picked")
    f.buttons[3].__scripts.OnDoubleClick(f.buttons[3])
    assertEq(rule.icon .. " " .. tostring(f:IsShown()), "136231 false", "a double-click uses it at once")
    row.icon.__scripts.OnClick(row.icon, "LeftButton")
    f.own.__scripts.OnClick(f.own)
    assertEq(tostring(rule.icon) .. " " .. tostring(f:IsShown()), "nil false", "Its own icon: the usual one again")
    BT:SetSpellIconTo(rule, 136231, "Shred")
    row.icon.__scripts.OnClick(row.icon, "RightButton")
    assertEq(rule.icon, nil, "right-click on the row: its own icon again")
    assertEq(row.icon.tex.__texture, 132140, "the row shows Claw's own")
    assertEq(BT:SetSpellIconTo(rule, "x:0|t"), nil, "an icon that would break the line isn't taken")
    STATE.spellBook, STATE.macroIcons, STATE.macroItemIcons, STATE.iconPaths = {}, {}, {}, {}
    STATE.spellIcons.Rake, STATE.spellIcons.Claw = nil, nil
    wipe(BT.db.spellRules)
    BT.rulesByName = nil
    BT:RefreshConfig()
    win:Hide()
    SetIcons(false)
    clear()
end)()

step("your hits and misses over the enemy's nameplate (Layout tab: Enemy nameplates)")
;(function()
    clear()
    STATE.unit.plateMob = { enemy = true, guid = "Creature-0-1-2-3-100-0000PL", target = "me" }
    STATE.unit.farMob = { enemy = true, guid = "Creature-0-1-2-3-100-0000FA", target = "me" }
    STATE.who.target, STATE.who.nameplate4, STATE.who.nameplate6 = "plateMob", "plateMob", "farMob"
    BT.hiddenSeen, BT.hiddenAt, BT.credits, BT.dots, BT.spellSchool, BT.schoolSeen = nil, nil, nil, nil, nil, nil
    -- The game has a nameplate for plateMob only (farMob's is off screen)
    local plate4 = CreateFrame("Frame", "NamePlate4", UIParent)
    local plates = { nameplate4 = plate4 }
    local hadPlates = C_NamePlate
    C_NamePlate = {
        GetNamePlateForUnit = function(unit)
            for token, p in pairs(plates) do if UnitIsUnit(token, unit) then return p end end
            return nil
        end,
        GetNamePlates = function() return { plate4 } end,
    }
    local onPlates = BT.plateArea.active
    SetIcons(false)
    local function wound(unit, amount) fire("UNIT_COMBAT", unit, "WOUND", "", amount, 1) BT:FlushHits(true) end

    wound("target", 28)
    assertEq(last("outgoing"), "28", "usually your hits show in Outgoing")
    assertEq(#onPlates, 0, "and nothing over nameplates")
    clear()

    BT.db.routeOutDamage, BT.db.plateX, BT.db.plateY = "plates", 20, 40
    assertEq(BT:Area("OutDamage"), "plates", "Your hits can go to Enemy nameplates")
    assertEq(BT:AreaUsed("outgoing"), true, "Outgoing still counts as used (its look, and the fallback)")
    BT.db.routeInDamage = "plates"
    assertEq(BT:Area("InDamage"), "incoming", "damage you take can't: it stays in its usual area")
    BT.db.routeInDamage = "incoming"
    wound("target", 31)
    assertEq(#lines("outgoing"), 0, "with Enemy nameplates, the hit isn't in Outgoing")
    assertEq(#onPlates, 1, "it's over a nameplate")
    local o = onPlates[1]
    assertEq(o.plate, plate4, "the nameplate of the mob it landed on")
    assertEq(o.text:GetText(), "31", "with the hit's text")
    Advance(0.5)
    assertEq(o.__rel, plate4, "anchored to that nameplate")
    assert(o.__pos[1] >= 0 and o.__pos[1] <= 40, "moved right by Left and right (20, give or take its spread): " .. o.__pos[1])
    assert(o.__pos[2] >= 40 and o.__pos[2] <= 70, "and up by Up and down (40, and its drift): " .. o.__pos[2])
    Advance(0.5)
    wound("nameplate4", 33)
    wound("nameplate4", 34)
    assertEq(#onPlates, 3, "more hits on it: more lines")
    assert(onPlates[2].py > onPlates[3].py, "one that comes right after another starts below it and pushes it up, so they don't cover each other")
    assertEq(BT:PlateFor(nil, STATE.unit.plateMob.guid), plate4, "a combat log line's mob (its GUID) finds its nameplate too")
    clear()
    -- A fight's worth of hits, a little apart (Tyler's screenshot: "Claw 36" under "Dodge 58"):
    -- no two lines over one nameplate ever cover each other, while they're on screen
    local function apart()
        local list = {}
        for _, l in ipairs(onPlates) do
            local t = FAKE_TIME - l.start
            if t >= 0 and t < l.duration then list[#list + 1] = { y = l.py + 30 * t / l.duration, h = l.size } end
        end
        for i = 1, #list do
            for j = i + 1, #list do
                if math.abs(list[i].y - list[j].y) < (list[i].h + list[j].h) / 2 then return false end
            end
        end
        return true
    end
    for i = 1, 12 do
        wound("target", 30 + i)
        assert(apart(), "lines over one nameplate never cover each other (hit " .. i .. ")")
        Advance(i % 3 == 0 and 0.05 or 0.3)
        assert(apart(), "nor as they drift (after hit " .. i .. ")")
    end
    clear()
    for i = 1, 9 do wound("target", 40 + i) end
    Advance(0.05)
    assertEq(#onPlates, 6, "a burst: six lines at most over one nameplate, the oldest go")
    assert(apart(), "and still apart")
    clear()
    assertEq(#onPlates, 0, "they fade like other lines")

    wound("nameplate6", 44)
    assertEq(last("outgoing"), "44", "a mob without a nameplate on screen: Outgoing, as before")
    assertEq(#onPlates, 0, "and not over some other nameplate")
    clear()

    -- The nameplate goes (out of sight, dead): its lines go with it, before the game hands it to another mob
    wound("target", 35)
    assertEq(#onPlates, 1, "a line over it")
    fire("NAME_PLATE_UNIT_REMOVED", "nameplate4")
    Advance(0.05)
    assertEq(#onPlates, 0, "the nameplate's gone: so is its line")
    wound("target", 36)
    plate4:Hide()
    assertEq(BT:PlateFor("target"), nil, "a hidden nameplate isn't used")
    Advance(0.05)
    assertEq(#onPlates, 0, "and a line over one that's hidden goes")
    wound("target", 37)
    assertEq(last("outgoing"), "37", "so a hit then shows in Outgoing")
    plate4:Show()
    clear()

    -- Misses can go there too, by their own choice
    fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1) BT:FlushHits(true)
    assertEq(last("outgoing"), "Dodge", "Your misses stay in Outgoing unless they're moved too")
    clear()
    BT.db.routeOutMisses = "plates"
    fire("UNIT_COMBAT", "target", "DODGE", "", 0, 1) BT:FlushHits(true)
    assertEq(#onPlates, 1, "moved: over the nameplate")
    assertEq(onPlates[1].text:GetText(), "Dodge", "the miss")
    clear()

    -- A game without the nameplate functions: Outgoing, and no error
    C_NamePlate = nil
    wound("target", 38)
    assertEq(last("outgoing"), "38", "no nameplates to ask about: Outgoing")
    clear()
    C_NamePlate = hadPlates

    -- The Layout tab offers it for your hits and misses only, and the offsets wait until it's picked
    BT.db.routeOutDamage, BT.db.routeOutMisses, BT.db.plateX, BT.db.plateY = "outgoing", "outgoing", 0, 10
    assertEq(BT:Choices("routeOutDamage").plates, true, "shared settings can carry it")
    STATE.who.target, STATE.who.nameplate4, STATE.who.nameplate6 = nil, nil, nil
    STATE.unit.plateMob, STATE.unit.farMob = nil, nil
    SetIcons(true)
end)()

assertClean("by the end")
print("ALL TESTS PASSED")
