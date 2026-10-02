-- Minimal WoW API stub for exercising BattleText Forever outside the game.
-- Methods (CamelCase keys) default to no-ops; lowercase fields read as nil like real frames.

LOG = {}
local function log(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end LOG[#LOG + 1] = table.concat(t, " ") end
print = function(...) log(...) end

ALL_FRAMES = {}
BLOCKED = {}          -- protected actions attempted in combat
COMBAT = false
SECRET_MODE = false

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
function Methods:Show() protectedCheck(self, "Show") self.__shown = true if self.__scripts.OnShow then self.__scripts.OnShow(self) end end
function Methods:Hide() protectedCheck(self, "Hide") self.__shown = false end
function Methods:SetShown(v) if v then self:Show() else self:Hide() end end
function Methods:IsShown() return self.__shown end
function Methods:IsVisible()
    local f = self
    while f do if f.__shown == false then return false end f = f.__parent end
    return true
end
function Methods:SetScript(k, fn) self.__scripts[k] = fn end
function Methods:GetScript(k) return self.__scripts[k] end
function Methods:HookScript(k, fn)
    local old = self.__scripts[k]
    self.__scripts[k] = function(...) if old then old(...) end fn(...) end
end
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
function Methods:SetMinMaxValues(a, b) end
function Methods:RegisterEvent(e) self.__events = self.__events or {} self.__events[e] = true end
function Methods:RegisterUnitEvent(e) self.__events = self.__events or {} self.__events[e] = true end
function Methods:SetAlpha(a) self.__alpha = a end
function Methods:GetFontString() return nil end
function Methods:SetEnabled(v) self.__enabled = v end
function Methods:SetDesaturated(v) self.__desat = v end
function Methods:SetTexture(t) self.__texture = t end
function Methods:StartMoving() protectedCheck(self, "StartMoving") self.__moving = true end
function Methods:StopMovingOrSizing() protectedCheck(self, "StopMovingOrSizing") self.__moving = false end

function CreateFrame(kind, name, parent, template) return newObj(kind, name, parent, template) end
UIParent = newObj("Frame", "UIParent")
Minimap = newObj("Frame", "Minimap")
GameTooltip = newObj("GameTooltip", "GameTooltip")
UISpecialFrames, SlashCmdList = {}, {}
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"

-- Game state the tests set up
STATE = {
    xp = 100, xpMax = 1000,
    pet = false,
    cvars = { enableFloatingCombatText = "1", floatingCombatTextCombatDamage = "1", floatingCombatTextCombatHealing = "1" },
    filteredEvents = false,       -- C_CombatLog.SetFilteredEventsEnabled
    spellIcons = { Claw = 132140, Moonfire = 136096 },
}

FAKE_TIME = 1000
function GetTime() return FAKE_TIME end
function InCombatLockdown() return COMBAT end
function UnitXP() return STATE.xp end
function UnitXPMax() return STATE.xpMax end
function UnitExists(unit) return unit == "pet" and STATE.pet or unit == "player" end
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
    NewTicker = function(_, fn) TICKERS[#TICKERS + 1] = fn end,
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
        for _, f in ipairs(ALL_FRAMES) do
            if f.__scripts and f.__scripts.OnUpdate then f.__scripts.OnUpdate(f, step) end
        end
    end
end

C_CombatLog = {
    SetFilteredEventsEnabled = function(on) STATE.filteredEvents = on end,
    AreFilteredEventsEnabled = function() return STATE.filteredEvents end,
    -- Blizzard only: an addon calling this breaks the game's combat log
    ApplyFilterSettings = function() error("ApplyFilterSettings is only available to the Blizzard UI") end,
}
Enum = { CombatLogMessageOrder = { Newest = 0, Oldest = 1 } }
C_Spell = { GetSpellTexture = function(name) return STATE.spellIcons[name] end }
C_Item = { GetItemIconByID = function(id) return 134000 + id end }

-- The Combat Log window, and the chat tabs
ChatFrame1 = newObj("ScrollingMessageFrame", "ChatFrame1")
ChatFrame2 = newObj("ScrollingMessageFrame", "ChatFrame2")
ChatFrame2.__shown = false
COMBATLOG = ChatFrame2
ChatFrame1Tab = newObj("Button", "ChatFrame1Tab")
ChatFrame2Tab = newObj("Button", "ChatFrame2Tab")
SELECTED_DOCK_FRAME = ChatFrame1

-- The game's text for loot (the combat words use Parse.lua's built-in English)
LOOT_ITEM_SELF = "You receive loot: %s."
LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
LOOT_ITEM_PUSHED_SELF = "You receive item: %s."
LOOT_ITEM_CREATED_SELF = "You create: %s."

Secret = secret   -- tests make hidden values with Secret(123)
function Methods:SetFont(path, size, flags) self.__font = { path, size, flags } return true end
function Methods:SetTextColor(r, g, b) self.__color = { r, g, b } end
function Methods:SetScale(s) self.__scale = s end
function Methods:SetJustifyH(j) self.__justify = j end
