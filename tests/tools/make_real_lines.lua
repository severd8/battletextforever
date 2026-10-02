-- Makes tests/real_lines.lua and tests/strings_enus.lua.
--
-- The lines are real: this runs the game's own Combat Log code
-- (CombatLogProcessor:GenerateMessage) on made-up combat events, with the Combat
-- Log's default settings, and saves the text it produces next to what BattleText
-- should read from it. It needs two things that aren't in this repository:
--
--   1. the game's interface code, exported from the client (the folder that
--      holds Interface/AddOns/Blizzard_CombatLogProcessor)
--   2. the game's English text as a Lua file of  _G["KEY"] = "text";  lines
--
--   lua5.1 tests/tools/make_real_lines.lua <interface code folder> <text file>
--
-- Run it again whenever the game's Combat Log code changes.
local ROOT = assert(arg[1], "usage: make_real_lines.lua <interface code folder> <text file>")
local GS = assert(arg[2], "usage: make_real_lines.lua <interface code folder> <text file>")
local REF = ROOT:gsub("/+$", "") .. "/Interface/AddOns/"
local OUT_LINES = arg[3] or "tests/real_lines.lua"
local OUT_STRINGS = arg[4] or "tests/strings_enus.lua"

-- WoW-style string.format: supports positional "%N$s"
local rawformat = string.format
local function wowformat(fmt, ...)
    local args, n = { ... }, select("#", ...)
    local seq = 0
    local out = fmt:gsub("%%(%d*)(%$?)([%-%+ #0]*%d*%.?%d*)([%a%%])", function(pos, dollar, flags, conv)
        if conv == "%" and pos == "" and flags == "" then return "%" end
        local idx
        if dollar == "$" then idx = tonumber(pos) else
            flags = pos .. flags
            seq = seq + 1
            idx = seq
        end
        local v = args[idx]
        if conv == "s" then
            if v == nil then error("format: nil for %s at arg " .. idx .. " in " .. fmt) end
            return rawformat("%" .. flags .. "s", tostring(v))
        elseif conv == "d" or conv == "x" or conv == "X" then
            return rawformat("%" .. flags .. conv, math.floor(tonumber(v)))
        else
            return rawformat("%" .. flags .. conv, v)
        end
    end)
    return out
end
string.format = wowformat
format = wowformat

-- bit library (32-bit, pure Lua)
bit = {}
local function tobits(a) local t = {} for i = 1, 32 do t[i] = a % 2; a = math.floor(a / 2) end return t end
function bit.band(a, b) local x, y, r = tobits(a), tobits(b), 0 for i = 32, 1, -1 do r = r * 2 + ((x[i] == 1 and y[i] == 1) and 1 or 0) end return r end
function bit.bor(...)
    local r = 0
    for _, v in ipairs({ ... }) do
        local x, y, o = tobits(r), tobits(v), 0
        for i = 32, 1, -1 do o = o * 2 + ((x[i] == 1 or y[i] == 1) and 1 or 0) end
        r = o
    end
    return r
end
function bit.bnot(a) return 4294967295 - a end

-- global strings
dofile(GS)

Enum = {
    CombatLogObject = { Empty = 0, AffiliationMine = 1, AffiliationParty = 2, AffiliationRaid = 4, AffiliationOutsider = 8,
        ReactionFriendly = 16, ReactionNeutral = 32, ReactionHostile = 64, ControlPlayer = 256, ControlNpc = 512,
        TypePlayer = 1024, TypeNpc = 2048, TypePet = 4096, TypeGuardian = 8192, TypeObject = 16384,
        Target = 65536, Focus = 131072, Maintank = 262144, Mainassist = 524288, None = 2147483648 },
    CombatLogMessageOrder = { Newest = 0, Oldest = 1 },
    CombatLogObjectTarget = { Raidtarget1 = 1, Raidtarget2 = 2, Raidtarget3 = 4, Raidtarget4 = 8, Raidtarget5 = 16,
        Raidtarget6 = 32, Raidtarget7 = 64, Raidtarget8 = 128 },
    Damageclass = { MaskNone = 0, MaskPhysical = 1, MaskHoly = 2, MaskFire = 4, MaskNature = 8, MaskFrost = 16,
        MaskShadow = 32, MaskArcane = 64 },
    PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4, Runes = 5, RunicPower = 6, SoulShards = 7,
        LunarPower = 8, HolyPower = 9, Alternate = 10, Maelstrom = 11, Chi = 12, Insanity = 13, ArcaneCharges = 16,
        Fury = 17, Pain = 18, Essence = 19 },
}
Constants = { CombatLogObjectTargetMasks = { COMBATLOG_OBJECT_RAID_TARGET_MASK = 255 } }
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
function GetCurrentEnvironment() return _G end
function SwapToGlobalEnvironment() end
Event = { RegisterCallback = function() end }
EventRegistry = { TriggerEvent = function() end }
function securecallfunction(f, ...) return f(...) end
function BreakUpLargeNumbers(n)
    local s = tostring(math.floor(n))
    local left, num = s:match("^(-?)(%d+)$")
    num = num:reverse():gsub("(%d%d%d)", "%1" .. LARGE_NUMBER_SEPERATOR):reverse()
    if num:sub(1, 1) == LARGE_NUMBER_SEPERATOR then num = num:sub(2) end
    return left .. num
end
local SCHOOLS = { [1] = "Physical", [2] = "Holy", [4] = "Fire", [8] = "Nature", [16] = "Frost", [32] = "Shadow", [64] = "Arcane",
    [20] = "Frostfire" }
C_Spell = { GetSchoolString = function(s) return SCHOOLS[s] end }
local O = Enum.CombatLogObject
local AFF, REA, CTL, TYP = 15, 240, 768, 64512
C_CombatLog = {
    DoesObjectMatchFilter = function(flags, mask)
        if type(flags) ~= "number" or type(mask) ~= "number" then return false end
        if mask == O.None then return flags == O.None end
        local m = bit.band(flags, mask)
        return bit.band(m, AFF) > 0 and bit.band(m, REA) > 0 and bit.band(m, CTL) > 0 and bit.band(m, TYP) > 0
    end,
    GetMessageLimit = function() return 300 end,
}
C_CombatLogSecure = {}
C_Timer = {}
C_DeathRecap = { GetRecapLink = function(id) return ("|Hdeath:%d|h[You died.]|h"):format(id) end }
PLAYER_GUID = "Player-5555-0ABCDEF1"
function UnitGUID(u) if u == "player" then return PLAYER_GUID end end
function GetUnitPowerBarStringsByID() return nil end
abs = math.abs

dofile(REF .. "Blizzard_CombatLogBase/Shared/CombatLogFilters.lua")
dofile(REF .. "Blizzard_CombatLogBase/Mainline/CombatLogConstants.lua")
dofile(REF .. "Blizzard_CombatLogBase/Mainline/CombatLogColors.lua")
dofile(REF .. "Blizzard_CombatLogBase/CombatLogUtil.lua")
dofile(REF .. "Blizzard_CombatLogProcessor/Blizzard_CombatLogProcessor.lua")

-- The Combat Log's default settings, read out of the game's own file
do
    local f = assert(io.open(REF .. "Blizzard_CombatLog/Mainline/Blizzard_CombatLog.lua"))
    local src = f:read("*a") f:close()
    local chunk = src:match("(COMBATLOG_DEFAULT_SETTINGS = %b{};)")
    assert(loadstring(chunk))()
end
local function CopyTable(t) local c = {} for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end return c end
local FILTER = { settings = CopyTable(COMBATLOG_DEFAULT_SETTINGS), colors = CopyTable(COMBATLOG_DEFAULT_COLORS) }
assert(FILTER.settings.fullText == false and FILTER.settings.braces == false and FILTER.settings.hideBuffs == true)

date = os.date

---------------------------------------------------------------------------
-- The made-up fight
---------------------------------------------------------------------------
local ME = { guid = PLAYER_GUID, name = "Abla", flags = 0x511 }                 -- mine, friendly, a player
local MOB = { guid = "Creature-0-1-2-3-4-000001", name = "Bristleback Hunter Fizzlesticks", flags = 0xa48 }
local PET = { guid = "Pet-0-1-2-3-4-000002", name = "Fluffy Zapsu", flags = 0x1111 }   -- mine, a pet
local FRIEND = { guid = "Player-5555-0ABCDEF2", name = "Anduin Gabgubman", flags = 0x514 }
local NOBODY = { guid = "0000000000000000", name = nil, flags = 2147483648 }
local function Mob(name) return { guid = "Creature-1", name = name, flags = 0xa48 } end

local OUT = {}
local settings   -- changes to the default settings for the next lines, or nil

-- expect: what Parser:Parse should return for the line (nil = nothing to show).
-- Every field BattleText acts on is compared, so leave out only what should be unset.
local function gen(id, expect, event, src, dst, ...)
    local filter = FILTER
    if settings then
        filter = { settings = CopyTable(COMBATLOG_DEFAULT_SETTINGS), colors = CopyTable(COMBATLOG_DEFAULT_COLORS) }
        for k, v in pairs(settings) do filter.settings[k] = v end
    end
    local text = CombatLogProcessor:GenerateMessage(filter, 1759400000, event, src.hideCaster or false,
        src.guid, src.name, src.flags, src.raid or 0, dst.guid, dst.name, dst.flags, dst.raid or 0, ...)
    assert(type(text) == "string", id .. ": the game's code made no line")
    OUT[#OUT + 1] = { id = id, raw = text, expect = expect }
end

local P, HOLY, F, N, S, A = 1, 2, 4, 8, 32, 64   -- spell schools
local MISSES = { "MISS", "DODGE", "PARRY", "BLOCK", "RESIST", "ABSORB", "IMMUNE", "EVADE", "DEFLECT" }
local function MissAmount(m) return (m == "BLOCK" or m == "RESIST" or m == "ABSORB") and 15 or nil end

-- SWING_DAMAGE: amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand
gen("swing", { kind = "damage", fromMe = true, melee = true, amount = 27, unit = "Physical" },
    "SWING_DAMAGE", ME, MOB, 27, -1, P, nil, nil, nil, false, false, false, false)
gen("swing, crit", { kind = "damage", fromMe = true, melee = true, amount = 56, unit = "Physical", crit = true },
    "SWING_DAMAGE", ME, MOB, 56, -1, P, nil, nil, nil, true, false, false, false)
gen("swing, glancing", { kind = "damage", fromMe = true, melee = true, amount = 20, unit = "Physical", glancing = true },
    "SWING_DAMAGE", ME, MOB, 20, -1, P, nil, nil, nil, false, true, false, false)
gen("swing, partly blocked", { kind = "damage", fromMe = true, melee = true, amount = 26, unit = "Physical", blocked = 3 },
    "SWING_DAMAGE", ME, MOB, 26, -1, P, nil, 3, nil, false, false, false, false)
gen("swing, overkill", { kind = "damage", fromMe = true, melee = true, amount = 17, unit = "Physical", overkill = 35 },
    "SWING_DAMAGE", ME, MOB, 52, 35, P, nil, nil, nil, false, false, false, false)
gen("swing, thousands, absorbed, crit",
    { kind = "damage", fromMe = true, melee = true, amount = 1234, unit = "Physical", absorbed = 1200, crit = true },
    "SWING_DAMAGE", ME, MOB, 1234, -1, P, nil, nil, 1200, true, false, false, false)
gen("swing, millions", { kind = "damage", fromMe = true, melee = true, amount = 1234567, unit = "Physical" },
    "SWING_DAMAGE", ME, MOB, 1234567, -1, P, nil, nil, nil, false, false, false, false)
gen("swing at me", { kind = "damage", toMe = true, melee = true, amount = 12, unit = "Physical", blocked = 3 },
    "SWING_DAMAGE", MOB, ME, 12, -1, P, nil, 3, nil, false, false, false, false)
gen("swing at me, crushing", { kind = "damage", toMe = true, melee = true, amount = 80, unit = "Physical", crushing = true },
    "SWING_DAMAGE", MOB, ME, 80, -1, P, nil, nil, nil, false, false, true, false)
gen("swing at me, crit", { kind = "damage", toMe = true, melee = true, amount = 80, unit = "Physical", crit = true },
    "SWING_DAMAGE", MOB, ME, 80, -1, P, nil, nil, nil, true, false, false, false)
gen("pet's swing", { kind = "damage", melee = true, amount = 20, unit = "Physical", srcGUID = PET.guid },
    "SWING_DAMAGE", PET, MOB, 20, -1, P, nil, nil, nil, false, false, false, false)
gen("swing at the pet", { kind = "damage", melee = true, amount = 9, unit = "Physical", srcGUID = MOB.guid },
    "SWING_DAMAGE", MOB, PET, 9, -1, P, nil, nil, nil, false, false, false, false)

-- SPELL_DAMAGE: spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing
local function spell(id, expect, src, dst, spellId, name, school, amount, resisted, blocked, absorbed, crit)
    gen(id, expect, "SPELL_DAMAGE", src, dst, spellId, name, school, amount, -1, school, resisted, blocked, absorbed,
        crit or false, false, false)
end
spell("spell", { kind = "damage", fromMe = true, spell = "Claw", spellId = 16827, amount = 50, unit = "Physical", blocked = 1 },
    ME, MOB, 16827, "Claw", P, 50, nil, 1)
spell("spell, crit", { kind = "damage", fromMe = true, spell = "Moonfire", spellId = 8921, amount = 112, unit = "Arcane", crit = true },
    ME, MOB, 8921, "Moonfire", A, 112, nil, nil, nil, true)
spell("spell, partly resisted", { kind = "damage", fromMe = true, spell = "Fireball", spellId = 133, amount = 75, unit = "Fire", resisted = 25 },
    ME, MOB, 133, "Fireball", F, 75, 25)
spell("spell, resisted, absorbed, crit",
    { kind = "damage", fromMe = true, spell = "Fireball", spellId = 133, amount = 2500, unit = "Fire", resisted = 1250, absorbed = 300, crit = true },
    ME, MOB, 133, "Fireball", F, 2500, 1250, nil, 300, true)
spell("spell of two schools", { kind = "damage", fromMe = true, spell = "Frostfire Bolt", spellId = 44614, amount = 90, unit = "Frostfire" },
    ME, MOB, 44614, "Frostfire Bolt", 20, 90)
spell("spell name with brackets", { kind = "damage", fromMe = true, spell = "Faerie Fire (Feral)", spellId = 16857, amount = 5, unit = "Nature" },
    ME, MOB, 16857, "Faerie Fire (Feral)", N, 5)
spell("spell name with a period", { kind = "damage", fromMe = true, spell = "Mr. Pinchy's Gift", spellId = 1, amount = 5, unit = "Nature" },
    ME, MOB, 1, "Mr. Pinchy's Gift", N, 5)
spell("spell name with a number", { kind = "damage", fromMe = true, spell = "Goblin Bomb 9000", spellId = 1, amount = 300, unit = "Fire" },
    ME, MOB, 1, "Goblin Bomb 9000", F, 300)
spell("spell name ending in a number", { kind = "damage", fromMe = true, spell = "Rocket 2", spellId = 1, amount = 7, unit = "Fire" },
    ME, MOB, 1, "Rocket 2", F, 7)
spell("spell name with an action word", { kind = "damage", fromMe = true, spell = "Critical hit Proc", spellId = 1, amount = 7, unit = "Fire" },
    ME, MOB, 1, "Critical hit Proc", F, 7)
spell("target name with a number", { kind = "damage", fromMe = true, spell = "Claw", spellId = 16827, amount = 50, unit = "Physical" },
    ME, Mob("Training Dummy 2"), 16827, "Claw", P, 50)
spell("target name with an action word", { kind = "damage", fromMe = true, spell = "Claw", spellId = 16827, amount = 50, unit = "Physical" },
    ME, Mob("Big hit Bob"), 16827, "Claw", P, 50)
spell("target name with a period", { kind = "damage", fromMe = true, spell = "Claw", spellId = 16827, amount = 50, unit = "Physical" },
    ME, Mob("Mr. Smite"), 16827, "Claw", P, 50)
spell("target with a raid mark", { kind = "damage", fromMe = true, spell = "Claw", spellId = 16827, amount = 50, unit = "Physical" },
    ME, { guid = MOB.guid, name = MOB.name, flags = MOB.flags, raid = 128 }, 16827, "Claw", P, 50)
spell("spell at me", { kind = "damage", toMe = true, spell = "Fireball", spellId = 133, amount = 84, unit = "Fire" },
    MOB, ME, 133, "Fireball", F, 84)
spell("spell at me, apostrophe in its name", { kind = "damage", toMe = true, spell = "Hunter's Mark", spellId = 1130, amount = 5, unit = "Arcane" },
    MOB, ME, 1130, "Hunter's Mark", A, 5)
spell("spell at me, caster's name has an action word", { kind = "damage", toMe = true, spell = "Fireball", spellId = 133, amount = 84, unit = "Fire" },
    Mob("Defias hit Squad"), ME, 133, "Fireball", F, 84)
spell("spell at me, caster's name has another action word", { kind = "damage", toMe = true, spell = "Fireball", spellId = 133, amount = 84, unit = "Fire" },
    Mob("The healed One"), ME, 133, "Fireball", F, 84)
spell("spell at myself", { kind = "damage", fromMe = true, toMe = true, spell = "Hellfire", spellId = 1949, amount = 30, unit = "Fire" },
    ME, ME, 1949, "Hellfire", F, 30)
spell("pet's spell", { kind = "damage", spell = "Bite", spellId = 17253, amount = 20, unit = "Physical", srcGUID = PET.guid },
    PET, MOB, 17253, "Bite", P, 20)

-- RANGE_DAMAGE / RANGE_MISSED
gen("shot", { kind = "damage", fromMe = true, spell = "Auto Shot", amount = 44, unit = "Physical" },
    "RANGE_DAMAGE", ME, MOB, 75, "Auto Shot", P, 44, -1, P, nil, nil, nil, false, false, false)
gen("shot, crit", { kind = "damage", fromMe = true, spell = "Auto Shot", amount = 88, unit = "Physical", crit = true },
    "RANGE_DAMAGE", ME, MOB, 75, "Auto Shot", P, 88, -1, P, nil, nil, nil, true, false, false)
gen("shot at me", { kind = "damage", toMe = true, spell = "Shoot", amount = 14, unit = "Physical" },
    "RANGE_DAMAGE", MOB, ME, 6660, "Shoot", P, 14, -1, P, nil, nil, nil, false, false, false)
for _, m in ipairs(MISSES) do
    local amt = MissAmount(m)
    gen("shot fails: " .. m, { kind = "miss", fromMe = true, spell = "Shot", missType = m, blocked = m == "BLOCK" and amt or nil,
        resisted = m == "RESIST" and amt or nil, absorbed = m == "ABSORB" and amt or nil },
        "RANGE_MISSED", ME, MOB, 75, "Auto Shot", P, m, false, amt, false)
end

-- Damage over time. A tick that's evaded or deflected says nothing more than "missed".
gen("tick", { kind = "damage", fromMe = true, spell = "Rend", spellId = 772, amount = 9, unit = "Physical", periodic = true },
    "SPELL_PERIODIC_DAMAGE", ME, MOB, 772, "Rend", P, 9, -1, P, nil, nil, nil, false, false, false)
gen("tick, absorbed, crit",
    { kind = "damage", fromMe = true, spell = "Corruption", spellId = 172, amount = 90, unit = "Shadow", absorbed = 10, crit = true, periodic = true },
    "SPELL_PERIODIC_DAMAGE", ME, MOB, 172, "Corruption", S, 90, -1, S, nil, nil, 10, true, false, false)
gen("tick on me", { kind = "damage", toMe = true, spell = "Poison", spellId = 744, amount = 6, unit = "Nature", periodic = true },
    "SPELL_PERIODIC_DAMAGE", MOB, ME, 744, "Poison", N, 6, -1, N, nil, nil, nil, false, false, false)
for _, m in ipairs(MISSES) do
    local shown = (m == "EVADE" or m == "DEFLECT") and "MISS" or m
    gen("tick fails: " .. m, { kind = "miss", fromMe = true, spell = "Rend", spellId = 772, missType = shown, periodic = true,
        absorbed = m == "ABSORB" and 15 or nil },
        "SPELL_PERIODIC_MISSED", ME, MOB, 772, "Rend", P, m, false, m == "ABSORB" and 15 or nil, false)
end

-- Thorns and the like. A fail that's absorbed or evaded says nothing more than "missed".
gen("damage shield", { kind = "damage", fromMe = true, spell = "Thorns", spellId = 467, amount = 3, unit = "Nature" },
    "DAMAGE_SHIELD", ME, MOB, 467, "Thorns", N, 3, -1, N, nil, nil, nil, false, false, false)
gen("damage shield on me", { kind = "damage", toMe = true, spell = "Thorns", spellId = 467, amount = 3, unit = "Nature" },
    "DAMAGE_SHIELD", MOB, ME, 467, "Thorns", N, 3, -1, N, nil, nil, nil, false, false, false)
for _, m in ipairs(MISSES) do
    local shown = (m == "ABSORB" or m == "EVADE") and "MISS" or m
    gen("damage shield fails: " .. m, { kind = "miss", fromMe = true, spell = "Thorns", spellId = 467, missType = shown },
        "DAMAGE_SHIELD_MISSED", ME, MOB, 467, "Thorns", N, m)
end
gen("damage shared out", { kind = "damage", fromMe = true, spell = "Soul Link", spellId = 25228, amount = 12, unit = "Shadow", split = true },
    "DAMAGE_SPLIT", ME, PET, 25228, "Soul Link", S, 12, -1, S, nil, nil, nil, false, false, false)
gen("damage shared to me", { kind = "damage", toMe = true, spell = "Soul Link", spellId = 25228, amount = 12, unit = "Shadow", split = true,
    srcGUID = PET.guid },
    "DAMAGE_SPLIT", PET, ME, 25228, "Soul Link", S, 12, -1, S, nil, nil, nil, false, false, false)
for _, t in ipairs({ "Falling", "Drowning", "Fire", "Lava", "Fatigue", "Slime" }) do
    gen("the world: " .. t, { kind = "damage", toMe = true, spell = t, amount = 123, unit = t == "Falling" and "Physical" or "Fire" },
        "ENVIRONMENTAL_DAMAGE", NOBODY, ME, t, 123, -1, t == "Falling" and P or F, nil, nil, nil, false, false, false)
end
gen("the world, nobody named", { kind = "damage", toMe = true, spell = "Falling", amount = 123, unit = "Physical" },
    "ENVIRONMENTAL_DAMAGE", { guid = NOBODY.guid, flags = NOBODY.flags, hideCaster = true }, ME, "Falling", 123, -1, P,
    nil, nil, nil, false, false, false)
gen("the world, thousands, absorbed", { kind = "damage", toMe = true, spell = "Falling", amount = 1234, unit = "Physical", absorbed = 20 },
    "ENVIRONMENTAL_DAMAGE", NOBODY, ME, "Falling", 1234, -1, P, nil, nil, 20, false, false, false)

-- SWING_MISSED: missType, isOffHand, amountMissed, critical
for _, m in ipairs(MISSES) do
    local amt = MissAmount(m)
    local b, r, a = m == "BLOCK" and amt or nil, m == "RESIST" and amt or nil, m == "ABSORB" and amt or nil
    gen("swing fails: " .. m, { kind = "miss", fromMe = true, melee = true, missType = m, blocked = b, resisted = r, absorbed = a },
        "SWING_MISSED", ME, MOB, m, false, amt, false)
    gen("swing at me fails: " .. m, { kind = "miss", toMe = true, melee = true, missType = m, blocked = b, resisted = r, absorbed = a },
        "SWING_MISSED", MOB, ME, m, false, amt, false)
end
gen("swing blocked for nothing", { kind = "miss", fromMe = true, melee = true, missType = "BLOCK", blocked = 0 },
    "SWING_MISSED", ME, MOB, "BLOCK", false, 0, false)

-- SPELL_MISSED: spellId, spellName, spellSchool, missType, isOffHand, amountMissed, critical
for _, m in ipairs({ "MISS", "DODGE", "PARRY", "BLOCK", "RESIST", "ABSORB", "IMMUNE", "EVADE", "DEFLECT", "REFLECT" }) do
    local amt = MissAmount(m)
    if m == "RESIST" then amt = 0 end   -- a full resist carries no amount
    local b, a = m == "BLOCK" and amt or nil, m == "ABSORB" and amt or nil
    gen("spell fails: " .. m, { kind = "miss", fromMe = true, spell = "Moonfire", spellId = 8921, missType = m, blocked = b, absorbed = a },
        "SPELL_MISSED", ME, MOB, 8921, "Moonfire", A, m, false, amt, false)
    gen("spell at me fails: " .. m, { kind = "miss", toMe = true, spell = "Fireball", spellId = 133, missType = m, blocked = b, absorbed = a },
        "SPELL_MISSED", MOB, ME, 133, "Fireball", F, m, false, amt, false)
end
gen("spell resisted, with an amount", { kind = "miss", fromMe = true, spell = "Moonfire", spellId = 8921, missType = "RESIST", resisted = 40 },
    "SPELL_MISSED", ME, MOB, 8921, "Moonfire", A, "RESIST", false, 40, false)
gen("spell with brackets in its name misses", { kind = "miss", fromMe = true, spell = "Faerie Fire (Feral)", spellId = 16857, missType = "MISS" },
    "SPELL_MISSED", ME, MOB, 16857, "Faerie Fire (Feral)", N, "MISS", false, nil, false)
gen("spell with brackets in its name is resisted", { kind = "miss", fromMe = true, spell = "Faerie Fire (Feral)", spellId = 16857, missType = "RESIST" },
    "SPELL_MISSED", ME, MOB, 16857, "Faerie Fire (Feral)", N, "RESIST", false, 0, false)

-- Heals: spellId, spellName, spellSchool, amount, overhealing, absorbed, critical
gen("heal on myself", { kind = "heal", fromMe = true, toMe = true, spell = "Healing Touch", spellId = 5185, amount = 380, unit = "Nature", overheal = 120 },
    "SPELL_HEAL", ME, ME, 5185, "Healing Touch", N, 500, 120, 0, false)
gen("heal on myself, crit", { kind = "heal", fromMe = true, toMe = true, spell = "Healing Touch", spellId = 5185, amount = 1500, unit = "Nature", crit = true },
    "SPELL_HEAL", ME, ME, 5185, "Healing Touch", N, 1500, 0, 0, true)
gen("heal on myself, all overheal", { kind = "heal", fromMe = true, toMe = true, spell = "Healing Touch", spellId = 5185, amount = 0, unit = "Nature", overheal = 500 },
    "SPELL_HEAL", ME, ME, 5185, "Healing Touch", N, 500, 500, 0, false)
gen("heal on a friend", { kind = "heal", fromMe = true, spell = "Rejuvenation", spellId = 774, amount = 61, unit = "Nature" },
    "SPELL_HEAL", ME, FRIEND, 774, "Rejuvenation", N, 61, 0, 0, false)
gen("heal on a friend, overheal, crit", { kind = "heal", fromMe = true, spell = "Flash Heal", spellId = 2061, amount = 1034, unit = "Holy", overheal = 200, crit = true },
    "SPELL_HEAL", ME, FRIEND, 2061, "Flash Heal", HOLY, 1234, 200, 0, true)
gen("a friend's heal on me", { kind = "heal", toMe = true, spell = "Flash Heal", spellId = 2061, amount = 300, unit = "Holy" },
    "SPELL_HEAL", FRIEND, ME, 2061, "Flash Heal", HOLY, 300, 0, 0, false)
gen("heal tick on myself", { kind = "heal", fromMe = true, toMe = true, spell = "Rejuvenation", spellId = 774, amount = 32, unit = "Nature", periodic = true },
    "SPELL_PERIODIC_HEAL", ME, ME, 774, "Rejuvenation", N, 32, 0, 0, false)
gen("heal tick on a friend, overheal, crit",
    { kind = "heal", fromMe = true, spell = "Rejuvenation", spellId = 774, amount = 22, unit = "Nature", overheal = 10, crit = true, periodic = true },
    "SPELL_PERIODIC_HEAL", ME, FRIEND, 774, "Rejuvenation", N, 32, 10, 0, true)
gen("a friend's heal tick on me", { kind = "heal", toMe = true, spell = "Renew", spellId = 139, amount = 45, unit = "Holy", periodic = true },
    "SPELL_PERIODIC_HEAL", FRIEND, ME, 139, "Renew", HOLY, 45, 0, 0, false)

-- Power gains: spellId, spellName, spellSchool, amount, overEnergize, powerType, alternatePowerType
gen("rage gained", { kind = "energize", fromMe = true, toMe = true, spell = "Bloodrage", spellId = 2687, amount = 10, unit = "Rage" },
    "SPELL_ENERGIZE", ME, ME, 2687, "Bloodrage", P, 10, 0, 1, nil)
gen("mana gained, thousands", { kind = "energize", fromMe = true, toMe = true, spell = "Evocation", spellId = 12051, amount = 1200, unit = "Mana" },
    "SPELL_ENERGIZE", ME, ME, 12051, "Evocation", A, 1200, 0, 0, nil)
gen("mana gained from a friend", { kind = "energize", toMe = true, spell = "Mana Spring", spellId = 5677, amount = 10, unit = "Mana" },
    "SPELL_ENERGIZE", FRIEND, ME, 5677, "Mana Spring", N, 10, 0, 0, nil)
gen("rage tick", { kind = "energize", fromMe = true, toMe = true, spell = "Bloodrage", spellId = 2687, amount = 1, unit = "Rage", periodic = true },
    "SPELL_PERIODIC_ENERGIZE", ME, ME, 2687, "Bloodrage", P, 1, 0, 1, nil)
gen("rage gained, some wasted", { kind = "energize", fromMe = true, toMe = true, spell = "Bloodrage", spellId = 2687, amount = 10, unit = "Rage" },
    "SPELL_ENERGIZE", ME, ME, 2687, "Bloodrage", P, 10, 4, 1, nil)

-- Kills and deaths
gen("my kill", { kind = "kill", fromMe = true }, "PARTY_KILL", ME, MOB)
gen("pet's kill", { kind = "kill", srcGUID = PET.guid }, "PARTY_KILL", PET, MOB)
gen("a mob dies", { kind = "died" }, "UNIT_DIED", NOBODY, MOB, 0, 0)
gen("I die (a death recap link, not a sentence)", { kind = "died", fromMe = true }, "UNIT_DIED", NOBODY, ME, 7, 0)
gen("a totem is destroyed", { kind = "died" }, "UNIT_DESTROYED", NOBODY, { guid = "Creature-9", name = "Searing Totem", flags = 0x2111 }, 0, 0)

-- Interrupts and dispels (read, not shown yet)
gen("interrupt", { kind = "interrupt", fromMe = true, spell = "Kick", spellId = 1766 },
    "SPELL_INTERRUPT", ME, MOB, 1766, "Kick", P, 133, "Fireball", F)
gen("interrupted", { kind = "interrupt", toMe = true, spell = "Pummel", spellId = 6552 },
    "SPELL_INTERRUPT", MOB, ME, 6552, "Pummel", P, 133, "Fireball", F)
gen("dispel", { kind = "dispel", fromMe = true, spell = "Purge", spellId = 370 },
    "SPELL_DISPEL", ME, MOB, 370, "Purge", N, 1243, "Power Word: Fortitude", HOLY, "BUFF")
gen("cleanse a friend", { kind = "dispel", fromMe = true, spell = "Cleanse", spellId = 4987 },
    "SPELL_DISPEL", ME, FRIEND, 4987, "Cleanse", HOLY, 172, "Corruption", S, "DEBUFF")
gen("cleanse myself", { kind = "dispel", fromMe = true, toMe = true, spell = "Cleanse", spellId = 4987 },
    "SPELL_DISPEL", ME, ME, 4987, "Cleanse", HOLY, 172, "Corruption", S, "DEBUFF")
gen("my buff is dispelled", { kind = "dispel", toMe = true, spell = "Purge", spellId = 370 },
    "SPELL_DISPEL", MOB, ME, 370, "Purge", N, 1243, "Power Word: Fortitude", HOLY, "BUFF")
gen("spell steal", { kind = "dispel", fromMe = true, spell = "Spellsteal", spellId = 30449 },
    "SPELL_STOLEN", ME, MOB, 30449, "Spellsteal", A, 1243, "Power Word: Fortitude", HOLY, "BUFF")

-- Lines BattleText has nothing to show for
gen("a spell's kill (\"You killed\" follows it)", nil, "SPELL_INSTAKILL", ME, MOB, 1, "Execute Order", P, nil, 0)
gen("leech", nil, "SPELL_LEECH", ME, MOB, 5138, "Drain Mana", S, 40, 0, 40, nil)
gen("drain", nil, "SPELL_DRAIN", ME, MOB, 5138, "Drain Mana", S, 40, 0, 40, nil)
gen("leech tick", nil, "SPELL_PERIODIC_LEECH", ME, MOB, 5138, "Drain Mana", S, 40, 0, 40, nil)
gen("extra attacks", nil, "SPELL_EXTRA_ATTACKS", ME, ME, 8516, "Windfury Attack", N, 2)
gen("summon", nil, "SPELL_SUMMON", ME, { guid = "Creature-9", name = "Searing Totem", flags = 0x2111 }, 3599, "Searing Totem", F)
gen("cast", nil, "SPELL_CAST_SUCCESS", ME, MOB, 133, "Fireball", F)

-- The same hit with the Combat Log's look changed (its Formatting and Colors settings)
local hit = { kind = "damage", fromMe = true, spell = "Claw", spellId = 16827, amount = 50, unit = "Physical", blocked = 1, crit = true }
for _, variant in ipairs({
    { "timestamps", { timestamp = true } },
    { "braces around names", { braces = true } },
    { "braces around names and spells", { braces = true, spellBraces = true } },
    { "names coloured", { unitColoring = true } },
    { "everything coloured", { unitColoring = true, abilityColoring = true, abilitySchoolColoring = true, actionColoring = true,
        amountColoring = true, amountSchoolColoring = true, schoolNameColoring = true } },
}) do
    settings = variant[2]
    spell("look: " .. variant[1], hit, ME, MOB, 16827, "Claw", P, 50, nil, 1, nil, true)
    gen("look: " .. variant[1] .. ", a miss", { kind = "miss", fromMe = true, melee = true, missType = "DODGE" },
        "SWING_MISSED", ME, MOB, "DODGE", false, nil, false)
end
settings = nil

---------------------------------------------------------------------------
-- Write the files
---------------------------------------------------------------------------
local function ser(t)
    if t == nil then return "nil" end
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    local p = {}
    for _, k in ipairs(keys) do
        local v = t[k]
        p[#p + 1] = k .. " = " .. (type(v) == "string" and rawformat("%q", v) or tostring(v))
    end
    return "{ " .. table.concat(p, ", ") .. " }"
end
local fh = assert(io.open(OUT_LINES, "w"))
fh:write("-- Made by tests/tools/make_real_lines.lua: Combat Log lines exactly as the game's own code\n")
fh:write("-- writes them, and what BattleText should read from each. Don't edit by hand.\n")
fh:write("return {\n")
for _, o in ipairs(OUT) do
    fh:write(rawformat("    { id = %q,\n      raw = %q,\n      expect = %s },\n", o.id, o.raw, ser(o.expect)))
end
fh:write("}\n")
fh:close()

-- The game's English text that BattleText reads
local wanted = {}
for key, value in pairs(_G) do
    if type(key) == "string" and type(value) == "string" then
        local keep = key:find("^UNIT_YOU") or key:find("^TEXT_MODE_A_STRING_RESULT_") or key:find("^STRING_SCHOOL_")
            or key:find("^LOOT_ITEM_[%u_]*SELF") or key == "LARGE_NUMBER_SEPERATOR"
            or (key:find("^ACTION_") and not key:find("FULL_TEXT") and not key:find("POSSESSIVE$") and not key:find("MASTER$"))
        for _, k in ipairs({ "MISS", "DODGE", "PARRY", "BLOCK", "RESIST", "ABSORB", "IMMUNE", "EVADE", "DEFLECT", "REFLECT",
            "MANA", "RAGE", "ENERGY", "FOCUS" }) do
            if key == k then keep = true end
        end
        if keep then wanted[#wanted + 1] = key end
    end
end
table.sort(wanted)
fh = assert(io.open(OUT_STRINGS, "w"))
fh:write("-- Made by tests/tools/make_real_lines.lua: the game's English text that BattleText reads.\n")
fh:write("-- Don't edit by hand.\n")
for _, key in ipairs(wanted) do fh:write(rawformat("_G[%q] = %q\n", key, _G[key])) end
fh:close()
print(#OUT .. " lines -> " .. OUT_LINES .. ", " .. #wanted .. " strings -> " .. OUT_STRINGS)
