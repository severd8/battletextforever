-- BattleText Forever: scrolling combat text for World of Warcraft: Forever.
-- Numbers come from the UNIT_COMBAT event (what happens to a unit: you, your
-- target, the mobs around you), and from the game's combat log lines whenever
-- the game lets an addon read them (see Parse.lua).

local ADDON, ns = ...
local BT = {}
ns.BT = BT
local Parser = ns.Parser
-- The look is the shared one of severd8's Forever addons (Theme.lua, loaded first)
local T = ns.Theme

BT.ICON = T.LOGO
BT.LOGO_TEXT = "|T" .. BT.ICON .. ":0|t"
local function Print(msg) print(T.CHAT_PREFIX .. ": " .. msg) end
BT.Print = Print

-- Text colors
BT.TEXT_COLORS = {
    melee     = { 1.00, 1.00, 1.00 },
    spell     = { 1.00, 0.86, 0.35 },
    heal      = { 0.30, 1.00, 0.35 },
    miss      = { 0.80, 0.80, 0.80 },
    inDamage  = { 1.00, 0.25, 0.25 },
    inAvoid   = { 0.55, 0.80, 1.00 },
    power     = { 0.45, 0.65, 1.00 },
    notify    = { 1.00, 0.85, 0.40 },
    combat    = { 1.00, 0.45, 0.20 },
    xp        = { 0.75, 0.50, 1.00 },
    loot      = { 1.00, 1.00, 1.00 },
    seal      = { 1.00, 0.92, 0.55 },
    buff      = { 0.55, 0.85, 1.00 },
}
-- What they start as; db.colors holds the ones you've changed (ApplyColors)
BT.DEFAULT_COLORS = {}
for k, c in pairs(BT.TEXT_COLORS) do BT.DEFAULT_COLORS[k] = { c[1], c[2], c[3] } end
-- The colors you can change, in the order the options list them
BT.COLOR_CHOICES = {
    { "melee", "Your hits" }, { "spell", "Your spells" }, { "miss", "Your misses" },
    { "inDamage", "Damage you take" }, { "inAvoid", "Attacks you avoid" }, { "heal", "Heals" },
    { "power", "Power gains" }, { "notify", "Notifications" }, { "combat", "Entering combat" },
    { "xp", "Experience" }, { "seal", "Seals" }, { "buff", "Buffs" },
}
-- Spell damage is tinted by its school (the game's own words for them)
local SCHOOL_KEYS = {
    { "STRING_SCHOOL_HOLY", "Holy", { 1.00, 0.92, 0.55 } },
    { "STRING_SCHOOL_FIRE", "Fire", { 1.00, 0.50, 0.10 } },
    { "STRING_SCHOOL_NATURE", "Nature", { 0.40, 1.00, 0.40 } },
    { "STRING_SCHOOL_FROST", "Frost", { 0.50, 0.90, 1.00 } },
    { "STRING_SCHOOL_SHADOW", "Shadow", { 0.72, 0.55, 1.00 } },
    { "STRING_SCHOOL_ARCANE", "Arcane", { 1.00, 0.55, 1.00 } },
}

-- The same schools as UNIT_COMBAT numbers them: 2 Holy, 4 Fire, 8 Nature...
local MASK_COLORS = {}
for i, school in ipairs(SCHOOL_KEYS) do MASK_COLORS[2 ^ i] = school[3] end

local DEFAULTS = {
    enabled = true,
    locked = true,
    font = "Default",
    fontSize = 20,
    critScale = 150,          -- crits, as a percent of the text size
    scrollTime = 3,           -- seconds a line takes to cross its area
    height = 240,             -- how far a line travels
    curved = true,            -- lines bow outward as they scroll
    scrollUp = false,         -- lines scroll up instead of down
    outline = "OUTLINE",      -- the outline round normal lines (one of BT.OUTLINES)
    critOutline = "OUTLINE",  -- and round crits
    sticky = true,            -- crits pop and hold in place
    -- Spell (and skill) icons and names, per section of the options
    outIcons = true, outNames = true,      -- your hits and misses
    inIcons = true, inNames = true,        -- what happens to you
    healIcons = true, healNames = true,    -- heals, yours and on you
    nIcons = true,                         -- notifications: loot and skill ups
    merge = true,             -- rapid hits of one spell add up on one line
    minDamage = 0,            -- hide your hits below this
    healArea = true,          -- heals (yours and on you) scroll in their own area
    healOver = true,          -- show overhealing after a heal, when the game says
    minHeal = 0,              -- hide heals below this
    healWho = true,           -- "on <name>" after a heal you do, when the game says who
    shortNumbers = false,     -- 12,345 as 12.3k
    colors = {},              -- text colors you've changed, by BT.TEXT_COLORS key
    -- Each area's text size (percent of the text size) and opacity (percent)
    outSize = 100, outAlpha = 100, inSize = 100, inAlpha = 100,
    healSize = 100, healAlpha = 100, nSize = 100, nAlpha = 100,
    outDamage = true, outHeals = true, outMisses = true, outPet = true, outShields = true,
    outSeals = true,          -- name a seal's hit beside your swing
    shieldAmounts = {},       -- learned: what each damage shield of yours hits for (by its name)
    inDamage = true, inHeals = true, inMisses = true, inPower = false,
    nCombat = true, nKill = true, nXP = true, nRep = true, nHonor = true,
    nLoot = true, nMoney = false, nSkill = true, nSeals = true,
    nBuffs = false,           -- a line when a buff goes on or comes off (out of a fight only)
    hideBlizzard = false,
    minimap = true,
    startReminder = true,   -- a line in chat after logging in, while Start hasn't been clicked
    minimapAngle = 215,
    debug = false,
    areas = {
        incoming = { x = -230, y = 20 },
        outgoing = { x = 230, y = 20 },
        notify = { x = 0, y = 170 },
        heal = { x = 0, y = -190 },
    },
}
BT.DEFAULTS = DEFAULTS

-- "Default" is the game's own font for your language. The next four come with
-- the game; the rest are in this addon's Fonts folder (each under its own
-- open licence, in Fonts/Licenses).
local FONT_DIR = "Interface\\AddOns\\BattleTextForever\\Fonts\\"
BT.FONTS = {
    { name = "Default" },
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { name = "Skurri", path = "Fonts\\SKURRI.TTF" },
    { name = "Anton", path = FONT_DIR .. "Anton-Regular.ttf" },
    { name = "Archivo Black", path = FONT_DIR .. "ArchivoBlack-Regular.ttf" },
    { name = "Bangers", path = FONT_DIR .. "Bangers-Regular.ttf" },
    { name = "Barlow Condensed", path = FONT_DIR .. "BarlowCondensed-Bold.ttf" },
    { name = "Bebas Neue", path = FONT_DIR .. "BebasNeue-Regular.ttf" },
    { name = "Fira Sans", path = FONT_DIR .. "FiraSans-Bold.ttf" },
    { name = "Lato", path = FONT_DIR .. "Lato-Bold.ttf" },
    { name = "Luckiest Guy", path = FONT_DIR .. "LuckiestGuy-Regular.ttf" },
    { name = "Permanent Marker", path = FONT_DIR .. "PermanentMarker-Regular.ttf" },
    { name = "Poppins", path = FONT_DIR .. "Poppins-Bold.ttf" },
    { name = "Press Start 2P", path = FONT_DIR .. "PressStart2P-Regular.ttf" },
    { name = "PT Sans Narrow", path = FONT_DIR .. "PTSansNarrow-Bold.ttf" },
    { name = "Rajdhani", path = FONT_DIR .. "Rajdhani-Bold.ttf" },
    { name = "Russo One", path = FONT_DIR .. "RussoOne-Regular.ttf" },
    { name = "Ubuntu", path = FONT_DIR .. "Ubuntu-Bold.ttf" },
}

-- How thick the outline round the letters is: the game's font flags
BT.OUTLINES = {
    { name = "None", flags = "" },
    { name = "Thin", flags = "OUTLINE" },
    { name = "Thick", flags = "THICKOUTLINE" },
}

-- Scroll areas. dir: which way a curved line bows (-1 left, 1 right, 0 none).
BT.AREAS = {
    incoming = { label = "Incoming", dir = -1, justify = "RIGHT", prefix = "in" },
    outgoing = { label = "Outgoing", dir = 1, justify = "LEFT", prefix = "out" },
    notify   = { label = "Notifications", dir = 0, justify = "CENTER", short = true, prefix = "n" },
    heal     = { label = "Healing", dir = 0, justify = "CENTER", heightScale = 0.6, prefix = "heal" },
}
local AREA_WIDTH = 60        -- how far a curved line bows out
local MAX_DELAY = 1.2        -- a line never waits longer than this for room
local MERGE_WINDOW = 0.5

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) == true end
local function Num(v) if IsSecret(v) or type(v) ~= "number" then return nil end return v end
local function Str(v) if IsSecret(v) or type(v) ~= "string" then return nil end return v end
BT.IsSecret, BT.Num, BT.Str = IsSecret, Num, Str

-- A yes-or-no question for the game, answered with a plain true or false
-- (false when the game hides the answer, or doesn't have the function)
local function Flag(fn, ...)
    if not fn then return false end
    local ok, v = pcall(fn, ...)
    return ok and not IsSecret(v) and (v == true or v == 1)
end

local function FillDefaults(t, defaults)
    for k, v in pairs(defaults) do
        if t[k] == nil then
            t[k] = type(v) == "table" and FillDefaults({}, v) or v
        elseif type(v) == "table" and type(t[k]) == "table" then
            FillDefaults(t[k], v)
        end
    end
    return t
end

-- Settings that were renamed: an old one becomes the new ones it was split into
local SPLIT_SETTINGS = {
    icons = { "outIcons", "inIcons", "healIcons", "nIcons" },
    spellNames = { "outNames", "inNames", "healNames" },
}
function BT:MoveOldSettings(db)
    for old, new in pairs(SPLIT_SETTINGS) do
        if db[old] ~= nil then
            for _, key in ipairs(new) do
                if db[key] == nil then db[key] = db[old] end
            end
            db[old] = nil
        end
    end
end

local function Commas(n)
    -- "Short numbers": 12.3k, 1.2m
    if BT.db and BT.db.shortNumbers and type(n) == "number" and n >= 10000 then
        local v, unit = n / 1000, "k"
        if n >= 1000000 then v, unit = n / 1000000, "m" end
        return (("%.1f"):format(v):gsub("%.0$", "")) .. unit
    end
    if BreakUpLargeNumbers then
        local ok, s = pcall(BreakUpLargeNumbers, n)
        if ok and Str(s) then return s end
    end
    return tostring(n)
end

---------------------------------------------------------------------------
-- Scroll areas and the lines moving through them
---------------------------------------------------------------------------
function BT:FontPath()
    for _, f in ipairs(self.FONTS) do
        if f.name == self.db.font and f.path then return f.path end
    end
    return Str(STANDARD_TEXT_FONT) or "Fonts\\FRIZQT__.TTF"
end

-- The font flags for a line: crits have their own outline
function BT:OutlineFlags(crit)
    local flags = crit and self.db.critOutline or self.db.outline
    for _, o in ipairs(self.OUTLINES) do
        if o.flags == flags then return flags end
    end
    return "OUTLINE"
end

function BT:BuildAreas()
    self.areas = {}
    for key, def in pairs(self.AREAS) do
        local a = CreateFrame("Frame", "BattleTextForever" .. def.label, UIParent)
        a:SetFrameStrata("HIGH")
        a.key, a.def = key, def
        a.active, a.pool, a.recent = {}, {}, {}

        -- Shown while unlocked: a box to drag, with the header bar along its top
        local mover = CreateFrame("Frame", nil, a)
        mover:SetAllPoints()
        T.Panel(mover, 0.6)
        mover.header = CreateFrame("Frame", nil, mover)
        mover.header:SetPoint("TOPLEFT")
        mover.header:SetPoint("TOPRIGHT")
        mover.header:SetHeight(18)
        T.HeaderStrip(mover.header, def.label)
        mover.header:FitLogo(18)
        mover.label = mover.header.text
        mover:EnableMouse(true)
        mover:RegisterForDrag("LeftButton")
        a:SetMovable(true)
        a:SetClampedToScreen(true)
        mover:SetScript("OnDragStart", function() a:StartMoving() end)
        mover:SetScript("OnDragStop", function()
            a:StopMovingOrSizing()
            BT:SaveAreaPosition(a)
        end)
        mover:Hide()
        a.mover = mover
        self.areas[key] = a
    end
    self:ApplyAreas()

    local driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", function() BT:Animate(GetTime()) end)
    self.driver = driver
end

-- An area's own setting: "Size" or "Alpha" (db.outSize, db.healAlpha...)
function BT:AreaSetting(a, what)
    return self.db[a.def.prefix .. what]
end

function BT:AreaHeight(a)
    if a.def.short then return math.floor(self.db.height * 0.45) end
    if a.def.heightScale then return math.floor(self.db.height * a.def.heightScale) end
    return self.db.height
end

-- Seconds a line takes to cross an area
function BT:ScrollTime(a)
    if a.def.short then return math.max(1.5, self.db.scrollTime * 0.7) end
    return self.db.scrollTime
end

-- Size, place and (un)lock the areas from the settings
function BT:ApplyAreas()
    if not self.areas then return end
    for key, a in pairs(self.areas) do
        local pos = self.db.areas[key]
        a:SetSize(a.def.dir == 0 and 220 or 150, self:AreaHeight(a))
        a:ClearAllPoints()
        a:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
        a.mover:SetShown(not self.db.locked)
    end
end

function BT:SaveAreaPosition(a)
    local cx, cy = a:GetCenter()
    local ux, uy = UIParent:GetCenter()
    cx, cy, ux, uy = Num(cx), Num(cy), Num(ux), Num(uy)
    if not (cx and cy and ux and uy) then return end
    local pos = self.db.areas[a.key]
    pos.x, pos.y = math.floor(cx - ux + 0.5), math.floor(cy - uy + 0.5)
    a:ClearAllPoints()
    a:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
end

function BT:ResetPositions()
    for key, pos in pairs(DEFAULTS.areas) do
        self.db.areas[key].x, self.db.areas[key].y = pos.x, pos.y
    end
    self:ApplyAreas()
end

local function AcquireLine(a)
    local o = table.remove(a.pool)
    if not o then
        o = CreateFrame("Frame", nil, a)
        o:SetSize(10, 10)
        o.text = o:CreateFontString(nil, "OVERLAY")
    end
    return o
end

local function ReleaseLine(a, o)
    o:Hide()
    o.key = nil
    a.pool[#a.pool + 1] = o
end

-- Where a heal goes: the Healing area when it's turned on, else the area given
function BT:HealArea(areaKey)
    return self.db.healArea and "heal" or areaKey
end

-- " on Name" for a heal of yours on someone else, when the game lets the name
-- be read (it can hide it). Never for your pet or yourself.
function BT:HealedName(unit)
    if not self.db.healWho or not unit or unit == "pet" then return "" end
    if Flag(UnitIsUnit, unit, "player") or Flag(UnitIsUnit, unit, "pet") then return "" end
    local ok, name = pcall(UnitName, unit)
    name = ok and Str(name)
    if not name or name == "" then return "" end
    return " |cffc9f7cc" .. name .. "|r"
end

-- Whether a heal of n is big enough to show (a hidden amount always is)
function BT:HealShown(n)
    return type(n) ~= "number" or n >= (self.db.minHeal or 0)
end

-- Puts a line of text into an area.
--   color = { r, g, b }
--   opts.crit    bigger, and sticky if that's turned on
--   opts.key     lines with the same key that arrive together add up (needs opts.amount)
--   opts.format  how to write a merged line: function(total, count) -> text
--   opts.secret  a value the addon can't read; the game itself writes it after the
--                text (and opts.after follows it)
function BT:Emit(areaKey, text, color, opts)
    local a = self.areas and self.areas[areaKey]
    if not a or not (self.db.enabled or self.testing) then return end
    opts = opts or {}
    local now = GetTime()

    -- Add to a line that just started, instead of a new one
    if opts.key and opts.amount and self.db.merge and not opts.crit then
        local r = a.recent[opts.key]
        if r and r.line.key == opts.key and now - r.time <= MERGE_WINDOW and now - r.born < 1 then
            r.total, r.count, r.time = r.total + opts.amount, r.count + 1, now
            r.line.text:SetText(opts.format(r.total, r.count))
            return r.line
        end
    end

    local o = AcquireLine(a)
    local size = self.db.fontSize * (self:AreaSetting(a, "Size") or 100) / 100
    if opts.crit then size = size * self.db.critScale / 100 end
    size = math.floor(size + 0.5)
    local flags = self:OutlineFlags(opts.crit)
    if not o.text:SetFont(self:FontPath(), size, flags) and STANDARD_TEXT_FONT then
        o.text:SetFont(STANDARD_TEXT_FONT, size, flags)
    end
    if IsSecret(opts.secret) then   -- (never compare a secret, even with nil: that throws)
        o.text:SetFormattedText("%s%s%s", text, opts.secret, opts.after or "")
    else
        o.text:SetText(text)
    end
    o.text:SetTextColor(color[1], color[2], color[3])
    o.size = size
    o.sticky = opts.crit and self.db.sticky or false
    o.key = nil
    -- Scrolling lines grow away from the middle of the screen. A crit that holds
    -- grows the other way, so it never sits on top of them.
    local anchor = a.def.justify
    if o.sticky and a.def.dir ~= 0 then anchor = a.def.dir > 0 and "RIGHT" or "LEFT" end
    if o.anchor ~= anchor then
        o.anchor = anchor
        o.text:ClearAllPoints()
        o.text:SetPoint(anchor, o, anchor, 0, 0)
        o.text:SetJustifyH(anchor)
    end

    if o.sticky then
        o.start, o.duration = now, 1.7
        -- The lowest free place among the crits still holding
        local taken = {}
        for _, other in ipairs(a.active) do
            if other.sticky and now - other.start < other.duration then taken[other.slot] = true end
        end
        local slot = 0
        while taken[slot] do slot = slot + 1 end
        o.slot = slot
    else
        local duration = self:ScrollTime(a)
        local speed = self:AreaHeight(a) / duration
        -- Keep a line's height between this one and the one before
        local start = now
        if a.lastStart then
            start = math.max(now, a.lastStart + (math.max(size, a.lastSize) + 2) / speed)
        end
        -- Crowded: rather than keep this line waiting, the lines ahead of it move along
        local over = (start - now) - MAX_DELAY
        if over > 0 then
            for _, other in ipairs(a.active) do
                if not other.sticky then other.start = other.start - over end
            end
            start = start - over
        end
        a.lastStart, a.lastSize = start, size
        o.start, o.duration = start, duration
    end
    o:SetAlpha(0)
    o:Show()
    a.active[#a.active + 1] = o
    -- Only a plain scrolling line can be added to later (a crit keeps its own number)
    if opts.key and opts.amount and not opts.crit then
        o.key = opts.key
        a.recent[opts.key] = { line = o, time = now, born = now, total = opts.amount, count = 1 }
    end
    return o
end

-- Moves every line to where it belongs at time `now`
function BT:Animate(now)
    if not self.areas then return end
    for _, a in pairs(self.areas) do
        local h = self:AreaHeight(a)
        local n = #a.active
        for i = n, 1, -1 do
            local o = a.active[i]
            local t = now - o.start
            if t >= o.duration then
                table.remove(a.active, i)
                ReleaseLine(a, o)
            elseif t >= 0 then
                local p = t / o.duration
                local x, y, alpha, scale = 0, 0, 1, 1
                if o.sticky then
                    if a.def.dir == 0 then
                        y = o.size + o.slot * (o.size + 4)        -- above the notifications
                    else
                        x = -a.def.dir * 14                       -- beside the scrolling lines
                        y = -h / 2 + o.slot * (o.size + 4)
                    end
                    if t < 0.15 then scale = 1 + 0.7 * (1 - t / 0.15) end
                    if t > o.duration - 0.4 then alpha = (o.duration - t) / 0.4 end
                else
                    y = self.db.scrollUp and -(1 - p) * h or -p * h
                    if self.db.curved and a.def.dir ~= 0 then
                        x = a.def.dir * AREA_WIDTH * (1 - (2 * p - 1) ^ 2)
                    end
                    if p < 0.08 then alpha = p / 0.08 elseif p > 0.75 then alpha = (1 - p) / 0.25 end
                end
                o:SetScale(scale)
                o:ClearAllPoints()
                o:SetPoint(o.anchor, a, "TOP", x / scale, y / scale)
                o:SetAlpha(alpha * (self:AreaSetting(a, "Alpha") or 100) / 100)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Turning combat into lines of text
---------------------------------------------------------------------------
function BT:SchoolColor(unit)
    if not self.schools then
        self.schools = {}
        for _, s in ipairs(SCHOOL_KEYS) do
            local word = Str(_G[s[1]]) or s[2]
            self.schools[word:lower()] = s[3]
        end
    end
    return unit and self.schools[unit:lower()]
end

-- A spell's icon as text, by its ID or name
function BT:IconText(spell)
    if not spell then return "" end
    self.iconCache = self.iconCache or {}
    local cached = self.iconCache[spell]
    if cached == nil then
        cached = false
        if C_Spell and C_Spell.GetSpellTexture then
            local ok, tex = pcall(C_Spell.GetSpellTexture, spell)
            if ok and not IsSecret(tex) and tex then cached = "|T" .. tex .. ":0|t " end
        end
        self.iconCache[spell] = cached
    end
    return cached or ""
end

-- A spell after a number, on lines about you: " <icon> Fireball", either part
-- left out when it's turned off or unknown
local function SpellAfter(icon, name)
    if name then return " " .. icon .. name end
    if icon ~= "" then return " " .. icon:gsub(" $", "") end
    return ""
end

-- "(3 blocked)" style notes after a number
local function Partials(info)
    local parts = {}
    if info.blocked then parts[#parts + 1] = Commas(info.blocked) .. " blocked" end
    if info.absorbed then parts[#parts + 1] = Commas(info.absorbed) .. " absorbed" end
    if info.resisted then parts[#parts + 1] = Commas(info.resisted) .. " resisted" end
    if info.glancing then parts[#parts + 1] = "glancing" end
    if info.crushing then parts[#parts + 1] = "crushing" end
    if #parts == 0 then return "" end
    return " |cffb0b0b0(" .. table.concat(parts, ", ") .. ")|r"
end

-- The game's own short word for a way of missing: "Dodge", "Parry"
local MISS_TEXT = { MISS = "Miss", DODGE = "Dodge", PARRY = "Parry", BLOCK = "Block", RESIST = "Resist",
    ABSORB = "Absorb", IMMUNE = "Immune", EVADE = "Evade", DEFLECT = "Deflect", REFLECT = "Reflect",
    MISFIRE = "Misfire" }
local function MissText(missType)
    missType = missType or "MISS"
    return Str(_G[missType]) or MISS_TEXT[missType] or MISS_TEXT.MISS
end
BT.MissText = MissText

-- A spell's icon and name as one section of the options shows them
-- (section: "out", "in" or "heal"); either is left out when it's turned off
function BT:SpellParts(section, icon, name)
    local db = self.db
    return db[section .. "Icons"] and icon or "", db[section .. "Names"] and name or nil
end

-- Your pet's line: the one who did it is your pet (the line's link says who)
function BT:IsPetLine(info)
    if info.fromMe or not info.srcGUID or not UnitGUID then return false end
    local ok, guid = pcall(UnitGUID, "pet")
    guid = ok and Str(guid) or nil
    return guid ~= nil and guid == info.srcGUID
end

-- What happens to you comes from UNIT_COMBAT, unless the combat log is
-- delivering it (the player picked a filter that includes it). fromLog[what]
-- counts the UNIT_COMBAT events since the log last delivered one: after three
-- with nothing from the log, the filter has changed and UNIT_COMBAT takes over.
function BT:NoteLogIncoming(what)
    self.fromLog = self.fromLog or {}
    self.fromLog[what] = 0
end

function BT:LogCovers(what)
    local n = self.fromLog and self.fromLog[what]
    if not n then return false end
    if n >= 3 then
        self.fromLog[what] = nil
        return false
    end
    self.fromLog[what] = n + 1
    return true
end

function BT:LogDelivers(what)
    return self.fromLog ~= nil and self.fromLog[what] ~= nil
end

-- One parsed combat log line (see Parser:Parse). Returns true if it's a kind
-- of line BattleText shows (even if a setting hides it), false if not.
function BT:ShowCombat(info)
    local db, C = self.db, self.TEXT_COLORS
    local spellIcon = self:IconText(info.spellId or info.spell)
    local section = info.kind == "heal" and "heal" or info.toMe and "in" or "out"
    local icon, name = self:SpellParts(section, spellIcon, info.spell)
    local mine = info.fromMe == true
    local pet = not mine and self:IsPetLine(info)
    local outLabel = icon .. (name and (name .. " ") or "") .. (pet and "(Pet) " or "")

    if info.kind == "damage" then
        if not info.amount then return false end
        if info.toMe then
            -- Damage you do to yourself is in the log either way; UNIT_COMBAT shows it
            if mine and not self:LogDelivers("damage") then return true end
            if not mine then self:NoteLogIncoming("damage") end
            if db.inDamage then
                local text = "-" .. Commas(info.amount) .. SpellAfter(icon, name) .. Partials(info)
                self:Emit("incoming", text, C.inDamage, { crit = info.crit or info.crushing })
            end
            return true
        elseif (mine or pet) and not info.split then
            if pet and not db.outPet then return true end
            if not db.outDamage or info.amount < db.minDamage then return true end
            local color = (info.spell and (self:SchoolColor(info.unit) or C.spell)) or C.melee
            self:Emit("outgoing", outLabel .. Commas(info.amount) .. Partials(info), color, {
                crit = info.crit,
                key = (pet and "pet:" or "") .. (info.spellId or info.spell or "melee"),
                amount = info.amount,
                format = function(total, count)
                    return outLabel .. Commas(total) .. " |cffb0b0b0(x" .. count .. ")|r"
                end,
            })
            return true
        end
    elseif info.kind == "heal" then
        if not info.amount then return false end
        local over = (db.healOver and info.overheal) and (" |cffb0b0b0(" .. Commas(info.overheal) .. " over)|r") or ""
        local nothing = info.amount == 0 and info.overheal   -- all of it was overhealing
        if info.toMe then
            if mine then self.lastSelfHeal = GetTime() else self:NoteLogIncoming("heal") end
            if nothing or not self:HealShown(info.amount) then return true end
            if db.inHeals then
                self:Emit(self:HealArea("incoming"), "+" .. Commas(info.amount) .. SpellAfter(icon, name) .. over,
                    C.heal, { crit = info.crit })
            elseif mine and db.outHeals then
                self:Emit(self:HealArea("outgoing"), outLabel .. "+" .. Commas(info.amount) .. over, C.heal,
                    { crit = info.crit })
            end
            return true
        elseif mine or pet then
            if pet and not db.outPet then return true end
            if db.outHeals and not nothing and self:HealShown(info.amount) then
                self:Emit(self:HealArea("outgoing"), outLabel .. "+" .. Commas(info.amount) .. over, C.heal,
                    { crit = info.crit })
            end
            return true
        end
    elseif info.kind == "miss" then
        local word = MissText(info.missType)
        if info.toMe then
            if not mine then self:NoteLogIncoming("miss") end
            if db.inMisses and not mine then
                self:Emit("incoming", word .. SpellAfter(icon, name), C.inAvoid)
            end
            return true
        elseif mine or pet then
            if pet and not db.outPet then return true end
            if db.outMisses then self:Emit("outgoing", outLabel .. word, C.miss) end
            return true
        end
    elseif info.kind == "energize" then
        if not info.amount then return false end
        if info.toMe then
            self:NoteLogIncoming("power")
            if db.inPower then
                self:Emit("incoming", "+" .. Commas(info.amount) .. (info.unit and (" " .. info.unit) or ""), C.power)
            end
            return true
        end
    elseif info.kind == "kill" then
        if mine then
            if db.nKill then self:Emit("notify", "Killing blow!", C.combat, { crit = true }) end
            return true
        end
    end
    return false
end

-- UNIT_COMBAT for yourself: damage, heals and power you take, with no spell
-- names. Used for whatever the combat log isn't delivering.
local function PowerName()
    if not UnitPowerType then return nil end
    local ok, _, token = pcall(UnitPowerType, "player")
    token = ok and Str(token) or nil
    return token and Str(_G[token]) or nil
end

function BT:OnUnitCombat(unit, action, flag, amount, school)
    unit = Str(unit)
    if not unit then return end
    if unit ~= "player" then return self:OnUnitHit(unit, action, flag, amount, school) end
    action, flag = Str(action), Str(flag)
    if self.db.debug then
        self:Record("UNIT_COMBAT player " .. tostring(action) .. " " .. tostring(flag) .. " "
            .. (IsSecret(amount) and "(hidden amount)" or tostring(amount)))
    end
    if not action then return end
    if action == "WOUND" then self:ConfirmShield(GetTime()) end
    local db, C = self.db, self.TEXT_COLORS
    local crit = flag == "CRITICAL" or flag == "CRUSHING"
    local secret = IsSecret(amount)
    local n = Num(amount)
    if action == "WOUND" then
        if secret or (n and n > 0) then
            self:Queue({ blow = true })   -- (a blow that landed: see the hit for nothing, below)
            if self:LogCovers("damage") or not db.inDamage then return end
            if secret then
                self:Emit("incoming", "-", C.inDamage, { crit = crit, secret = amount })
            else
                self:Emit("incoming", "-" .. Commas(n), C.inDamage, { crit = crit })
            end
        else
            -- No damage: fully absorbed, blocked or resisted, or a plain miss
            if self:LogCovers("miss") or not db.inMisses then return end
            if flag and MISS_TEXT[flag] then
                self:Emit("incoming", MissText(flag), C.inAvoid)
            else
                -- Some attacks arrive in two parts, one of them for nothing (a mob's special
                -- attack: "WOUND 0" and "WOUND 33" in one frame). That's no miss: it's shown
                -- as one only if no blow landed on you in the same frame (ResolveFrame).
                self:Queue({ nothing = true })
            end
        end
    elseif action == "HEAL" then
        if self:LogCovers("heal") or not db.inHeals then return end
        -- Your own heals on yourself also come from the combat log, with the
        -- spell's name. Wait a moment to see whether this is one of those.
        local function show()
            if BT.lastSelfHeal and GetTime() - BT.lastSelfHeal < 0.6 then return end
            if BT:LogDelivers("heal") then return end   -- the log's line for it arrived meanwhile
            if secret then
                BT:Emit(BT:HealArea("incoming"), "+", C.heal, { crit = crit, secret = amount })
            elseif n and n > 0 and BT:HealShown(n) then
                BT:Emit(BT:HealArea("incoming"), "+" .. Commas(n), C.heal, { crit = crit })
            end
        end
        if C_Timer and C_Timer.After then C_Timer.After(0.25, show) else show() end
    elseif action == "ENERGIZE" then
        if self:LogCovers("power") or not db.inPower then return end
        local power = PowerName()
        power = power and (" " .. power) or ""
        if secret then
            -- The amount goes last, so the game can fill it in
            self:Emit("incoming", "+", C.power, { secret = amount, after = power })
        elseif n and n > 0 then
            self:Emit("incoming", "+" .. Commas(n) .. power, C.power)
        end
    elseif MISS_TEXT[action] then
        if self:LogCovers("miss") or not db.inMisses then return end
        self:Emit("incoming", MissText(action), C.inAvoid)
    end
end

---------------------------------------------------------------------------
-- What you do to other units
--
-- The game hides the text of its combat log lines from addons when it likes:
-- the line arrives as a "|K...|k" token, which can be shown but not read. So
-- your hits are read from UNIT_COMBAT on the unit they land on (your target,
-- a mob with a nameplate, a party member): the amount, crit and school are
-- there, but not who did it, nor with which spell.
--
-- Everything that arrives in one frame (hidden lines, your casts, hits) is
-- kept in order in self.seq and worked out together once the frame is over
-- (ResolveFrame): what comes before and after a hit says what it was.
---------------------------------------------------------------------------
local CREDIT_TIME = 1.2   -- a hit can follow its combat log line by this long (a swing lands with its animation)
local TICK_SLACK = 0.25   -- a tick can be this far off its beat
local DOT_TIME = 45       -- a damage-over-time spell is forgotten this long after its cast
local FLAG_NOTES = { GLANCING = "glancing", BLOCK = "blocked", BLOCK_REDUCED = "blocked", ABSORB = "absorbed",
    RESIST = "resisted" }

-- Spells that keep hurting after the cast: { first rank's ID, English name,
-- seconds between ticks, school, whether the cast itself also hits }. The ID
-- gives the name in the game's language; every rank shares the name.
local PERIODIC_SPELLS = {
    { 1822, "Rake", 3, 1, true }, { 1079, "Rip", 2, 1 }, { 9005, "Pounce", 3, 1 },
    { 8921, "Moonfire", 3, 64, true }, { 5570, "Insect Swarm", 2, 8 }, { 339, "Entangling Roots", 3, 8 },
    { 772, "Rend", 3, 1 }, { 703, "Garrote", 3, 1 }, { 1943, "Rupture", 2, 1 },
    { 1978, "Serpent Sting", 3, 8 },
    { 172, "Corruption", 3, 32 }, { 348, "Immolate", 3, 4, true }, { 980, "Curse of Agony", 2, 32 },
    { 18265, "Siphon Life", 3, 32 },
    { 589, "Shadow Word: Pain", 3, 32 }, { 2944, "Devouring Plague", 3, 32 }, { 14914, "Holy Fire", 2, 2, true },
    { 8050, "Flame Shock", 3, 4, true },
}
-- Buffs on you that hurt whoever hits you: { first rank's ID, English name, school }
local SHIELD_SPELLS = {
    { 467, "Thorns", 8 }, { 324, "Lightning Shield", 8 }, { 7294, "Retribution Aura", 2 }, { 2947, "Fire Shield", 4 },
}

-- A paladin's seals: { first rank's ID, English name, school of the damage it adds
-- to your swings (none for the seals that don't hurt) }. Judgement uses up the seal.
local SEAL_SPELLS = {
    { 21084, "Seal of Righteousness", 2 }, { 20375, "Seal of Command", 2 },
    { 21082, "Seal of the Crusader" }, { 20164, "Seal of Justice" }, { 20165, "Seal of Light" },
    { 20166, "Seal of Wisdom" },
}
local JUDGEMENT = { 20271, "Judgement" }
local SEAL_TIME = 30   -- how long a seal lasts, in seconds

local function SpellName(id)
    if not (C_Spell and C_Spell.GetSpellName) then return nil end
    local ok, name = pcall(C_Spell.GetSpellName, id)
    return ok and Str(name) or nil
end

-- The two lists above by spell name, in English and in the game's language.
-- On an English client the ID's name must agree with the list (if this game
-- has given the ID to another spell, it's left out).
function BT:SpellLists()
    if self.periodic then return self.periodic, self.shields end
    local english = not GetLocale or GetLocale() == "enUS" or GetLocale() == "enGB"
    local function names(entry)
        local out = { entry[2] }
        local name = SpellName(entry[1])
        if name and name ~= entry[2] and not english then out[2] = name end
        return out
    end
    self.periodic, self.shields = {}, {}
    for _, e in ipairs(PERIODIC_SPELLS) do
        for _, name in ipairs(names(e)) do self.periodic[name] = { period = e[3], school = e[4], direct = e[5] or false } end
    end
    for _, e in ipairs(SHIELD_SPELLS) do
        for _, name in ipairs(names(e)) do self.shields[name] = { school = e[3], id = e[1] } end
    end
    return self.periodic, self.shields
end

-- The seals by name (English, and the game's language), and Judgement's names
function BT:SealLists()
    if self.seals then return self.seals, self.judgement end
    local english = not GetLocale or GetLocale() == "enUS" or GetLocale() == "enGB"
    local function names(id, name)
        local out = { name }
        local own = SpellName(id)
        if own and own ~= name and not english then out[2] = own end
        return out
    end
    self.seals, self.judgement = {}, {}
    for _, e in ipairs(SEAL_SPELLS) do
        for _, name in ipairs(names(e[1], e[2])) do self.seals[name] = { id = e[1], name = e[2], school = e[3] } end
    end
    for _, name in ipairs(names(JUDGEMENT[1], JUDGEMENT[2])) do self.judgement[name] = true end
    return self.seals, self.judgement
end

-- The seal you have on (self.seal), and a line when one goes on or comes off.
-- Buffs can be read out of a fight only; in a fight a seal coming off is worked
-- out: Judgement uses it up, a new seal replaces it, or its time runs out.
function BT:SealNotice(seal, on)
    if not self.db.nSeals then return end
    local icon = self.db.nIcons and self:IconText(seal.id) or ""
    self:Notify(icon .. (on and "+" or "-") .. seal.name, self.TEXT_COLORS.seal)
end

function BT:SetSeal(seal, quiet)
    local old = self.seal
    if old and old.name == seal.name then
        old.ends = GetTime() + SEAL_TIME   -- put on again: it lasts from now
    else
        if old and not quiet then self:SealNotice(old, false) end
        self.seal = { id = seal.id, name = seal.name, school = seal.school, ends = GetTime() + SEAL_TIME }
        if not quiet then self:SealNotice(self.seal, true) end
    end
    local mine = self.seal
    if C_Timer and C_Timer.After then
        C_Timer.After(SEAL_TIME + 0.1, function()
            if BT.seal == mine and GetTime() >= mine.ends then BT:LoseSeal() end
        end)
    end
end

function BT:LoseSeal(quiet)
    local old = self.seal
    if not old then return end
    self.seal = nil
    if not quiet then self:SealNotice(old, false) end
end

-- What a reading of your buffs found (out of a fight): the seal on you, or none
function BT:SeenSeal(found)
    local first = not self.sealRead
    self.sealRead = true
    if found then
        if not self.seal or self.seal.name ~= found.name then self:SetSeal(found, first) end
    elseif self.seal then
        self:LoseSeal(first)
    end
end

-- Buffs gained and lost. Your buffs can only be read out of a fight, so what
-- changed during one shows when it ends. Left out: seals (they have their own
-- lines), buffs with no time limit (mounts, auras, stances, tracking) and food
-- and drink. Dying drops your buffs: that's not reported.
local QUIET_BUFFS = { Food = true, Drink = true, ["Food & Drink"] = true, Refreshment = true }
function BT:SeenBuffs(now)
    local before = self.buffsSeen
    self.buffsSeen = now
    if not before or not self.db.nBuffs then return end
    if Flag(UnitIsDeadOrGhost, "player") then return end
    local function worth(b) return not QUIET_BUFFS[b.name] and b.duration ~= nil and b.duration > 0 end
    local function line(b, on)
        local icon = ""
        if self.db.nIcons and b.icon then icon = "|T" .. b.icon .. ":0|t " end
        self:Notify(icon .. (on and "+" or "-") .. b.name, self.TEXT_COLORS.buff)
    end
    for name, b in pairs(before) do
        if not now[name] and worth(b) then line(b, false) end
    end
    for name, b in pairs(now) do
        if not before[name] and worth(b) then line(b, true) end
    end
end

-- A Holy hit that lands with your swing on the same unit, while a seal that adds
-- damage is on you, is the seal's
function BT:SealFor(h, seq, first, last, at)
    local seal = self.seal
    if not self.db.outSeals then return nil end
    if not seal or not seal.school or h.kind ~= "damage" or GetTime() > seal.ends + 1 then return nil end
    if Num(h.school) ~= seal.school then return nil end
    for j = first, last do
        local o = seq[j]
        if j ~= at and o.hit and o.kind == "damage" and Num(o.school) == 1
            and ((h.key and o.key == h.key) or (not h.key and o.unit == h.unit)) then
            return { id = seal.id, name = seal.name }
        end
    end
    return nil
end

function BT:InGroup()
    return Flag(IsInGroup) or Flag(IsInRaid) or Flag(UnitExists, "party1")
end

-- A unit you're fighting: your target, or one that's after you or your pet
local function Fighting(unit)
    return Flag(UnitIsUnit, unit, "target") or Flag(UnitIsUnit, unit .. "target", "player")
        or Flag(UnitIsUnit, unit, "pettarget") or Flag(UnitIsUnit, unit .. "target", "pet")
end

-- What to know a unit by from one moment to the next: its GUID, or "target"
-- when the game won't give one
local function UnitKey(unit)
    local ok, guid = pcall(UnitGUID, unit)
    guid = ok and Str(guid) or nil
    if guid then return guid end
    if unit == "target" or Flag(UnitIsUnit, unit, "target") then return "target" end
    return nil
end

-- One hit arrives once for every name its unit goes by (target, nameplate3,
-- focus...). Only the first name seen in a frame counts for that unit.
function BT:FirstSight(unit, now)
    local seen = self.seenUnits
    if not seen then
        seen = {}
        self.seenUnits = seen
    end
    if self.seenAt ~= now then
        self.seenAt = now
        for k in pairs(seen) do seen[k] = nil end
    end
    local ok, guid = pcall(UnitGUID, unit)
    local key = ok and Str(guid) or nil
    if not key then
        -- No GUID to go by: your target counts under "target" only
        if unit ~= "target" and Flag(UnitIsUnit, unit, "target") then return false end
        key = unit
    end
    if seen[key] == nil then seen[key] = unit end
    return seen[key] == unit
end

-- Adds to this frame's events, and sees that they're worked out when it's over
function BT:Queue(event)
    local seq = self.seq or {}
    self.seq = seq
    event.time = GetTime()
    seq[#seq + 1] = event
    if C_Timer and C_Timer.After then
        self:FlushSoon()
    elseif event.hit or event.nothing then
        self:FlushHits(true)   -- no timers: each hit on its own
    end
end

function BT:FlushSoon()
    if self.flushing then return end
    self.flushing = true
    C_Timer.After(0, function()
        BT.flushing = false
        BT:FlushHits()
    end)
end

-- Works out every frame that's over (all = this one too)
function BT:FlushHits(all)
    local seq = self.seq
    if not seq or #seq == 0 then return end
    local now, first = GetTime(), 1
    while seq[first] and (all or seq[first].time ~= now) do
        local last = first
        while seq[last + 1] and seq[last + 1].time == seq[first].time do last = last + 1 end
        self:ResolveFrame(seq, first, last)
        first = last + 1
    end
    local left = {}
    for i = first, #seq do left[#left + 1] = seq[i] end
    self.seq = left
    if #left > 0 then self:FlushSoon() end
end

-- In a group, a hit on a mob could be anyone's. The combat log lines can't be
-- read, but with the "My actions" filter each one is something you did. So a
-- hit is taken for yours only if a line came with it or shortly before it,
-- and each line vouches for one hit. (credits: when those lines arrived.)
function BT:NoteHiddenLine(now)
    self.hiddenSeen, self.hiddenAt = true, now
    local credits = self.credits or {}
    self.credits = credits
    while credits[1] and (now - credits[1] > CREDIT_TIME or #credits >= 20) do table.remove(credits, 1) end
    credits[#credits + 1] = now
    self:Queue({ line = true })
end

function BT:ClaimHit(now)
    local credits = self.credits
    while credits and credits[1] and now - credits[1] > CREDIT_TIME do table.remove(credits, 1) end
    if credits and credits[1] and credits[1] <= now then
        table.remove(credits, 1)
        return true
    end
    return false
end

-- Your own casts. A hit in the very frame a cast finishes is that spell (an
-- instant attack, a spell with no travel time). A cast of a damage-over-time
-- spell is remembered against your target, to name its ticks later.
function BT:OnSpellcast(spellId)
    local id = Num(spellId)
    local name = id and SpellName(id) or nil
    if self.db.debug then self:Record("CAST " .. tostring(id) .. " " .. tostring(name)) end
    self:Queue({ cast = true, id = id, name = name })
    if not name then return end
    local periodic, shields = self:SpellLists()
    local dot = periodic[name]
    local key = dot and UnitKey("target")
    if key then
        self.dots = self.dots or {}
        self.dots[key] = self.dots[key] or {}
        self.dots[key][name] = { id = id, name = name, at = GetTime(), period = dot.period, school = dot.school }
    end
    if shields[name] then
        self.buffShields = self.buffShields or {}
        self.buffShields[name] = { name = name, id = id, school = shields[name].school }
    end
    local seals, judgement = self:SealLists()
    if seals[name] then
        self:SetSeal({ id = id, name = seals[name].name, school = seals[name].school })
    elseif judgement[name] then
        self:LoseSeal()
    end
end

-- Damage shields: what hurts whoever strikes you. There can be several at
-- once (Thorns from a druid, and a cloak that stings back).
--
-- The buffs among them (self.buffShields, by name). Buffs can only be read
-- some of the time (not in a fight), so the last answer stands until there's
-- a new one.
function BT:ScanShield()
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
    local _, shields = self:SpellLists()
    local seals = self:SealLists()
    local found, seal, buffs = {}, nil, {}
    for i = 1, 40 do
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or IsSecret(a) then return end
        if a == nil then break end
        if type(a) ~= "table" or IsSecret(a.name) then return end
        local name = Str(a.name)
        if name and shields[name] then
            found[name] = { name = name, id = Num(a.spellId) or shields[name].id, school = shields[name].school }
        end
        if name and seals[name] then
            seal = { id = Num(a.spellId) or seals[name].id, name = seals[name].name, school = seals[name].school }
        elseif name then
            local icon = a.icon
            buffs[name] = { name = name, icon = Num(icon) or Str(icon), duration = Num(a.duration) }
        end
    end
    self.buffShields = found
    self:SeenSeal(seal)
    self:SeenBuffs(buffs)
end

-- The ones on your gear (self.itemShields): an item says so in its tooltip,
-- with the amount and school ("When struck in combat, inflicts 1 Nature damage
-- to the attacker."). Read in English only; on other languages an item's
-- shield goes unrecognised.
local SCHOOL_WORDS = { physical = 1, holy = 2, fire = 4, nature = 8, frost = 16, shadow = 32, arcane = 64 }
function BT:ScanItemShields()
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return end
    if InCombatLockdown() then return end
    local found = {}
    for slot = 1, 19 do
        local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
        local rows = ok and not IsSecret(data) and type(data) == "table" and data.lines
        if type(rows) == "table" then
            local name
            for _, row in ipairs(rows) do
                local text = type(row) == "table" and Str(row.leftText) or nil
                if not text and type(row) == "table" and type(row.args) == "table" then
                    -- (an older shape of the same data: the text is among the line's "args")
                    for _, arg in ipairs(row.args) do
                        if type(arg) == "table" and arg.field == "leftText" then text = Str(arg.stringVal) end
                    end
                end
                if text then
                    name = name or text   -- the first line is the item's name
                    local amount, school = text:match("[Ii]nflicts (%d+) (%a+) damage to the attacker")
                    school = school and SCHOOL_WORDS[school:lower()]
                    if school then
                        local okIcon, icon = pcall(GetInventoryItemTexture, "player", slot)
                        found[#found + 1] = { name = name, amount = tonumber(amount), school = school,
                            icon = okIcon and (Num(icon) or Str(icon)) or nil }
                    end
                end
            end
        end
    end
    self.itemShields = found
end

-- Whose answer to a blow this hit is, if it's a damage shield's. An item's is
-- known by its amount. A buff's amount has to be learned: a hit of the buff's
-- school that nothing else explains waits here for the proof.
function BT:KnownShield(h)
    local mask = Num(h.school)
    if h.kind ~= "damage" or not h.n or not mask then return nil end
    for _, item in ipairs(self.itemShields or {}) do
        if item.school == mask and item.amount == h.n then return item end
    end
    for name, shield in pairs(self.buffShields or {}) do
        if shield.school == mask and self.db.shieldAmounts[name] == h.n then return shield end
    end
    return nil
end

function BT:ShieldFor(h, lineInFrame)
    local known = self:KnownShield(h)
    if known then return known end
    local mask = Num(h.school)
    if h.kind ~= "damage" or not h.n or not mask then return nil end
    local waiting = false
    for _, shield in pairs(self.buffShields or {}) do
        if shield.school == mask then waiting = true end
    end
    if waiting then
        local pending = self.shieldPending or {}
        self.shieldPending = pending
        -- While the combat log lines arrive, a frame with a line in it proves nothing
        -- (a shield's answer has no line; a spell of yours landing has)
        pending[#pending + 1] = { time = h.time, amount = h.n, school = mask, clean = not lineInFrame }
        if #pending > 10 then table.remove(pending, 1) end
    end
    return nil
end

-- A shield answers a blow, and the blow on you shows up within a second of the
-- answer. An amount that has answered two blows is a shield's; three, to
-- replace an amount learned before.
function BT:ConfirmShield(now)
    local pending = self.shieldPending
    if not pending or not pending[1] then return end
    local answers = {}
    while pending[1] do
        local p = table.remove(pending, 1)
        if p.clean and now - p.time <= CREDIT_TIME then answers[p.school .. ":" .. p.amount] = p end
    end
    local counts = self.shieldCounts or {}
    self.shieldCounts = counts
    for key, p in pairs(answers) do
        counts[key] = (counts[key] or 0) + 1
        if counts[key] >= 2 then self:LearnShield(p, counts[key], answers) end
    end
end

-- Does the buff's own description name this amount? ("...causing 11 Nature damage to attackers...")
local function Describes(shield, amount)
    if not (shield.id and C_Spell and C_Spell.GetSpellDescription) then return false end
    local ok, text = pcall(C_Spell.GetSpellDescription, shield.id)
    text = ok and Str(text) or nil
    return text ~= nil and text:find("%f[%d]" .. amount .. "%f[%D]") ~= nil
end

-- Which of the buffs you're wearing hits for this amount: the one whose
-- description says so, or the only one it could be
function BT:LearnShield(p, count, answers)
    local amounts = self.db.shieldAmounts
    local could, described, describedCount = {}, nil, 0
    for _, shield in pairs(self.buffShields or {}) do
        if shield.school == p.school then
            could[#could + 1] = shield
            if Describes(shield, p.amount) then described, describedCount = shield, describedCount + 1 end
        end
    end
    local owner
    if describedCount == 1 then
        owner = described
    elseif #could == 1 then
        -- Only if this is the one amount of its school that needs an owner
        local others = 0
        for _, other in pairs(answers) do
            if other.school == p.school and other.amount ~= p.amount then others = others + 1 end
        end
        if others == 0 then owner = could[1] end
    end
    if owner and (amounts[owner.name] == nil or count >= 3 or describedCount == 1) then
        amounts[owner.name] = p.amount
    end
end

-- The damage-over-time spell of yours whose tick this hit is: one you cast on
-- that unit, on its beat now (so many periods after the cast), of the hit's school
function BT:TickFor(h)
    local dots = h.key and self.dots and self.dots[h.key]
    if not dots or h.kind ~= "damage" then return nil end
    local mask = Num(h.school)
    local best, bestOff
    for name, dot in pairs(dots) do
        local since = h.time - dot.at
        if since > DOT_TIME then
            dots[name] = nil
        else
            local beats = math.floor(since / dot.period + 0.5)
            local off = math.abs(since - beats * dot.period)
            if beats >= 1 and off <= TICK_SLACK and (not mask or mask == dot.school) and (not best or off < bestOff) then
                best, bestOff = dot, off
            end
        end
    end
    return best
end

-- One frame's events, in the order they came: seq[first..last]
function BT:ResolveFrame(seq, first, last)
    local periodic = self:SpellLists()
    local cast, castAt, casts = nil, nil, 0
    for i = first, last do
        if seq[i].cast then cast, castAt, casts = seq[i], i, casts + 1 end
    end
    if casts ~= 1 or not cast.id then cast = nil end   -- two casts in a frame: no telling which did what
    local castSchool   -- the school of the hits this frame's cast has been given
    -- While the lines are arriving, a tick is known by its line: it comes right behind the hit
    local linesFlow = self.hiddenAt ~= nil and seq[first].time - self.hiddenAt < 10
    local lineInFrame, blowInFrame = false, false
    for i = first, last do
        if seq[i].line then lineInFrame = true end
        if seq[i].blow then blowInFrame = true end
    end
    -- Which hits are the cast's. While the lines are arriving, the cast's hit is the one with a
    -- line of its own just ahead of it in the frame, wherever the cast itself falls: Claw's and
    -- Rake's hits come after the cast, Shred's comes before it. A damage shield's answer has
    -- no line, and a tick's line comes behind the tick. If no hit has a line, it goes by order.
    local byLine
    if cast and linesFlow then
        local info = periodic[cast.name or ""]
        local taken, school = {}, nil
        for i = first, last do
            local h = seq[i]
            if h.hit then
                local mask = Num(h.school)
                local can = true
                if h.kind == "damage" then
                    local expect = school or (self.spellSchool and self.spellSchool[cast.id])
                    can = not (info and not info.direct) and not (expect and mask and expect ~= mask)
                        and not (expect ~= mask and self:KnownShield(h))
                end
                local mine = false
                if can then
                    for j = i - 1, first, -1 do
                        if seq[j].line and not taken[j] then
                            taken[j], seq[j].used, mine = true, true, true
                            break
                        end
                    end
                end
                if mine then
                    byLine = byLine or {}
                    byLine[i] = true
                    if h.kind == "damage" then school = school or mask end
                elseif self:TickFor(h) then
                    for j = i + 1, last do   -- the tick's own line, which the loop below gives it
                        if seq[j].line and not taken[j] then taken[j] = true break end
                    end
                end
            end
        end
    end
    for i = first, last do
        local h = seq[i]
        if h.nothing and not blowInFrame then
            self:Emit("incoming", MissText("MISS"), self.TEXT_COLORS.inAvoid)   -- a hit on you for nothing
        end
        if h.hit then
            local mask = Num(h.school)
            local what, spell = "hit", nil
            -- Without a line to go by, the cast's hit comes after the cast (a hit ahead of it in
            -- the frame is something else)
            if cast and ((byLine and byLine[i]) or (not byLine and i > castAt)) then
                local info = periodic[cast.name or ""]
                if h.kind ~= "damage" then
                    spell = cast
                    -- The cast missed: nothing was put on the unit to tick
                    if h.kind == "miss" and info and h.key and self.dots and self.dots[h.key] then
                        self.dots[h.key][cast.name] = nil
                    end
                elseif not (info and not info.direct) then
                    local expect = castSchool or (self.spellSchool and self.spellSchool[cast.id])
                    -- Not a hit of another school than the spell's; and a hit that's just what a
                    -- damage shield of yours does is the shield's, unless the spell is of that school too
                    if not (expect and mask and expect ~= mask) and not (expect ~= mask and self:KnownShield(h)) then
                        spell, castSchool = cast, castSchool or mask
                    end
                end
                if spell then what = "cast" end
            end
            if not spell then
                local dot = self:TickFor(h)
                if dot then
                    local vouched
                    if linesFlow then
                        for j = i + 1, last do
                            if seq[j].line and not seq[j].used then
                                seq[j].used, vouched = true, true
                                break
                            end
                        end
                    else
                        vouched = mask ~= nil and mask ~= 1   -- without the lines, a bleed's tick looks just like a swing
                    end
                    if vouched then what, spell = "tick", dot end
                end
            end
            if not spell then
                local shield = self:ShieldFor(h, lineInFrame)
                if shield then what, spell = "shield", shield end
            end
            if not spell then
                local seal = self:SealFor(h, seq, first, last, i)
                if seal then what, spell = "seal", seal end
            end
            local why
            if h.grouped and not self:ClaimHit(h.time) then
                why = "no line of yours with it"
            else
                why = self:ShowUnitHit(h, what, spell)
            end
            if self.db.debug then
                self:Record(("  %s %s: %s"):format(h.unit, h.secret and "(hidden amount)" or tostring(h.amount),
                    why or (spell and (what .. " of " .. tostring(spell.name)) or "shown")), h.time)
            end
        end
    end
    -- What this frame's cast turned out to be: the school, if every hit it was given agrees
    if cast and castSchool then
        self.spellSchool = self.spellSchool or {}
        self.spellSchool[cast.id] = self.spellSchool[cast.id] or castSchool
    end
end

-- Puts a hit on screen. what: "cast", "tick", "shield", "seal" or "hit"; spell: { id, name } when it's known.
-- Returns why not, if a setting hides it.
function BT:ShowUnitHit(h, what, spell)
    local db, C = self.db, self.TEXT_COLORS
    local icon = ""
    if spell and spell.id then
        icon = self:IconText(spell.id)
    elseif spell and spell.icon then
        icon = "|T" .. spell.icon .. ":0|t "   -- an item's
    end
    local spellName = spell and spell.name
    local name
    icon, name = self:SpellParts(h.kind == "heal" and "heal" or "out", icon, spellName)
    local label = icon .. (name and (name .. " ") or "")
    if h.kind == "damage" then
        if what == "shield" and not db.outShields then return "damage shields are turned off" end
        if not db.outDamage then return "damage is turned off" end
        if h.n and h.n < db.minDamage then return "below \"Hide hits below\"" end
        local mask = Num(h.school)
        local color = MASK_COLORS[mask or 1] or ((spellName or (mask and mask ~= 1)) and C.spell) or C.melee
        local note = FLAG_NOTES[h.flag or ""]
        note = note and (" |cffb0b0b0(" .. note .. ")|r") or ""
        if h.secret then
            self:Emit("outgoing", label, color, { crit = h.crit, secret = h.amount, after = note })
        else
            self:Emit("outgoing", label .. Commas(h.n) .. note, color, {
                crit = h.crit,
                key = spell and (what .. ":" .. tostring(spell.id or spellName)) or nil,
                amount = h.n,
                format = function(total, count)
                    return label .. Commas(total) .. " |cffb0b0b0(x" .. count .. ")|r"
                end,
            })
        end
    elseif h.kind == "heal" then
        if not db.outHeals then return "heals are turned off" end
        local who = self:HealedName(h.unit)
        if h.secret then
            self:Emit(self:HealArea("outgoing"), label .. "+", C.heal, { crit = h.crit, secret = h.amount, after = who })
        else
            if not self:HealShown(h.n) then return "below \"Hide heals below\"" end
            self:Emit(self:HealArea("outgoing"), label .. "+" .. Commas(h.n) .. who, C.heal, { crit = h.crit })
        end
    else
        if not db.outMisses then return "misses are turned off" end
        -- A wound for nothing says how in its flag; a plain miss has none
        local how = h.action
        if how == "WOUND" then how = (h.flag and MISS_TEXT[h.flag]) and h.flag or "MISS" end
        self:Emit("outgoing", label .. MissText(how), C.miss)
    end
    return nil
end

-- UNIT_COMBAT for a unit that isn't you
function BT:OnUnitHit(unit, action, flag, amount, school)
    -- You go by other names too (a mob's target, a raid member): "player" has
    -- its own event. Of what happens to your pet, only its heals are shown.
    if Flag(UnitIsUnit, unit, "player") then return end
    action, flag = Str(action), Str(flag)
    local myPet = Flag(UnitIsUnit, unit, "pet")
    if myPet and (unit ~= "pet" or action ~= "HEAL") then return end
    local secret, n, now = IsSecret(amount), Num(amount), GetTime()
    local some = secret or (n ~= nil and n > 0)
    local kind
    if action == "WOUND" then
        kind = some and "damage" or "miss"
    elseif action == "HEAL" then
        kind = some and "heal" or nil
    elseif action and MISS_TEXT[action] then
        kind = "miss"
    end
    local healing = kind == "heal"
    local enemy = Flag(UnitCanAttack, "player", unit)
    -- In a group, once the combat log lines are arriving, they say which hits are yours
    local grouped = self.hiddenSeen and self:InGroup()

    local why
    if not kind then
        why = "not a hit"
    elseif self.readAt and now - self.readAt < CREDIT_TIME then
        why = "the combat log line has it"
    elseif healing and enemy then
        why = "a heal on an enemy"
    elseif not healing and not enemy then
        why = "not an enemy"
    elseif healing and not grouped and not myPet and not Flag(UnitIsUnit, unit, "target") then
        why = "not your target"
    elseif not healing and not Fighting(unit) then
        why = "not your fight"
    elseif not self:FirstSight(unit, now) then
        why = "same hit, under another name"
    end
    if self.db.debug then
        self:Record(("UNIT_COMBAT %s %s %s %s school %s%s"):format(unit, tostring(action), tostring(flag),
            secret and "(hidden amount)" or tostring(amount), IsSecret(school) and "(hidden)" or tostring(school),
            why and (": " .. why) or ""))
    end
    if why then return end
    self:Queue({ hit = true, unit = unit, key = UnitKey(unit), kind = kind, action = action, flag = flag,
        amount = amount, secret = secret, n = n, school = school, crit = flag == "CRITICAL", grouped = grouped })
end

-- A finished combat log line from the game
function BT:OnCombatLogMessage(message, _, _, _, order)
    -- Old lines replayed when the Combat Log window refills aren't news
    local oldest = Enum and Enum.CombatLogMessageOrder and Enum.CombatLogMessageOrder.Oldest
    if oldest ~= nil and not IsSecret(order) and order == oldest then return end
    if not self.started then
        self.started = true   -- the lines are flowing
        self:UpdateStartButton()
    end
    if not self.db.enabled then return end
    -- The game is hiding the text: the line can't be read, but it says you did
    -- something just now (see NoteHiddenLine)
    local hidden = IsSecret(message)
    if not hidden and (type(message) ~= "string" or message:find("|K", 1, true)) then hidden = true end
    if hidden then
        if self.db.debug then self:Record("hidden  " .. (Str(message) or "(a hidden value)")) end
        self:NoteHiddenLine(GetTime())
        return
    end
    local info = Parser:Parse(message)
    -- A line of yours that can be read is shown from the line; the same hit from
    -- UNIT_COMBAT is then left out
    if info and (info.fromMe or self:IsPetLine(info)) then self.readAt = GetTime() end
    local shown = info ~= nil and self:ShowCombat(info)
    if self.db.debug then self:Record((shown and "read    " or "skipped ") .. message) end
end

-- Debug (/btf debug, then /btf copy): what the game sent, exactly, with the time
-- it arrived. Kept only while debug is on, and only the last 300.
function BT:Record(text, time)
    self.recorded = self.recorded or {}
    local list = self.recorded
    list[#list + 1] = ("%7.2f  %s"):format((time or GetTime()) % 1000, text)
    if #list > 300 then table.remove(list, 1) end
end

---------------------------------------------------------------------------
-- Notifications
---------------------------------------------------------------------------
function BT:Notify(text, color, opts)
    self:Emit("notify", text, color or self.TEXT_COLORS.notify, opts)
end

function BT:OnXP()
    local xp, max = Num(UnitXP("player")), Num(UnitXPMax("player"))
    if not xp or not max then return end
    local last, lastMax = self.lastXP, self.lastXPMax
    self.lastXP, self.lastXPMax = xp, max
    if not last or not self.db.nXP then return end
    local gained = xp - last
    if gained < 0 and lastMax then gained = (lastMax - last) + xp end   -- levelled up
    if gained > 0 then self:Notify("+" .. Commas(gained) .. " XP", self.TEXT_COLORS.xp) end
end

-- A game sentence like "You receive loot: %sx%d." as a pattern that matches it
local function SentencePattern(fmt)
    local p = fmt:gsub("%%%d*%$?s", "\1"):gsub("%%%d*%$?d", "\2")
    p = p:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    p = p:gsub("\1", "(.+)"):gsub("\2", "(%%d+)")
    return "^" .. p
end

-- "You receive loot: [Linen Cloth]x2." -> "+2 [Linen Cloth]"
local LOOT_KEYS = { "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF",
    "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF" }
local LOOT_FALLBACK = { LOOT_ITEM_SELF = "You receive loot: %s", LOOT_ITEM_PUSHED_SELF = "You receive item: %s",
    LOOT_ITEM_CREATED_SELF = "You create: %s" }
function BT:OnLoot(message)
    message = Str(message)
    if not message or not self.db.nLoot then return end
    -- Only your own loot: the line is one of the game's sentences for it
    if not self.lootPatterns then
        self.lootPatterns = {}
        for _, key in ipairs(LOOT_KEYS) do
            local fmt = Str(_G[key]) or LOOT_FALLBACK[key]
            if fmt then self.lootPatterns[#self.lootPatterns + 1] = SentencePattern(fmt) end
        end
    end
    local mine = false
    for _, pattern in ipairs(self.lootPatterns) do
        if message:find(pattern) then mine = true break end
    end
    if not mine then return end
    local link = message:match("(|c[^|]*|Hitem:.-|h.-|h|r)") or message:match("(|Hitem:.-|h.-|h)")
    if not link then return end
    local count = tonumber(message:match("|h|r?x(%d+)")) or 1
    local icon = ""
    local id = tonumber(link:match("|Hitem:(%d+)"))
    if id and self.db.nIcons and C_Item and C_Item.GetItemIconByID then
        local ok, tex = pcall(C_Item.GetItemIconByID, id)
        if ok and not IsSecret(tex) and tex then icon = "|T" .. tex .. ":0|t " end
    end
    self:Notify(icon .. "+" .. count .. " " .. link, self.TEXT_COLORS.loot)
end

-- Professions whose spell has another name than the skill (the rest are found by name)
local SKILL_SPELLS = { Herbalism = 2366, Mining = 2575, Fishing = 7620 }

-- A skill-up's icon: the skill's spell, when the game has one ("Your skill in Cooking has increased to 5")
function BT:SkillIcon(message)
    if not self.db.nIcons then return "" end
    local pattern = Str(SKILL_RANK_UP) or "Your skill in %s has increased to %d."
    pattern = pattern:gsub("([%.%(%)%-%+%*%?%[%]%^%$])", "%%%1"):gsub("%%s", "(.-)"):gsub("%%d", "%%d+")
    local skill = message:match(pattern)
    if not skill then return "" end
    return self:IconText(SKILL_SPELLS[skill] or skill)
end

-- /btf check: asks the game about every spell, skill, text and icon BattleText
-- relies on, on any character (the game knows every spell, not only your class's).
-- Prints what's missing or named differently, and keeps the report for /btf copy.
function BT:CheckGameData()
    local report, problems = {}, 0
    local function line(ok, text)
        if not ok then problems = problems + 1 end
        report[#report + 1] = (ok and "ok      " or "PROBLEM ") .. text
    end
    local english = (GetLocale and (GetLocale() == "enUS" or GetLocale() == "enGB")) or false
    local function spell(id, expected, what)
        local ok, name = pcall(C_Spell.GetSpellName, id)
        name = ok and Str(name) or nil
        if not name then
            line(false, ("%s %d (%s): not in this game"):format(what, id, expected))
        elseif english and name ~= expected then
            line(false, ("%s %d: the game calls it %s, BattleText expects %s"):format(what, id, name, expected))
        else
            line(true, ("%s %d: %s"):format(what, id, name))
        end
    end
    for _, e in ipairs(PERIODIC_SPELLS) do spell(e[1], e[2], "tick") end
    for _, e in ipairs(SHIELD_SPELLS) do spell(e[1], e[2], "shield") end
    for _, e in ipairs(SEAL_SPELLS) do spell(e[1], e[2], "seal") end
    spell(JUDGEMENT[1], JUDGEMENT[2], "seal")
    local skillNames = { [2366] = "Herb Gathering", [2575] = "Mining", [7620] = "Fishing" }
    for skill, id in pairs(SKILL_SPELLS) do spell(id, skillNames[id] or skill, "skill " .. skill) end
    line(Str(SKILL_RANK_UP) ~= nil, "text SKILL_RANK_UP: " .. tostring(Str(SKILL_RANK_UP)))
    local getFile = GetFileIDFromPath
    if getFile then
        local icons = { T.LOGO }
        for _, t in ipairs(self.CONFIG_TABS or {}) do icons[#icons + 1] = t.icon end
        for _, path in ipairs(icons) do
            local ok, id = pcall(getFile, path)
            line(ok and Num(id) ~= nil, "icon " .. path)
        end
    end
    self.recorded = {}
    for _, text in ipairs(report) do self:Record(text) end
    if problems == 0 then
        Print(("all %d checks passed."):format(#report))
    else
        Print(("%d of %d checks found a problem:"):format(problems, #report))
        for _, text in ipairs(report) do
            if text:find("^PROBLEM") then print("  " .. text:gsub("^PROBLEM ", "")) end
        end
        Print("type /btf copy to copy the full report.")
    end
    return problems, report
end

-- Chat lines shown as they are, minus the trailing period
function BT:OnChatNotice(setting, message, color)
    message = Str(message)
    if not message or not self.db[setting] then return end
    local icon = setting == "nSkill" and self:SkillIcon(message) or ""
    self:Notify(icon .. (message:gsub("%.%s*$", "")), color)
end

---------------------------------------------------------------------------
-- Getting the combat log lines flowing
--
-- The game only writes them once the Combat Log window has been shown (that's
-- when it loads its filter), and stops when that window hides. An addon can't
-- load the filter itself, but it can turn the lines back on afterwards. So:
-- one click on the Start button opens and closes the Combat Log tab, and from
-- then on BattleText keeps the lines coming.
---------------------------------------------------------------------------
-- The Combat Log window. COMBATLOG is set by Blizzard's Combat Log code once
-- it has loaded and put its own show/hide handlers on the window.
function BT:CombatLogFrame()
    return _G.COMBATLOG
end

function BT:KeepLogFlowing()
    if not self.db.enabled then return end
    if C_CombatLog and C_CombatLog.SetFilteredEventsEnabled then
        pcall(C_CombatLog.SetFilteredEventsEnabled, true)
    end
end

-- Turned off: leave the lines the way the game has them (on only while its
-- Combat Log window is showing)
function BT:StopLogFlowing()
    local log = self:CombatLogFrame()
    if log and log.IsShown and log:IsShown() then return end
    if C_CombatLog and C_CombatLog.SetFilteredEventsEnabled then
        pcall(C_CombatLog.SetFilteredEventsEnabled, false)
    end
end

function BT:BuildStartButton()
    -- A secure button can't be set up in combat (after a /reload mid-fight)
    if self.startButton then return end
    if InCombatLockdown() then
        self.startPending = true
        return
    end
    local b = CreateFrame("Button", "BattleTextForeverStart", UIParent, "SecureActionButtonTemplate")
    b:SetSize(170, 26)
    b:SetPoint("TOP", UIParent, "TOP", 0, -140)
    b:SetFrameStrata("HIGH")
    b:RegisterForClicks("AnyUp", "AnyDown")
    -- The shared header bar: logo, then the words in gold on red
    T.HeaderStrip(b, "Start BattleText")
    b:FitLogo(26)
    b.icon, b.label = b.logo, b.text
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Start BattleText", T.C.gold[1], T.C.gold[2], T.C.gold[3])
        GameTooltip:AddLine("The game only writes its combat lines after the Combat Log tab has been opened once. "
            .. "This click opens it and switches back for you.", 1, 1, 1, true)
        GameTooltip:AddLine("Playing alone, your hits show without it. In a group, BattleText needs those lines to tell "
            .. "your hits from everyone else's.", 1, 1, 1, true)
        GameTooltip:AddLine("Once each time you log in.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    -- Go back to whichever chat tab is selected right now
    b:SetScript("PreClick", function() BT:SetStartMacro() end)
    -- The click has opened and closed the tab; the game turned the lines off
    -- again when it closed, so turn them back on
    b:SetScript("PostClick", function() BT:KeepLogFlowing() end)
    b:Hide()
    self.startButton = b
    self:SetStartMacro()
end

-- The click: open the Combat Log tab, then go back to the tab you were on.
-- If you're already on the Combat Log tab, leave it and come back.
function BT:SetStartMacro()
    local b = self.startButton
    if not b or InCombatLockdown() then return end
    local selected
    if FCFDock_GetSelectedWindow and GENERAL_CHAT_DOCK then
        local ok, frame = pcall(FCFDock_GetSelectedWindow, GENERAL_CHAT_DOCK)
        if ok then selected = frame end
    end
    selected = selected or _G.SELECTED_DOCK_FRAME
    local macro
    if selected and selected == _G.ChatFrame2 then
        macro = "/click ChatFrame1Tab\n/click ChatFrame2Tab"
    else
        local back = "ChatFrame1Tab"
        if selected and selected.GetName then
            local name = Str(selected:GetName())
            if name and _G[name .. "Tab"] then back = name .. "Tab" end
        end
        macro = "/click ChatFrame2Tab\n/click " .. back
    end
    if b.macro == macro then return end
    b.macro = macro
    b:SetAttribute("type", "macro")
    b:SetAttribute("macrotext", macro)
end

-- Shown until the lines are flowing: until the Combat Log window has been
-- shown, or a line has arrived
function BT:UpdateStartButton()
    if not self.startButton then
        if self.built then self:BuildStartButton() end
        if not self.startButton then return end
    end
    local b = self.startButton
    local show = self.db.enabled and not self.started
    if show == b.wanted then return end
    if InCombatLockdown() then
        self.startPending = true   -- showing or hiding a secure button waits for combat to end
        return
    end
    b.wanted = show
    b:SetShown(show)
end

-- A line in chat a little after logging in (or a /reload), if Start hasn't been clicked by then
local REMIND_AFTER = 10
function BT:RemindStart()
    if not (self.db.enabled and self.db.startReminder) or self.started then return end
    local key = GetBindingKey and Str(GetBindingKey("CLICK BattleTextForeverStart:LeftButton"))
    Print("click |cffffd100Start BattleText|r at the top of your screen"
        .. (key and (" (or press " .. key .. ")") or "")
        .. ". It names your bleed ticks and, in a group, leaves other people's hits out.")
end

-- When the Combat Log window is shown the game loads its filter (so the lines
-- start); when it hides, the game turns them off, and we turn them back on
function BT:HookCombatLog()
    local log = self:CombatLogFrame()
    if not log or self.hooked then return end
    self.hooked = true
    log:HookScript("OnShow", function()
        BT.started = true
        BT:UpdateStartButton()
    end)
    log:HookScript("OnHide", function() BT:KeepLogFlowing() end)
end

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------
-- Your colors over the starting ones, in place (code reads BT.TEXT_COLORS when it shows a line)
function BT:ApplyColors()
    local mine = self.db and self.db.colors or {}
    for k, def in pairs(self.DEFAULT_COLORS) do
        local c = mine[k]
        if type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number" then
            self.TEXT_COLORS[k] = { c[1], c[2], c[3] }
        else
            self.TEXT_COLORS[k] = { def[1], def[2], def[3] }
        end
    end
end

function BT:SetColor(key, r, g, b)
    if r then self.db.colors[key] = { r, g, b } else self.db.colors[key] = nil end
    self:ApplyColors()
end

function BT:ApplySettings()
    self:ApplyColors()
    if not self.built then return end
    self:ApplyAreas()
    self:UpdateStartButton()
    self:UpdateMinimapButton()
    self:ApplyBlizzardText()
    if self.db.enabled then self:KeepLogFlowing() else self:StopLogFlowing() end
end

-- Settings for this character only, or the ones every character shares. Turning
-- it on starts this character from a copy of the shared ones.
local function Copy(t)
    local c = {}
    for k, v in pairs(t) do c[k] = type(v) == "table" and Copy(v) or v end
    return c
end

function BT:OwnSettings()
    return BattleTextForeverCharDB ~= nil and BattleTextForeverCharDB.own == true
end

function BT:SetOwnSettings(on)
    if on == self:OwnSettings() then return end
    self:ApplyBlizzardText(true)   -- put the game's numbers back while the settings change hands
    local char = BattleTextForeverCharDB
    if on then
        local mine = Copy(BattleTextForeverDB)
        mine.savedCVars = nil
        char.settings, char.own = mine, true
        self.db = mine
    else
        char.own = nil
        self.db = BattleTextForeverDB
    end
    self:ApplySettings()
    self:RefreshConfig()
end

-- Picking a font shows a line in it straight away
function BT:SetFont(name)
    self.db.font = name
    self.testing = true
    self:Emit("notify", name, self.TEXT_COLORS.notify)
    self.testing = false
end

-- Picking an outline shows a line with it straight away (a crit for the crits' one)
function BT:SetOutline(key, flags)
    self.db[key] = flags
    self.testing = true
    self:Emit("notify", key == "critOutline" and "Crit" or "Normal", self.TEXT_COLORS.notify,
        { crit = key == "critOutline" })
    self.testing = false
end

function BT:SetLocked(locked)
    self.db.locked = locked
    self:ApplyAreas()
end

-- The game's own floating numbers, so they aren't shown twice. What they were
-- set to is remembered, and put back when the option or BattleText is turned
-- off, and whenever you log out (so nothing is left changed if BattleText is
-- removed).
local BLIZZARD_CVARS = { "enableFloatingCombatText", "floatingCombatTextCombatDamage", "floatingCombatTextCombatHealing" }
function BT:ApplyBlizzardText(restore)
    if not (GetCVar and SetCVar) then return end
    if InCombatLockdown() and not restore then return end
    local db = self.db
    if db.enabled and db.hideBlizzard and not restore then
        db.savedCVars = db.savedCVars or {}
        for _, cvar in ipairs(BLIZZARD_CVARS) do
            local ok, value = pcall(GetCVar, cvar)
            value = ok and Str(value) or nil
            if value then
                if db.savedCVars[cvar] == nil then db.savedCVars[cvar] = value end
                if value ~= "0" then pcall(SetCVar, cvar, "0") end
            end
        end
    elseif db.savedCVars then
        for cvar, value in pairs(db.savedCVars) do pcall(SetCVar, cvar, value) end
        db.savedCVars = nil
    end
end

-- A few sample lines, to see the look and place the areas
function BT:Test()
    local C = self.TEXT_COLORS
    local samples = {
        function() self:ShowCombat({ kind = "damage", fromMe = true, melee = true, amount = 27, unit = "Physical" }) end,
        function() self:ShowCombat({ kind = "damage", fromMe = true, spell = "Claw", amount = 50, unit = "Physical" }) end,
        function() self:Emit("incoming", "-34", C.inDamage) end,
        function() self:ShowCombat({ kind = "damage", fromMe = true, spell = "Moonfire", amount = 112, unit = "Arcane", crit = true }) end,
        function() self:Emit(self:HealArea("incoming"), "+120 Rejuvenation", C.heal) end,
        function() self:ShowCombat({ kind = "heal", fromMe = true, spell = "Healing Touch", amount = 214 }) end,
        function() self:ShowCombat({ kind = "miss", fromMe = true, melee = true, missType = "DODGE" }) end,
        function() self:Emit("incoming", "-58", C.inDamage, { crit = true }) end,
        function() self:Notify("+103 XP", C.xp) end,
        function() self:ShowCombat({ kind = "damage", fromMe = true, melee = true, amount = 26, unit = "Physical", blocked = 3 }) end,
        function() self:Emit("incoming", MissText("PARRY"), C.inAvoid) end,
        function() self:Notify("Killing blow!", C.combat, { crit = true }) end,
    }
    -- Shown even while BattleText is turned off, and whatever is ticked in the options
    local LOOKS = { sticky = true, curved = true, scrollUp = true, healArea = true, healOver = true, merge = true,
        shortNumbers = true, healWho = true,
        outIcons = true, outNames = true, inIcons = true, inNames = true, healIcons = true, healNames = true, nIcons = true }
    local function show(fn)
        local saved = self.db
        self.db = setmetatable({}, { __index = function(_, k)
            if k == "minDamage" or k == "minHeal" then return 0 end
            local v = saved[k]
            if type(v) == "boolean" and not LOOKS[k] then return true end
            return v
        end })
        self.testing = true
        local ok, err = pcall(fn)
        self.testing = false
        self.db = saved
        if not ok then error(err, 0) end
    end
    for i, fn in ipairs(samples) do
        if C_Timer and C_Timer.After then
            C_Timer.After((i - 1) * 0.3, function() show(fn) end)
        else
            show(fn)
        end
    end
end

---------------------------------------------------------------------------
-- Minimap button
---------------------------------------------------------------------------
function BT:PositionMinimapButton()
    local angle = math.rad(self.db.minimapAngle or 215)
    local radius = (Minimap:GetWidth() / 2) + 10
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function BT:BuildMinimapButton()
    local b = CreateFrame("Button", "BattleTextForeverMinimapButton", Minimap)
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local icon = b:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(22, 22)
    icon:SetTexture(self.ICON)
    icon:SetPoint("TOPLEFT", 5, -4)
    local border = b:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT")
    b:SetScript("OnClick", function(_, button)
        if button == "RightButton" then BT:Test() else BT:OpenConfig() end
    end)
    b:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local px, py = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            BT.db.minimapAngle = math.deg(math.atan2(py / scale - my, px / scale - mx))
            BT:PositionMinimapButton()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(BT.LOGO_TEXT .. " BattleText Forever")
        GameTooltip:AddLine("Left-click: options", 1, 1, 1)
        GameTooltip:AddLine("Right-click: show sample text", 1, 1, 1)
        GameTooltip:AddLine("Drag: move this button", 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    self.minimapButton = b
    self:PositionMinimapButton()
end

function BT:UpdateMinimapButton()
    if self.minimapButton then self.minimapButton:SetShown(self.db.minimap) end
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function Help()
    Print("commands:")
    print("  |cffffd100/btf|r  open or close the options")
    print("  |cffffd100/btf test|r  show sample text")
    print("  |cffffd100/btf lock|r, |cffffd100/btf unlock|r  lock or unlock the text areas (unlock to drag them)")
    print("  |cffffd100/btf reset|r  put the text areas back where they started")
    print("  |cffffd100/btf on|r, |cffffd100/btf off|r  turn the text on or off")
    print("  |cffffd100/btf debug|r  record the combat lines the game sends; |cffffd100/btf copy|r shows them (for bug reports)")
    print("  |cffffd100/btf check|r  check the spells, texts and icons BattleText uses against this game")
end

-- Keybinding names (Options > Keybindings > BattleText Forever)
BattleTextForever = BT
_G["BINDING_NAME_CLICK BattleTextForeverStart:LeftButton"] = "Start BattleText"
BINDING_NAME_BATTLETEXTFOREVER_OPTIONS = "Open options"

SLASH_BATTLETEXTFOREVER1 = "/btf"
SLASH_BATTLETEXTFOREVER2 = "/battletext"
SlashCmdList.BATTLETEXTFOREVER = function(msg)
    local cmd = (msg or ""):lower():match("^%s*(%S*)")
    if cmd == "" or cmd == "config" or cmd == "options" then
        BT:OpenConfig()
    elseif cmd == "test" then
        BT:Test()
    elseif cmd == "lock" or cmd == "unlock" then
        BT:SetLocked(cmd == "lock")
        Print(cmd == "lock" and "text areas locked." or "text areas unlocked. Drag the boxes, then /btf lock.")
    elseif cmd == "reset" then
        BT:ResetPositions()
        Print("text areas moved back to where they started.")
    elseif cmd == "on" or cmd == "off" then
        BT.db.enabled = cmd == "on"
        BT:ApplySettings()
        Print(cmd == "on" and "on." or "off.")
    elseif cmd == "debug" then
        BT.db.debug = not BT.db.debug
        if BT.db.debug then BT.recorded = {} end
        Print("debug " .. (BT.db.debug and "on. Fight for a moment, then type /btf copy to see what the game sent." or "off."))
    elseif cmd == "copy" then
        BT:OpenCopyWindow()
    elseif cmd == "check" then
        BT:CheckGameData()
    else
        Help()
    end
    if BT.RefreshConfig then BT:RefreshConfig() end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
-- Registered one by one, in case this client doesn't have one of them
for _, e in ipairs({ "COMBAT_LOG_MESSAGE", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_LOGOUT",
    "PLAYER_XP_UPDATE", "CHAT_MSG_LOOT", "CHAT_MSG_MONEY", "CHAT_MSG_SKILL", "CHAT_MSG_COMBAT_FACTION_CHANGE",
    "CHAT_MSG_COMBAT_HONOR_GAIN" }) do
    pcall(events.RegisterEvent, events, e)
end
pcall(events.RegisterEvent, events, "UNIT_COMBAT")   -- every unit: you, your target, the mobs around you
pcall(events.RegisterUnitEvent, events, "UNIT_SPELLCAST_SUCCEEDED", "player")
pcall(events.RegisterUnitEvent, events, "UNIT_AURA", "player")
pcall(events.RegisterEvent, events, "PLAYER_EQUIPMENT_CHANGED")

events:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, a5)
    if event == "ADDON_LOADED" then
        if a1 ~= ADDON then return end
        BattleTextForeverDB = BattleTextForeverDB or {}
        BT:MoveOldSettings(BattleTextForeverDB)
        FillDefaults(BattleTextForeverDB, DEFAULTS)
        BattleTextForeverCharDB = BattleTextForeverCharDB or {}
        local char = BattleTextForeverCharDB
        if char.own and type(char.settings) == "table" then
            BT:MoveOldSettings(char.settings)
            FillDefaults(char.settings, DEFAULTS)
            BT.db = char.settings
        else
            char.own = nil
            BT.db = BattleTextForeverDB
        end
        BT:ApplyColors()
        return
    elseif event == "PLAYER_LOGIN" then
        Parser:Init()
        BT:BuildAreas()
        BT:BuildStartButton()
        BT:BuildMinimapButton()
        BT:HookCombatLog()
        BT.built = true
        BT:ApplySettings()
        BT:OnXP()
        -- The game turns the lines off whenever the Combat Log window hides
        if C_Timer and C_Timer.NewTicker then
            C_Timer.NewTicker(3, function() BT:KeepLogFlowing() end)
        end
        print(T.CHAT_PREFIX .. " loaded. Type /btf for options.")
        if C_Timer and C_Timer.After then
            C_Timer.After(REMIND_AFTER, function() BT:RemindStart() end)
        end
        return
    end
    if not BT.built then return end

    if event == "COMBAT_LOG_MESSAGE" then
        BT:OnCombatLogMessage(a1, a2, a3, a4, a5)
    elseif event == "UNIT_COMBAT" then
        BT:OnUnitCombat(a1, a2, a3, a4, a5)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        BT:OnSpellcast(a3)
    elseif event == "UNIT_AURA" then
        BT:ScanShield()
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        BT:ScanItemShields()
    elseif event == "PLAYER_REGEN_DISABLED" then
        BT:ScanShield()      -- last look at your buffs and gear before the fight hides them
        BT:ScanItemShields()
        BT:SetStartMacro()   -- last chance before the fight to note which chat tab you're on
        if BT.db.nCombat then BT:Notify("+Combat", BT.TEXT_COLORS.combat) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if BT.db.nCombat then BT:Notify("-Combat", BT.TEXT_COLORS.notify) end
        BT:ScanShield()   -- your buffs can be read again: what changed during the fight
        if BT.startPending then
            BT.startPending = nil
            BT:UpdateStartButton()
        end
        BT:SetStartMacro()
        BT:ApplyBlizzardText()
        BT:ScanShield()
        BT:ScanItemShields()   -- (gear changed in the fight is read now)
    elseif event == "PLAYER_LOGOUT" then
        BT:ApplyBlizzardText(true)
    elseif event == "PLAYER_ENTERING_WORLD" then
        BT:ScanShield()
        BT:ScanItemShields()
        BT:HookCombatLog()
        BT:SetStartMacro()
        BT:UpdateStartButton()
        BT.lastXP = nil
        BT:OnXP()
    elseif event == "PLAYER_XP_UPDATE" then
        BT:OnXP()
    elseif event == "CHAT_MSG_LOOT" then
        BT:OnLoot(a1)
    elseif event == "CHAT_MSG_MONEY" then
        BT:OnChatNotice("nMoney", a1, BT.TEXT_COLORS.notify)
    elseif event == "CHAT_MSG_SKILL" then
        BT:OnChatNotice("nSkill", a1, BT.TEXT_COLORS.power)
    elseif event == "CHAT_MSG_COMBAT_FACTION_CHANGE" then
        BT:OnChatNotice("nRep", a1, BT.TEXT_COLORS.power)
    elseif event == "CHAT_MSG_COMBAT_HONOR_GAIN" then
        BT:OnChatNotice("nHonor", a1, BT.TEXT_COLORS.notify)
    end
end)
