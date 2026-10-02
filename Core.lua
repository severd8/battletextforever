-- BattleText Forever: scrolling combat text for World of Warcraft: Forever.
-- Your damage and heals come from the game's combat log lines (see Parse.lua);
-- damage you take also comes from the UNIT_COMBAT event, which needs no setup.

local ADDON, ns = ...
local BT = {}
ns.BT = BT
local Parser = ns.Parser

BT.COLORS = {
    gold     = { 1.00, 0.85, 0.40 },
    goldDark = { 0.85, 0.65, 0.19 },
    navy     = { 0.06, 0.14, 0.23 },
    dark     = { 0.07, 0.05, 0.11 },
    crimson  = { 0.55, 0.12, 0.12 },
}
BT.GOLD_HEX = "ffd966"
BT.ICON = "Interface\\AddOns\\BattleTextForever\\Media\\Icon"
BT.LOGO_TEXT = "|T" .. BT.ICON .. ":0|t"
local PREFIX = "|cffffd966BattleText|r: "
local function Print(msg) print(BT.LOGO_TEXT .. " " .. PREFIX .. msg) end
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

local DEFAULTS = {
    enabled = true,
    locked = true,
    font = "Default",
    fontSize = 20,
    critScale = 150,          -- crits, as a percent of the text size
    scrollTime = 3,           -- seconds a line takes to cross its area
    height = 240,             -- how far a line travels
    curved = true,            -- lines bow outward as they scroll
    sticky = true,            -- crits pop and hold in place
    spellNames = true,
    icons = true,
    merge = true,             -- rapid hits of one spell add up on one line
    minDamage = 0,            -- hide your hits below this
    outDamage = true, outHeals = true, outMisses = true, outPet = true,
    inDamage = true, inHeals = true, inMisses = true, inPower = false,
    nCombat = true, nKill = true, nXP = true, nRep = true, nHonor = true,
    nLoot = true, nMoney = false, nSkill = true,
    hideBlizzard = false,
    minimap = true,
    minimapAngle = 215,
    debug = false,
    areas = {
        incoming = { x = -230, y = 20 },
        outgoing = { x = 230, y = 20 },
        notify = { x = 0, y = 170 },
    },
}
BT.DEFAULTS = DEFAULTS

-- "Default" is the game's own font for your language
BT.FONTS = {
    { name = "Default" },
    { name = "Friz Quadrata", path = "Fonts\\FRIZQT__.TTF" },
    { name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
    { name = "Morpheus", path = "Fonts\\MORPHEUS.TTF" },
    { name = "Skurri", path = "Fonts\\SKURRI.TTF" },
}

-- Scroll areas. dir: which way a curved line bows (-1 left, 1 right, 0 none).
BT.AREAS = {
    incoming = { label = "Incoming", dir = -1, justify = "RIGHT" },
    outgoing = { label = "Outgoing", dir = 1, justify = "LEFT" },
    notify   = { label = "Notifications", dir = 0, justify = "CENTER", short = true },
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

local function Commas(n)
    if BreakUpLargeNumbers then
        local ok, s = pcall(BreakUpLargeNumbers, n)
        if ok and Str(s) then return s end
    end
    return tostring(n)
end

function BT:AddBorder(f, color, size)
    size = size or 1
    for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, size }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, size },
        { "TOPLEFT", "BOTTOMLEFT", size, nil }, { "TOPRIGHT", "BOTTOMRIGHT", size, nil } }) do
        local t = f:CreateTexture(nil, "BORDER")
        t:SetColorTexture(color[1], color[2], color[3], 1)
        t:SetPoint(e[1])
        t:SetPoint(e[2])
        if e[3] then t:SetWidth(e[3]) else t:SetHeight(e[4]) end
    end
end

function BT:SkinFrame(f, bg, border, alpha, size)
    local t = f:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints()
    t:SetColorTexture(bg[1], bg[2], bg[3], alpha or 0.95)
    self:AddBorder(f, border or self.COLORS.goldDark, size or 2)
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

function BT:BuildAreas()
    self.areas = {}
    for key, def in pairs(self.AREAS) do
        local a = CreateFrame("Frame", "BattleTextForever" .. def.label, UIParent)
        a:SetFrameStrata("HIGH")
        a.key, a.def = key, def
        a.active, a.pool, a.recent = {}, {}, {}

        -- Shown while unlocked: a box to drag
        local mover = CreateFrame("Frame", nil, a)
        mover:SetAllPoints()
        self:SkinFrame(mover, self.COLORS.navy, self.COLORS.goldDark, 0.55, 1)
        mover.label = mover:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        mover.label:SetPoint("CENTER")
        mover.label:SetText(def.label)
        mover.label:SetTextColor(unpack(self.COLORS.gold))
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

function BT:AreaHeight(a)
    return a.def.short and math.floor(self.db.height * 0.45) or self.db.height
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
    local size = self.db.fontSize
    if opts.crit then size = math.floor(size * self.db.critScale / 100 + 0.5) end
    if not o.text:SetFont(self:FontPath(), size, "OUTLINE") and STANDARD_TEXT_FONT then
        o.text:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")
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
                    y = -p * h
                    if self.db.curved and a.def.dir ~= 0 then
                        x = a.def.dir * AREA_WIDTH * (1 - (2 * p - 1) ^ 2)
                    end
                    if p < 0.08 then alpha = p / 0.08 elseif p > 0.75 then alpha = (1 - p) / 0.25 end
                end
                o:SetScale(scale)
                o:ClearAllPoints()
                o:SetPoint(o.anchor, a, "TOP", x / scale, y / scale)
                o:SetAlpha(alpha)
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
    if not self.db.icons or not spell then return "" end
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

function BT:SpellLabel(info)
    if info.spell and self.db.spellNames then return info.spell end
    return nil
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
    local name = self:SpellLabel(info)
    local icon = self:IconText(info.spellId or info.spell)
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
                local text = "-" .. Commas(info.amount) .. (name and (" " .. name) or "") .. Partials(info)
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
        local over = info.overheal and (" |cffb0b0b0(" .. Commas(info.overheal) .. " over)|r") or ""
        local nothing = info.amount == 0 and info.overheal   -- all of it was overhealing
        if info.toMe then
            if mine then self.lastSelfHeal = GetTime() else self:NoteLogIncoming("heal") end
            if nothing then return true end
            if db.inHeals then
                self:Emit("incoming", "+" .. Commas(info.amount) .. (name and (" " .. name) or "") .. over, C.heal,
                    { crit = info.crit })
            elseif mine and db.outHeals then
                self:Emit("outgoing", outLabel .. "+" .. Commas(info.amount) .. over, C.heal, { crit = info.crit })
            end
            return true
        elseif mine or pet then
            if pet and not db.outPet then return true end
            if db.outHeals and not nothing then
                self:Emit("outgoing", outLabel .. "+" .. Commas(info.amount) .. over, C.heal, { crit = info.crit })
            end
            return true
        end
    elseif info.kind == "miss" then
        local word = MissText(info.missType)
        if info.toMe then
            if not mine then self:NoteLogIncoming("miss") end
            if db.inMisses and not mine then
                self:Emit("incoming", word .. (name and (" " .. name) or ""), C.inAvoid)
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

function BT:OnUnitCombat(unit, action, flag, amount)
    if Str(unit) ~= "player" then return end
    action, flag = Str(action), Str(flag)
    if self.db.debug then
        self:Record("UNIT_COMBAT " .. tostring(action) .. " " .. tostring(flag) .. " "
            .. (IsSecret(amount) and "(hidden amount)" or tostring(amount)))
    end
    if not action then return end
    local db, C = self.db, self.TEXT_COLORS
    local crit = flag == "CRITICAL" or flag == "CRUSHING"
    local secret = IsSecret(amount)
    local n = Num(amount)
    if action == "WOUND" then
        if secret or (n and n > 0) then
            if self:LogCovers("damage") or not db.inDamage then return end
            if secret then
                self:Emit("incoming", "-", C.inDamage, { crit = crit, secret = amount })
            else
                self:Emit("incoming", "-" .. Commas(n), C.inDamage, { crit = crit })
            end
        else
            -- No damage: fully absorbed, blocked or resisted, or a plain miss
            if self:LogCovers("miss") or not db.inMisses then return end
            self:Emit("incoming", MissText(flag and MISS_TEXT[flag] and flag or "MISS"), C.inAvoid)
        end
    elseif action == "HEAL" then
        if self:LogCovers("heal") or not db.inHeals then return end
        -- Your own heals on yourself also come from the combat log, with the
        -- spell's name. Wait a moment to see whether this is one of those.
        local function show()
            if BT.lastSelfHeal and GetTime() - BT.lastSelfHeal < 0.6 then return end
            if BT:LogDelivers("heal") then return end   -- the log's line for it arrived meanwhile
            if secret then
                BT:Emit("incoming", "+", C.heal, { crit = crit, secret = amount })
            elseif n and n > 0 then
                BT:Emit("incoming", "+" .. Commas(n), C.heal, { crit = crit })
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
    if IsSecret(message) then
        -- The game is hiding the text. It can still be shown, just not read.
        if self.db.debug then self:Record("(hidden line)") end
        if self.db.outDamage then self:Emit("outgoing", "", self.TEXT_COLORS.melee, { secret = message }) end
        return
    end
    local info = Parser:Parse(message)
    local shown = info ~= nil and self:ShowCombat(info)
    if self.db.debug then self:Record((shown and "read    " or "skipped ") .. message) end
end

-- Debug (/btf debug, then /btf copy): what the game sent, exactly, with the time
-- it arrived. Kept only while debug is on, and only the last 150.
function BT:Record(text)
    self.recorded = self.recorded or {}
    local list = self.recorded
    list[#list + 1] = ("%7.2f  %s"):format(GetTime() % 1000, text)
    if #list > 150 then table.remove(list, 1) end
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
    if id and self.db.icons and C_Item and C_Item.GetItemIconByID then
        local ok, tex = pcall(C_Item.GetItemIconByID, id)
        if ok and not IsSecret(tex) and tex then icon = "|T" .. tex .. ":0|t " end
    end
    self:Notify(icon .. "+" .. count .. " " .. link, self.TEXT_COLORS.loot)
end

-- Chat lines shown as they are, minus the trailing period
function BT:OnChatNotice(setting, message, color)
    message = Str(message)
    if not message or not self.db[setting] then return end
    self:Notify((message:gsub("%.%s*$", "")), color)
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
    self:SkinFrame(b, self.COLORS.crimson, self.COLORS.goldDark, 0.95, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(18, 18)
    b.icon:SetPoint("LEFT", 6, 0)
    b.icon:SetTexture(self.ICON)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b.label:SetText("Start BattleText")
    b.label:SetTextColor(unpack(self.COLORS.gold))
    b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine("Start BattleText", unpack(BT.COLORS.gold))
        GameTooltip:AddLine("The game only writes its combat lines after the Combat Log tab has been opened once. "
            .. "This click opens it and switches back for you.", 1, 1, 1, true)
        GameTooltip:AddLine("Needed once each time you log in.", 0.7, 0.7, 0.7, true)
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
function BT:ApplySettings()
    if not self.built then return end
    self:ApplyAreas()
    self:UpdateStartButton()
    self:UpdateMinimapButton()
    self:ApplyBlizzardText()
    if self.db.enabled then self:KeepLogFlowing() else self:StopLogFlowing() end
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
        function() self:Emit("incoming", "+120 Rejuvenation", C.heal) end,
        function() self:ShowCombat({ kind = "miss", fromMe = true, melee = true, missType = "DODGE" }) end,
        function() self:Emit("incoming", "-58", C.inDamage, { crit = true }) end,
        function() self:Notify("+103 XP", C.xp) end,
        function() self:ShowCombat({ kind = "damage", fromMe = true, melee = true, amount = 26, unit = "Physical", blocked = 3 }) end,
        function() self:Emit("incoming", MissText("PARRY"), C.inAvoid) end,
        function() self:Notify("Killing blow!", C.combat, { crit = true }) end,
    }
    -- Shown even while BattleText is turned off, and whatever is ticked in the options
    local LOOKS = { sticky = true, curved = true, icons = true, spellNames = true, merge = true }
    local function show(fn)
        local saved = self.db
        self.db = setmetatable({}, { __index = function(_, k)
            if k == "minDamage" then return 0 end
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
    print("  |cffffd966/btf|r  open or close the options")
    print("  |cffffd966/btf test|r  show sample text")
    print("  |cffffd966/btf lock|r, |cffffd966/btf unlock|r  lock or unlock the text areas (unlock to drag them)")
    print("  |cffffd966/btf reset|r  put the text areas back where they started")
    print("  |cffffd966/btf on|r, |cffffd966/btf off|r  turn the text on or off")
    print("  |cffffd966/btf debug|r  record the combat lines the game sends; |cffffd966/btf copy|r shows them (for bug reports)")
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
pcall(events.RegisterUnitEvent, events, "UNIT_COMBAT", "player")

events:SetScript("OnEvent", function(_, event, a1, a2, a3, a4, a5)
    if event == "ADDON_LOADED" then
        if a1 ~= ADDON then return end
        BattleTextForeverDB = BattleTextForeverDB or {}
        FillDefaults(BattleTextForeverDB, DEFAULTS)
        BT.db = BattleTextForeverDB
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
        print(BT.LOGO_TEXT .. " |cffffd966BattleText Forever|r loaded. Type /btf for options.")
        return
    end
    if not BT.built then return end

    if event == "COMBAT_LOG_MESSAGE" then
        BT:OnCombatLogMessage(a1, a2, a3, a4, a5)
    elseif event == "UNIT_COMBAT" then
        BT:OnUnitCombat(a1, a2, a3, a4)
    elseif event == "PLAYER_REGEN_DISABLED" then
        BT:SetStartMacro()   -- last chance before the fight to note which chat tab you're on
        if BT.db.nCombat then BT:Notify("+Combat", BT.TEXT_COLORS.combat) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if BT.db.nCombat then BT:Notify("-Combat", BT.TEXT_COLORS.notify) end
        if BT.startPending then
            BT.startPending = nil
            BT:UpdateStartButton()
        end
        BT:SetStartMacro()
        BT:ApplyBlizzardText()
    elseif event == "PLAYER_LOGOUT" then
        BT:ApplyBlizzardText(true)
    elseif event == "PLAYER_ENTERING_WORLD" then
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
