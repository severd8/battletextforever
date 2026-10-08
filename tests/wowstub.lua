-- Minimal WoW API stub for exercising BattleText Forever outside the game.
-- Methods (CamelCase keys) default to no-ops; lowercase fields read as nil like real frames.
--
-- Where it matters, the stub behaves like the game instead of just accepting calls:
--   * the Combat Log window loads its filter when it's shown, which only works
--     from the game's own code (a hardware click), never from addon code
--   * combat log lines only arrive once that has happened and the lines are on
--   * a secure button's macro runs on mouse down or up (a game setting decides)
--   * anything an addon must never do is recorded in VIOLATIONS: replacing one of
--     the game's globals or a script on one of its frames, asking for the combat
--     log events, calling a Blizzard-only function

local STANDARD = {}   -- what Lua itself provides (everything else below is "the game")
for k in pairs(_G) do STANDARD[k] = true end

LOG = {}
GetBindingKey = function(command) return STATE.bindingKeys and STATE.bindingKeys[command] end
local function log(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end LOG[#LOG + 1] = table.concat(t, " ") end
print = function(...) log(...) end

ALL_FRAMES = {}
BLOCKED = {}          -- protected actions attempted in combat
VIOLATIONS = {}       -- things an addon must never do
COMBAT = false
SECRET_MODE = false
SECURE = false        -- true while the game's own code runs from a hardware click
local LOADED = false  -- the stub has finished loading: from here on, callers are the addon or the tests
local function violation(what) VIOLATIONS[#VIOLATIONS + 1] = what end

-- Secret values: a marker table that errors on arithmetic, ordering, concatenation
local SecretMT = {}
local function boom() error("attempted to use a secret value", 2) end
SecretMT.__add, SecretMT.__sub, SecretMT.__mul, SecretMT.__div = boom, boom, boom, boom
SecretMT.__lt, SecretMT.__le, SecretMT.__concat, SecretMT.__unm = boom, boom, boom, boom
SecretMT.__tostring = function() return "<secret>" end
local function secret(v) return setmetatable({ v = v }, SecretMT) end
function issecretvalue(v) return type(v) == "table" and getmetatable(v) == SecretMT end
local function maybeSecret(v) if SECRET_MODE then return secret(v) end return v end

local PROTECTED_WHEN_COMBAT = { SetPoint = true, ClearAllPoints = true, SetSize = true, SetWidth = true,
    SetHeight = true, SetAttribute = true, Show = true, Hide = true, SetShown = true, SetScale = true,
    StartMoving = true, StopMovingOrSizing = true }

local ObjMT = {}
local Methods = {}
STUB_METHODS = Methods   -- tests/render.lua adds layout tracking
ObjMT.__index = function(t, k)
    if Methods[k] then return Methods[k] end
    if type(k) == "string" and k:match("^%u") then
        return function(self, ...)
            for i = 1, select("#", ...) do
                local a = select(i, ...)
                if issecretvalue(a) and not ({ SetText = 1, SetFormattedText = 1, SetValue = 1, SetMinMaxValues = 1,
                        SetAlpha = 1, SetCooldown = 1 })[k] then
                    error("secret passed to " .. k)
                end
            end
            if COMBAT and self.__protected and PROTECTED_WHEN_COMBAT[k] then
                BLOCKED[#BLOCKED + 1] = (self.__name or self.__kind) .. ":" .. k
            end
            return nil
        end
    end
    return nil
end

function newObj(kind, name, parent, template)
    local o = setmetatable({ __kind = kind, __name = name, __parent = parent, __template = template,
        __scripts = {}, __shown = true, __attrs = {}, __children = {} }, ObjMT)
    if template and (template:find("Secure") or template:find("SecureUnitButton")) then o.__protected = true end
    if parent and parent.__children then table.insert(parent.__children, o) end
    ALL_FRAMES[#ALL_FRAMES + 1] = o
    if name then _G[name] = o end
    return o
end

local function protectedCheck(self, what)
    if COMBAT and self.__protected then BLOCKED[#BLOCKED + 1] = (self.__name or self.__kind) .. ":" .. what end
end

function Methods:CreateTexture() return newObj("Texture", nil, self) end
function Methods:CreateFontString() local f = newObj("FontString", nil, self); f.__text = "" return f end
function Methods:CreateAnimationGroup() local g = newObj("AnimationGroup", nil, self); g.__playing = false return g end
function Methods:CreateAnimation() return newObj("Animation", nil, self) end
function Methods:Play() self.__playing = true end
function Methods:Stop() self.__playing = false end
function Methods:IsPlaying() return self.__playing end
function Methods:Show()
    protectedCheck(self, "Show")
    local was = self.__shown
    self.__shown = true
    if not was and self.__scripts.OnShow then self.__scripts.OnShow(self) end
end
function Methods:Hide()
    protectedCheck(self, "Hide")
    local was = self.__shown
    self.__shown = false
    if was and self.__scripts.OnHide then self.__scripts.OnHide(self) end
end
function Methods:SetShown(v) if v then self:Show() else self:Hide() end end
function Methods:IsShown() return self.__shown end
function Methods:IsVisible()
    local f = self
    while f do if f.__shown == false then return false end f = f.__parent end
    return true
end
function Methods:SetScript(k, fn)
    if LOADED and self.__blizzard then violation("SetScript(" .. k .. ") on the game's " .. tostring(self.__name)) end
    self.__scripts[k] = fn
end
function Methods:GetScript(k) return self.__scripts[k] end
-- The hook runs after the original, as addon code (never as the game's own)
function Methods:HookScript(k, fn)
    local old = self.__scripts[k]
    self.__scripts[k] = function(...)
        if old then old(...) end
        local was = SECURE
        SECURE = false
        fn(...)
        SECURE = was
    end
end
function Methods:RegisterForClicks(...) self.__clicks = { ... } end
function Methods:SetAttribute(k, v) protectedCheck(self, "SetAttribute") self.__attrs[k] = v end
function Methods:GetAttribute(k) return self.__attrs[k] end
function Methods:SetText(t)
    if issecretvalue(t) then self.__text = "<secret>" return end
    self.__text = t
end
function Methods:SetFormattedText(fmt, ...)
    for i = 1, select("#", ...) do if issecretvalue((select(i, ...))) then self.__text = "<secret fmt>" return end end
    self.__text = fmt:format(...)
end
function Methods:GetText() return self.__text end
function Methods:SetChecked(v) self.__checked = v and true or false end
function Methods:GetChecked() return self.__checked end
function Methods:GetFont() return "Fonts\\FRIZQT__.TTF", 10, "" end
function Methods:GetRegions() local r = {} for _, c in ipairs(self.__children) do if c.__kind == "Texture" or c.__kind == "FontString" then r[#r + 1] = c end end return unpack(r) end
function Methods:GetObjectType() return self.__kind end
function Methods:GetHighlightTexture() return nil end
function Methods:GetPoint() return "CENTER", UIParent, "CENTER", 12, 34 end
function Methods:GetLeft() return self.__left end
function Methods:GetTop() return self.__top end
local oldSetPoint
function Methods:SetPoint(p, rel, rp, x, y)
    if COMBAT and self.__protected then BLOCKED[#BLOCKED + 1] = (self.__name or self.__kind) .. ":SetPoint" end
    self.__point = p
    if type(rel) == "table" then self.__pos = { x or 0, y or 0 } else self.__pos = { rel or 0, rp or 0 } end
end
function Methods:GetWidth() return 140 end
function Methods:GetCenter() return 0, 0 end
function Methods:GetEffectiveScale() return 1 end
function Methods:GetName() return self.__name end
function Methods:GetFrameLevel() return 1 end
function Methods:SetFrameLevel(l) self.__frameLevel = l end
function Methods:SetSize(w, h) protectedCheck(self, "SetSize") self.__size = { w, h } end
function Methods:SetValue(v) self.__value = v if self.__scripts.OnValueChanged then self.__scripts.OnValueChanged(self, issecretvalue(v) and 0 or v) end end
function Methods:SetMinMaxValues(a, b) self.__min, self.__max = a, b end
function Methods:RegisterEvent(e)
    -- WoW: Forever refuses these to addons
    if e == "COMBAT_LOG_EVENT" or e == "COMBAT_LOG_EVENT_UNFILTERED" then
        violation("RegisterEvent(" .. e .. ")")
        error("Attempt to register for a restricted event: " .. e)
    end
    self.__events = self.__events or {}
    self.__events[e] = true
end
function Methods:RegisterUnitEvent(e) self.__events = self.__events or {} self.__events[e] = true end
function Methods:SetAlpha(a) self.__alpha = a end
function Methods:GetFontString() return nil end
function Methods:SetEnabled(v) self.__enabled = v end
function Methods:SetDesaturated(v) self.__desat = v end
function Methods:SetTexture(t) self.__texture = t end
function Methods:StartMoving() protectedCheck(self, "StartMoving") self.__moving = true end
function Methods:StopMovingOrSizing() protectedCheck(self, "StopMovingOrSizing") self.__moving = false end

function CreateFrame(kind, name, parent, template)
    if kind == "DropdownButton" and STATE.noDropdown then error("Unknown frame type: DropdownButton") end
    return newObj(kind, name, parent, template)
end

-- The game's menus. A menu is described by a function that's handed a "root"
-- to add rows to; here the rows are just collected: { text, isSelected, pick }.
local function describeMenu(generator, owner)
    local rows = { scroll = nil }
    local root = {}
    function root:SetScrollMode(extent) rows.scroll = extent end
    function root:CreateRadio(text, isSelected, setSelected)
        rows[#rows + 1] = { text = text, isSelected = isSelected, pick = setSelected }
    end
    generator(owner, root)
    return rows
end
-- The game's dropdown button shows whichever row is ticked
function Methods:SetupMenu(generator)
    assert(self.__kind == "DropdownButton", "SetupMenu is the dropdown button's")
    self.__generator = generator
    if self:IsVisible() then self:GenerateMenu() end
end
function Methods:GenerateMenu()
    self.__menu = describeMenu(self.__generator, self)
    for _, row in ipairs(self.__menu) do
        if row.isSelected() then self.__text = row.text end
    end
end
-- A menu opened from any other button: the test looks at MENU_OPENED
MenuUtil = {
    CreateContextMenu = function(owner, generator) MENU_OPENED = describeMenu(generator, owner) end,
}
UIParent = newObj("Frame", "UIParent")
Minimap = newObj("Frame", "Minimap")
GameTooltip = newObj("GameTooltip", "GameTooltip")
UISpecialFrames, SlashCmdList = {}, {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

-- Game state the tests set up
STATE = {
    xp = 100, xpMax = 1000,
    pet = false,                  -- you have a pet out
    filterApplied = false,        -- the Combat Log window has loaded its filter (lines can flow)
    logBroken = false,            -- an addon tried to load the filter: the game's combat log is broken until /reload
    useKeyDown = false,           -- the "act on key down" game setting
    cvars = { enableFloatingCombatText = "1", floatingCombatTextCombatDamage = "1", floatingCombatTextCombatHealing = "1" },
    filteredEvents = false,       -- C_CombatLog.SetFilteredEventsEnabled
    spellIcons = { [16827] = 132140, [8921] = 136096 },   -- by spell ID
    spellNames = { [16827] = "Claw", [8921] = "Moonfire", [1082] = "Claw", [1822] = "Rake", [1079] = "Rip", [5221] = "Shred",
        [467] = "Thorns", [782] = "Thorns", [1075] = "Thorns", [324] = "Lightning Shield", [5570] = "Insect Swarm",
        [768] = "Cat Form" },
    buffs = {},                   -- your buffs: { name = "Thorns", spellId = 782 }
    equipped = {},                -- your gear by slot: { name = "Sporid Cape", icon = 133762, lines = { "Equip: ..." } }
    spellDescriptions = {},       -- by spell ID
    buffsHidden = false,          -- the game won't show buffs right now (asking throws an error)
    -- Other units. who: the names a unit goes by ("target", "nameplate1"...) -> the unit.
    -- unit: what's known about each (enemy, guid, target = the unit it's targeting; "me" and "pet" are yours).
    who = {}, unit = {},
    group = false,                -- you're in a party
    noDropdown = false,           -- a client without the game's dropdown button
}

FAKE_TIME = 1000
function GetTime() return FAKE_TIME end
function InCombatLockdown() return COMBAT end
function UnitXP() return STATE.xp end
function UnitXPMax() return STATE.xpMax end
-- Which unit a name like "target", "nameplate2" or "targettarget" stands for
local function who(token)
    if token == "player" then return "me" end
    if token == "pet" then return STATE.pet and "pet" or nil end
    if STATE.who[token] then return STATE.who[token] end
    local base = token:match("^(.+)target$")
    local id = base and who(base)
    return id and STATE.unit[id] and STATE.unit[id].target or nil
end
function UnitExists(unit) return who(unit) ~= nil end
function UnitGUID(unit)
    if unit == "player" then return "Player-5555-0ABCDEF1" end
    if unit == "pet" and STATE.pet then return "Pet-0-1-2-3-4-000002" end
    local id = who(unit)
    return id and STATE.unit[id] and STATE.unit[id].guid or nil
end
function UnitIsUnit(a, b)
    local x, y = who(a), who(b)
    return x ~= nil and x == y
end
function UnitCanAttack(a, b)
    local id = who(b)
    return a == "player" and id ~= nil and STATE.unit[id] ~= nil and STATE.unit[id].enemy == true
end
-- A unit's name: STATE.unit[id].name, or hidden when .secretName is set
function UnitName(unit)
    if unit == "player" then return "Me" end
    local id = who(unit)
    local u = id and STATE.unit[id]
    if not u then return nil end
    if u.secretName then return Secret(u.name or "Hidden") end
    return u.name
end
function IsInGroup() return STATE.group end
function IsInRaid() return false end
function UnitPowerType() return 1, "RAGE" end
function GetCVar(name) return STATE.cvars[name] end
function SetCVar(name, value) STATE.cvars[name] = tostring(value) end
function GetCursorPosition() return 10, 10 end
function BreakUpLargeNumbers(n)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    return (out:gsub("^,", ""))
end

-- Timers: run them with RunTimers(seconds)
TIMERS, TICKERS = {}, {}
C_Timer = {
    After = function(delay, fn) TIMERS[#TIMERS + 1] = { at = FAKE_TIME + delay, fn = fn } end,
    NewTicker = function(every, fn) TICKERS[#TICKERS + 1] = { every = every, at = FAKE_TIME + every, fn = fn } end,
}
-- Moves time forward in small steps, firing timers and every frame's OnUpdate
function Advance(seconds)
    local step = 0.05
    local finish = FAKE_TIME + seconds
    while FAKE_TIME < finish - 1e-9 do
        FAKE_TIME = FAKE_TIME + step
        local due = {}
        for i = #TIMERS, 1, -1 do
            if TIMERS[i].at <= FAKE_TIME + 1e-9 then table.insert(due, 1, table.remove(TIMERS, i)) end
        end
        for _, t in ipairs(due) do t.fn() end
        for _, t in ipairs(TICKERS) do
            if t.at <= FAKE_TIME + 1e-9 then
                t.at = t.at + t.every
                t.fn()
            end
        end
        for _, f in ipairs(ALL_FRAMES) do
            if f.__scripts and f.__scripts.OnUpdate then f.__scripts.OnUpdate(f, step) end
        end
    end
end

-- Loading the Combat Log's filter. Only the game's own code may: from addon
-- code the call is blocked, and the game's combat log errors until /reload.
local function ApplyFilterSettings()
    if SECURE then
        STATE.filterApplied = true
    else
        violation("C_CombatLog.ApplyFilterSettings from addon code")
        STATE.logBroken = true
    end
end
C_CombatLog = {
    SetFilteredEventsEnabled = function(on) STATE.filteredEvents = on end,
    AreFilteredEventsEnabled = function() return STATE.filteredEvents end,
    ApplyFilterSettings = ApplyFilterSettings,
}
Enum = { CombatLogMessageOrder = { Newest = 0, Oldest = 1 } }
C_Spell = {
    GetSpellTexture = function(spell) return STATE.spellIcons[spell] end,
    GetSpellName = function(id) return STATE.spellNames[id] end,
    GetSpellDescription = function(id) return STATE.spellDescriptions[id] end,
}
C_UnitAuras = {
    GetAuraDataByIndex = function(unit, i, filter)
        assert(unit == "player" and filter == "HELPFUL", "only your own buffs are read")
        if STATE.buffsHidden then error("auras are hidden right now") end
        return STATE.buffs[i]
    end,
}
function GetLocale() return STATE.locale or "enUS" end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
-- The game's files: every path is there unless STATE.missingFiles names it
function GetFileIDFromPath(path)
    if STATE.missingFiles and STATE.missingFiles[path] then return nil end
    return 12345
end
-- The game's colour picker: remembers what it was opened with; a test "picks" by
-- setting STATE.picked and calling swatchFunc, or cancels with cancelFunc
ColorPickerFrame = {
    SetupColorPickerAndShow = function(self, info) self.info = info self.shown = true end,
    GetColorRGB = function() return STATE.picked[1], STATE.picked[2], STATE.picked[3] end,
}
-- An equipped item's tooltip: its name, then its lines
C_TooltipInfo = {
    GetInventoryItem = function(unit, slot)
        assert(unit == "player", "only your own gear is read")
        local item = STATE.equipped[slot]
        if not item then return nil end
        if item.hidden then return Secret({}) end
        local lines = { { leftText = item.name } }
        for _, text in ipairs(item.lines or {}) do lines[#lines + 1] = { leftText = text } end
        if item.oldShape then   -- the text kept in each line's "args" instead
            for i, line in ipairs(lines) do
                lines[i] = { args = { { field = "leftColor" }, { field = "leftText", stringVal = line.leftText } } }
            end
        end
        return { lines = lines }
    end,
}
function GetInventoryItemTexture(unit, slot) return STATE.equipped[slot] and STATE.equipped[slot].icon end
C_Item = { GetItemIconByID = function(id) return 134000 + id end }

-- The chat tabs (General, Combat Log, Loot), and the Combat Log window behind the second one
ChatFrame1 = newObj("ScrollingMessageFrame", "ChatFrame1")
ChatFrame2 = newObj("ScrollingMessageFrame", "ChatFrame2")
ChatFrame3 = newObj("ScrollingMessageFrame", "ChatFrame3")
ChatFrame2.__shown, ChatFrame3.__shown = false, false
COMBATLOG = ChatFrame2
ChatFrame1Tab = newObj("Button", "ChatFrame1Tab")
ChatFrame2Tab = newObj("Button", "ChatFrame2Tab")
ChatFrame3Tab = newObj("Button", "ChatFrame3Tab")
SELECTED_DOCK_FRAME = ChatFrame1
GENERAL_CHAT_DOCK = {}
-- What Blizzard's Combat Log does when its window shows and hides
ChatFrame2.__scripts.OnShow = function()
    C_CombatLog.SetFilteredEventsEnabled(true)
    ApplyFilterSettings()
end
ChatFrame2.__scripts.OnHide = function() C_CombatLog.SetFilteredEventsEnabled(false) end
-- Clicking a tab shows its window and hides the others
local GAME   -- the game's globals (filled in at the end of this file)
function FCFDock_GetSelectedWindow() return GAME.SELECTED_DOCK_FRAME end
local function TabClick(tab, button)
    if button ~= "LeftButton" then return end
    local windows = { [ChatFrame1Tab] = ChatFrame1, [ChatFrame2Tab] = ChatFrame2, [ChatFrame3Tab] = ChatFrame3 }
    local show = windows[tab]
    if show == GAME.SELECTED_DOCK_FRAME then return end
    GAME.SELECTED_DOCK_FRAME = show
    for _, window in pairs(windows) do
        if window ~= show then window:Hide() end
    end
    show:Show()
end
ChatFrame1Tab.__scripts.OnClick = TabClick
ChatFrame2Tab.__scripts.OnClick = TabClick
ChatFrame3Tab.__scripts.OnClick = TabClick
-- Your own click on a chat tab
function ClickTab(tab)
    SECURE = true
    tab.__scripts.OnClick(tab, "LeftButton", false)
    SECURE = false
end

-- A real click on a button: mouse down, then up. A secure button's macro runs
-- on one of the two (the "act on key down" setting decides which), as the
-- game's own code, and only if the button is listening for that half of the click.
function ClickButton(b)
    for _, down in ipairs({ true, false }) do
        local wanted = down and "AnyDown" or "AnyUp"
        local listening = false
        for _, c in ipairs(b.__clicks or { "LeftButtonUp" }) do
            if c == wanted or c == (down and "LeftButtonDown" or "LeftButtonUp") then listening = true end
        end
        if listening then
            if b.__scripts.PreClick then b.__scripts.PreClick(b, "LeftButton", down) end
            if b.__protected and down == STATE.useKeyDown and b.__attrs.type == "macro" then
                SECURE = true
                for name in (b.__attrs.macrotext or ""):gmatch("/click ([^\n]+)") do
                    local target = _G[name]
                    if target and target.__scripts.OnClick then target.__scripts.OnClick(target, "LeftButton", false) end
                end
                SECURE = false
            end
            if b.__scripts.OnClick then b.__scripts.OnClick(b, "LeftButton", down) end
            if b.__scripts.PostClick then b.__scripts.PostClick(b, "LeftButton", down) end
        end
    end
end

Secret = secret   -- tests make hidden values with Secret(123)
function Methods:SetFont(path, size, flags) self.__font = { path, size, flags } return true end
function Methods:SetTextColor(r, g, b) self.__color = { r, g, b } end
function Methods:SetScale(s) self.__scale = s end
function Methods:SetJustifyH(j) self.__justify = j end

-- The game's English text (the same words the real client uses)
dofile((ADDON_DIR or ".") .. "/tests/strings_enus.lua")

-- Everything defined above that isn't a test control is the game's. An addon
-- may read it and add to its tables, but never replace it.
local TEST = { LOG = 1, ALL_FRAMES = 1, BLOCKED = 1, VIOLATIONS = 1, COMBAT = 1, SECRET_MODE = 1, SECURE = 1,
    STUB_METHODS = 1, STATE = 1, FAKE_TIME = 1, TIMERS = 1, TICKERS = 1, Advance = 1, Secret = 1, newObj = 1,
    ClickButton = 1, ClickTab = 1, WithoutGameText = 1, MENU_OPENED = 1 }
GAME = {}
for k, v in pairs(_G) do
    if not STANDARD[k] and not TEST[k] then GAME[k] = v end
end
for k in pairs(GAME) do rawset(_G, k, nil) end
setmetatable(_G, {
    __index = GAME,
    __newindex = function(t, k, v)
        if GAME[k] ~= nil then
            violation("assigned the game's global " .. tostring(k))
            GAME[k] = v
        else
            rawset(t, k, v)
        end
    end,
})
for _, f in ipairs(ALL_FRAMES) do f.__blizzard = true end

-- Runs fn with none of the game's text available (a missing or odd-language client)
function WithoutGameText(fn)
    local hidden = {}
    for k, v in pairs(GAME) do
        if type(v) == "string" and k ~= "STANDARD_TEXT_FONT" then hidden[k] = v; GAME[k] = nil end
    end
    local ok, err = pcall(fn)
    for k, v in pairs(hidden) do GAME[k] = v end
    if not ok then error(err, 0) end
end
-- Runs fn on a client that has no menus to open
function WithoutMenus(fn)
    local menus = GAME.MenuUtil
    GAME.MenuUtil = nil
    local ok, err = pcall(fn)
    GAME.MenuUtil = menus
    if not ok then error(err, 0) end
end
-- Runs fn on a client that has no timers
function WithoutTimers(fn)
    local timers = GAME.C_Timer
    GAME.C_Timer = nil
    local ok, err = pcall(fn)
    GAME.C_Timer = timers
    if not ok then error(err, 0) end
end
LOADED = true
