-- Lays out BattleText Forever's frames outside the game and writes them to JSON,
-- so tests/render.py can draw them as images for a visual check.
-- From the repo root:  lua5.1 tests/render.lua && python3 tests/render.py
-- Not shipped (the tests folder is left out of the download).

ADDON_DIR = "."
dofile("tests/wowstub.lua")
local M = STUB_METHODS

---------------------------------------------------------------------------
-- Track layout on the fake frames
---------------------------------------------------------------------------
local baseSetPoint, baseSetSize = M.SetPoint, M.SetSize
function M:SetPoint(p, rel, rp, x, y)
    baseSetPoint(self, p, rel, rp, x, y)
    local a
    if type(rel) == "table" then
        a = { p = p, rel = rel, rp = rp or p, x = x or 0, y = y or 0 }
    elseif type(rel) == "string" then
        a = { p = p, rp = rel, x = rp or 0, y = x or 0 }
    else
        a = { p = p, rp = p, x = rel or 0, y = rp or 0 }
    end
    self.__pts = self.__pts or {}
    for i, old in ipairs(self.__pts) do
        if old.p == p then table.remove(self.__pts, i) break end
    end
    table.insert(self.__pts, a)
end
function M:ClearAllPoints() self.__pts = {} end
function M:SetAllPoints(rel)
    rel = type(rel) == "table" and rel or nil
    self.__pts = { { p = "TOPLEFT", rel = rel, rp = "TOPLEFT", x = 0, y = 0 },
        { p = "BOTTOMRIGHT", rel = rel, rp = "BOTTOMRIGHT", x = 0, y = 0 } }
end
function M:SetSize(w, h) baseSetSize(self, w, h) self.__w, self.__h = w, h end
function M:SetWidth(w) self.__w = w end
function M:SetHeight(h) self.__h = h end
function M:SetColorTexture(r, g, b, a) self.__color = { r, g, b, a or 1 } end
function M:SetTextColor(r, g, b) self.__tcolor = { r, g, b } end
function M:SetJustifyH(j) self.__justify = j end
function M:SetFont(_, size) self.__fsize = size end
function M:SetFontObject(f) self.__font = f and f.__name end
function M:SetScrollChild(ch)
    ch.__pts = { { p = "TOPLEFT", rel = self, rp = "TOPLEFT", x = 0, y = 0 } }
    ch.__scrollOf = self
end
function M:SetWordWrap(v) self.__wrap = v end
function M:CreateFontString(_, _, template)
    local f = newObj("FontString", nil, self)
    f.__text = ""
    f.__font = template
    return f
end
function M:SetFontString(fs) self.__fontString = fs end
function M:CreateTexture(_, layer)
    local t = newObj("Texture", nil, self)
    t.__layer = layer
    return t
end
function M:GetFrameLevel() return self.__frameLevel or 1 end

local FONT_SIZES = { GameFontNormal = 12, GameFontHighlight = 12, GameFontNormalSmall = 10,
    GameFontHighlightSmall = 10, GameFontDisableSmall = 10, GameFontNormalLarge = 16, NumberFontNormal = 12 }
local function FontSize(o) return o.__fsize or FONT_SIZES[o.__font or ""] or 12 end
local function Plain(t)
    t = tostring(t or "")
    t = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "  ")
    return t
end
local function TextWidth(o) return #Plain(o.__text) * FontSize(o) * 0.56 end
function M:GetStringHeight()
    local size = FontSize(self)
    local w = self.__w
    if not w or w <= 0 then return size end
    local lines = math.max(1, math.ceil(TextWidth(self) / w))
    return lines * (size + 2)
end

---------------------------------------------------------------------------
-- Load the addon and log in
---------------------------------------------------------------------------
local ADDON = "BattleTextForever"
local ns = {}
local function load_file(path)
    local f = assert(io.open(path)) local src = f:read("*a") f:close()
    assert(loadstring(src, "@" .. path))(ADDON, ns)
end
load_file("Parse.lua")
load_file("Core.lua")
load_file("Options.lua")
local BT = ns.BT
local function fire(event, ...)
    for _, f in ipairs(ALL_FRAMES) do
        if f.__events and f.__events[event] and f.__scripts.OnEvent then f.__scripts.OnEvent(f, event, ...) end
    end
end
local function tick() for _, fn in ipairs(TICKERS) do fn() end end

---------------------------------------------------------------------------
-- Resolve rectangles (WoW coordinates: y grows upward) and dump them
---------------------------------------------------------------------------
local SW, SH = 1280, 900
local function Resolve(o, cache)
    if o == UIParent or o == nil then return { l = 0, r = SW, t = SH, b = 0 } end
    if cache[o] then return cache[o] end
    cache[o] = { l = 0, r = 0, t = 0, b = 0 }
    local l, r, t, b, cx, cy
    for _, a in ipairs(o.__pts or {}) do
        local rr = Resolve(a.rel or o.__parent, cache)
        local px = a.rp:find("LEFT") and rr.l or a.rp:find("RIGHT") and rr.r or (rr.l + rr.r) / 2
        local py = a.rp:find("TOP") and rr.t or a.rp:find("BOTTOM") and rr.b or (rr.t + rr.b) / 2
        px, py = px + a.x, py + a.y
        if a.p:find("LEFT") then l = px elseif a.p:find("RIGHT") then r = px else cx = px end
        if a.p:find("TOP") then t = py elseif a.p:find("BOTTOM") then b = py else cy = py end
    end
    local w, h = o.__w, o.__h
    if o.__kind == "FontString" then
        w = w or TextWidth(o)
        h = h or o:GetStringHeight()
    end
    w, h = w or 0, h or 0
    if l and r then w = r - l elseif l then r = l + w elseif r then l = r - w elseif cx then l, r = cx - w / 2, cx + w / 2 else l, r = 0, w end
    if t and b then h = t - b elseif t then b = t - h elseif b then t = b + h elseif cy then t, b = cy + h / 2, cy - h / 2 else t, b = h, 0 end
    local rect = { l = l, r = r, t = t, b = b, anchored = o.__pts and #o.__pts > 0 }
    cache[o] = rect
    return rect
end

local function Visible(o, root)
    local f = o
    while f do
        if f.__shown == false then return false end
        if f == root then return true end
        f = f.__parent
    end
    return false
end

local function ScrollClip(o)
    local f = o.__parent
    while f do
        if f.__scrollOf then return f.__scrollOf end
        f = f.__parent
    end
end

local function Esc(s)
    return (tostring(s):gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"))
end
local function Num(n) return string.format("%.1f", n) end

-- Frame level: set explicitly, or one above the parent frame. Textures and text
-- draw at their frame's level.
function FrameLevel(o)
    if o.__kind == "Texture" or o.__kind == "FontString" then return FrameLevel(o.__parent) end
    if not o or o == UIParent then return 0 end
    if o.__frameLevel then return o.__frameLevel end
    return (o.__parent and FrameLevel(o.__parent) or 0) + 1
end

local out = {}
local function Dump(name, root, unclip)
    local cache = {}
    local items = {}
    for i, o in ipairs(ALL_FRAMES) do
        if o ~= root and Visible(o, root) and o.__pts and #o.__pts > 0 then
            local rc = Resolve(o, cache)
            local fields = {
                '"i":' .. i, '"kind":"' .. o.__kind .. '"',
                '"l":' .. Num(rc.l), '"r":' .. Num(rc.r), '"t":' .. Num(SH - rc.t), '"b":' .. Num(SH - rc.b),
            }
            if o.__template then fields[#fields + 1] = '"tmpl":"' .. o.__template .. '"' end
            if o.__layer then fields[#fields + 1] = '"layer":"' .. o.__layer .. '"' end
            if o.__w and o.__kind == "FontString" then fields[#fields + 1] = '"fixedw":true' end
            fields[#fields + 1] = '"fl":' .. FrameLevel(o)
            for pi, po in ipairs(ALL_FRAMES) do
                if po == o.__parent then fields[#fields + 1] = '"p":' .. pi break end
            end
            if o.__color then fields[#fields + 1] = '"color":[' .. table.concat(o.__color, ",") .. "]" end
            if o.__tcolor then fields[#fields + 1] = '"tcolor":[' .. table.concat(o.__tcolor, ",") .. "]" end
            if o.__text and o.__text ~= "" then fields[#fields + 1] = '"text":"' .. Esc(Plain(o.__text)) .. '"' end
            if o.__font then fields[#fields + 1] = '"font":"' .. o.__font .. '"' end
            fields[#fields + 1] = '"size":' .. FontSize(o)
            if o.__justify then fields[#fields + 1] = '"justify":"' .. o.__justify .. '"' end
            if o.__checked then fields[#fields + 1] = '"checked":true' end
            if o.__texture then fields[#fields + 1] = '"texture":"' .. Esc(o.__texture) .. '"' end
            if o.__desat then fields[#fields + 1] = '"desat":true' end
            if o.__alpha then fields[#fields + 1] = '"alpha":' .. tostring(o.__alpha) end
            local clip = not unclip and ScrollClip(o)
            if clip then
                local cr = Resolve(clip, cache)
                fields[#fields + 1] = '"clip":[' .. Num(cr.l) .. "," .. Num(SH - cr.t) .. "," .. Num(cr.r) .. "," .. Num(SH - cr.b) .. "]"
            end
            items[#items + 1] = "{" .. table.concat(fields, ",") .. "}"
        end
    end
    local rc = Resolve(root, cache)
    out[#out + 1] = '{"name":"' .. name .. '","frame":[' .. Num(rc.l) .. "," .. Num(SH - rc.t) .. ","
        .. Num(rc.r) .. "," .. Num(SH - rc.b) .. '],"items":[' .. table.concat(items, ",") .. "]}"
end

---------------------------------------------------------------------------
-- Scenarios
---------------------------------------------------------------------------
fire("ADDON_LOADED", ADDON)
fire("PLAYER_LOGIN")
fire("PLAYER_ENTERING_WORLD")
BT.db.icons = false   -- the drawing has no icon art
local function log(line) fire("COMBAT_LOG_MESSAGE", line, 1, 1, 1, 0) end

-- A fight in progress: lines at different points of their scroll
BT.started = true
BT:UpdateStartButton()
log("Your Melee hit Boar 27 Physical.")
fire("UNIT_COMBAT", "player", "WOUND", "", 23, 1)
Advance(0.5)
log("Your Claw hit Boar 50 Physical. (1 Blocked)")
fire("UNIT_COMBAT", "player", "DODGE", "", 0, 1)
Advance(0.5)
log("Your Moonfire hit Boar 64 Arcane.")
Advance(0.4)
fire("UNIT_COMBAT", "player", "WOUND", "", 31, 1)
log("Your Rejuvenation healed You 61 Nature.")
Advance(0.5)
log("Your Melee missed Boar. Dodge")
log("Your Claw hit Boar 112 Physical. (Critical)")
fire("UNIT_COMBAT", "player", "WOUND", "CRITICAL", 58, 1)
STATE.xp = 203
fire("PLAYER_XP_UPDATE")
Advance(0.3)
log("Your Melee hit Boar 26 Physical.")
log("You killed Boar.")
Advance(0.25)
Dump("combat", UIParent)

-- Areas unlocked for moving, and the Start button after login
Advance(8)
BT.started = nil
BT.startButton.wanted = nil
BT:UpdateStartButton()
BT:SetLocked(false)
Dump("unlocked", UIParent)
BT:SetLocked(true)
BT.started = true
BT:UpdateStartButton()

BT:OpenConfig()
Dump("options", BT.config)

local f = assert(io.open(arg and arg[1] or "tests/render-out.json", "w"))
f:write("[" .. table.concat(out, ",\n") .. "]")
f:close()
io.write("wrote " .. #out .. " views\n")
