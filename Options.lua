-- BattleText Forever: options window (/btf), in the shared look (Theme.lua).
-- Tabs down the left: General, then how the text looks (Text, Scrolling), then
-- one tab per text area (Outgoing, Incoming, Healing, Notifications).

local ADDON, ns = ...
local BT = ns.BT
local T = ns.Theme
local C, Text, FlatButton, Card = T.C, T.Text, T.FlatButton, T.Card

local PAGE_W = T.WINDOW.PAGE_W
local COL2 = 270   -- the second column of a card

local refreshers = {}
local function AddRefresher(fn) table.insert(refreshers, fn) end

-- A switch bound to a setting. "locked" reads as "Move the text areas", so it's turned round.
local function Setting(parent, text, x, y, key, tip)
    local sw = T.LabeledSwitch(parent, text, x, y)
    sw.key = key
    sw:SetScript("OnClick", function(self)
        self:SetOn(not self:IsOn())
        if key == "locked" then
            BT:SetLocked(not self:IsOn())
        else
            BT.db[key] = self:IsOn()
            BT:ApplySettings()
        end
    end)
    if tip then T.Tooltip(sw, text, tip) end
    AddRefresher(function()
        local v = BT.db[key]
        if key == "locked" then v = not v end
        sw:SetOn(v and true or false)
    end)
    return sw
end

local function Slider(parent, text, x, y, key, min, max, suffix, step)
    local s = T.Slider(parent, text, x, y, 244,
        function() return BT.db[key] end,
        function(v) BT.db[key] = v BT:ApplySettings() end, min, max, suffix, step)
    s.label, s.key = text, key
    AddRefresher(s.Refresh)
    return s
end

local function Dropdown(parent, x, y, width, keys, labels, key, choose)
    local d = T.Dropdown(parent, width, keys, labels, function() return BT.db[key] end, choose)
    d:SetPoint("TOPLEFT", x, y)
    d.key = key
    AddRefresher(d.Refresh)
    return d
end

-- The two switches the combat tabs share
local function IconsAndNames(card, y, section, what)
    Setting(card, "Icons", 12, y, section .. "Icons", "Show the spell's icon beside " .. what .. ".")
    Setting(card, "Names", COL2, y, section .. "Names", "Show the spell's name beside " .. what .. ".")
end

-- Each area's own text size and opacity
local function AreaLook(p, y, prefix)
    local card = Card(p, "This area", 0, y, PAGE_W, 84)
    Slider(card, "Text size", 12, -30, prefix .. "Size", 50, 200, "%", 5)
    Slider(card, "Opacity", COL2, -30, prefix .. "Alpha", 10, 100, "%", 5)
end

-- A color square that opens the game's color picker
local function Swatch(parent, text, x, y, key)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(30, 16)
    b:SetPoint("TOPLEFT", x, y)
    b.fill = T.Fill(b, { 1, 1, 1, 1 }, "ARTWORK")
    T.Border(b, C.edge)
    b.label = Text(parent, text, "GameFontHighlight")
    b.label:SetPoint("TOPLEFT", b, "TOPRIGHT", 8, 1)
    b.key = key
    local function paint()
        local c = BT.TEXT_COLORS[key]
        b.fill:SetColorTexture(c[1], c[2], c[3], 1)
    end
    b:SetScript("OnClick", function()
        local picker = ColorPickerFrame
        if not (picker and picker.SetupColorPickerAndShow) then return end
        local c = BT.TEXT_COLORS[key]
        local before = BT.db.colors[key]
        picker:SetupColorPickerAndShow({
            r = c[1], g = c[2], b = c[3], hasOpacity = false,
            swatchFunc = function()
                local r, g, bl = picker:GetColorRGB()
                BT:SetColor(key, r, g, bl)
                paint()
            end,
            cancelFunc = function()
                if before then BT:SetColor(key, before[1], before[2], before[3]) else BT:SetColor(key) end
                paint()
            end,
        })
    end)
    T.Tooltip(b, text, "Click to pick a color.")
    AddRefresher(paint)
    return b
end

function BT:RefreshConfig()
    if not self.config then return end
    for _, fn in ipairs(refreshers) do fn() end
end

---------------------------------------------------------------------------
-- The pages. refs collects the widgets the window keeps a name for.
---------------------------------------------------------------------------
local function BuildGeneral(p, refs)
    local card = Card(p, "BattleText", 0, 0, PAGE_W, 150)
    Setting(card, "Show BattleText", 12, -30, "enabled")
    Setting(card, "Move the text areas", COL2, -30, "locked",
        "Shows a box for each text area. Drag the boxes where you want them, then turn this off. "
        .. "Closing the options locks them again.")
    Setting(card, "Hide the game's own numbers", 12, -56, "hideBlizzard",
        "Turns off the game's floating combat text so numbers aren't shown twice. Turn it off to bring them back.")
    Setting(card, "Minimap button", COL2, -56, "minimap")
    Setting(card, "Remind me to click Start", 12, -82, "startReminder",
        "Ten seconds after you log in, a line in chat reminds you to click Start BattleText if you haven't yet.")
    local own = T.LabeledSwitch(card, "Settings for this character only", COL2, -82)
    own:SetScript("OnClick", function(self)
        self:SetOn(not self:IsOn())
        BT:SetOwnSettings(self:IsOn())
    end)
    T.Tooltip(own, "Settings for this character only",
        "On: this character keeps its own settings, starting from a copy of the shared ones. "
        .. "Off: it uses the settings every character shares.")
    AddRefresher(function() own:SetOn(BT:OwnSettings()) end)
    refs.ownSwitch = own
    local sample = FlatButton(card, "Show sample text", 140)
    sample:SetPoint("TOPLEFT", 12, -114)
    sample:SetScript("OnClick", function() BT:Test() end)
    local reset = FlatButton(card, "Reset positions", 120)
    reset:SetPoint("LEFT", sample, "RIGHT", 8, 0)
    reset:SetScript("OnClick", function() BT:ResetPositions() end)
    refs.sampleButton, refs.resetButton = sample, reset

    local know = Card(p, "Good to know", 0, -160, PAGE_W, 150)
    T.Note(know, "Your hits are read from the unit you hit: your target, and the mobs attacking you or your pet. "
        .. "Turn on enemy nameplates for the ones you aren't targeting.\n\n"
        .. "The game doesn't say whose hit it was: alone, your pet's hits show as yours.\n\n"
        .. "Click \"Start BattleText\" once after you log in. It lets BattleText name the ticks of your bleeds, "
        .. "and in a group it leaves other people's hits out.", 12, -34, PAGE_W - 24)
end

local function BuildText(p, refs)
    local card = Card(p, "Font", 0, 0, PAGE_W, 130)
    local fontKeys, outlineKeys, outlineNames = {}, {}, {}
    for _, f in ipairs(BT.FONTS) do fontKeys[#fontKeys + 1] = f.name end
    for _, o in ipairs(BT.OUTLINES) do
        outlineKeys[#outlineKeys + 1] = o.flags
        outlineNames[o.flags] = o.name
    end
    local function outlineName(flags) return outlineNames[flags] or outlineNames.OUTLINE end

    T.RowLabel(card, "Font", 12, -30)
    refs.fontDropdown = Dropdown(card, 140, -30, 220, fontKeys, function(k) return k end, "font",
        function(name) BT:SetFont(name) end)
    refs.fontDropdown.menuScroll = 20 * 12   -- twelve rows, then it scrolls
    T.RowLabel(card, "Outline", 12, -60)
    refs.outlineDropdown = Dropdown(card, 140, -60, 220, outlineKeys, outlineName, "outline",
        function(flags) BT:SetOutline("outline", flags) end)
    T.RowLabel(card, "Crit outline", 12, -90)
    refs.critOutlineDropdown = Dropdown(card, 140, -90, 220, outlineKeys, outlineName, "critOutline",
        function(flags) BT:SetOutline("critOutline", flags) end)

    local size = Card(p, "Size", 0, -140, PAGE_W, 112)
    Slider(size, "Text size", 12, -30, "fontSize", 10, 40)
    Slider(size, "Crit size", COL2, -30, "critScale", 100, 250, "%", 10)
    Setting(size, "Short numbers", 12, -82, "shortNumbers", "Big numbers in short: 12,345 shows as 12.3k, 1,234,567 as 1.2m.")
end

local function BuildScrolling(p)
    local card = Card(p, "Scrolling", 0, 0, PAGE_W, 150)
    Setting(card, "Curved scrolling", 12, -30, "curved", "Lines bow outward as they scroll. Turn off for straight lines.")
    Setting(card, "Scroll upward", COL2, -30, "scrollUp",
        "Lines start at the bottom of their area and move up. Turn off to scroll down.")
    Setting(card, "Crits pop and hold", 12, -56, "sticky",
        "Critical hits jump out and stay in place for a moment instead of scrolling.")
    Setting(card, "Add up rapid hits", COL2, -56, "merge",
        "Hits from the same spell that land together are shown as one total, like \"Swipe 150 (x3)\".")
    Slider(card, "Scroll time", 12, -90, "scrollTime", 1, 6, " sec")
    Slider(card, "Scroll distance", COL2, -90, "height", 100, 500, "", 10)
end

local function BuildOutgoing(p)
    local card = Card(p, "What you do", 0, 0, PAGE_W, 170)
    Setting(card, "Damage", 12, -30, "outDamage")
    Setting(card, "Misses", COL2, -30, "outMisses", "Your attacks that miss or are dodged, parried, blocked or resisted.")
    Setting(card, "Pet", 12, -56, "outPet",
        "Your pet's hits, marked (Pet). This only works when the game lets BattleText read its combat lines; "
        .. "when it doesn't, your pet's hits can't be told from yours and show with them.")
    Setting(card, "Damage shields", COL2, -56, "outShields",
        "What your damage shields do to whoever hits you: buffs like Thorns, Lightning Shield and Retribution Aura "
        .. "(learned from their first two hits), and gear that stings back.")
    IconsAndNames(card, -82, "out", "your hits and misses")
    Slider(card, "Hide hits below", 12, -116, "minDamage", 0, 500, "", 5)
    AreaLook(p, -180, "out")
end

local function BuildIncoming(p)
    local card = Card(p, "What happens to you", 0, 0, PAGE_W, 116)
    Setting(card, "Damage", 12, -30, "inDamage")
    Setting(card, "Avoids", COL2, -30, "inMisses", "Attacks you dodge, parry, block or resist.")
    Setting(card, "Power gains", 12, -56, "inPower", "Mana, rage and energy you gain.")
    IconsAndNames(card, -82, "in", "spells that hit you or that you avoid (when the game says which)")
    AreaLook(p, -126, "in")
end

local function BuildHealing(p)
    local card = Card(p, "Heals", 0, 0, PAGE_W, 196)
    Setting(card, "Own area for heals", 12, -30, "healArea",
        "Heals scroll in their own area, under your character. Turn off to show them with damage: "
        .. "heals you get on the left, heals you do on the right.")
    Setting(card, "Show overhealing", COL2, -30, "healOver",
        "The grey \"(40 over)\" after a heal. Only when the game lets BattleText read its combat lines.")
    Setting(card, "Heals you get", 12, -56, "inHeals")
    Setting(card, "Heals you do", COL2, -56, "outHeals")
    IconsAndNames(card, -82, "heal", "heals")
    Setting(card, "Show who you healed", 12, -108, "healWho",
        "The name of the player you healed, after the number. Only when the game lets BattleText read it.")
    Slider(card, "Hide heals below", 12, -142, "minHeal", 0, 500, "", 5)
    AreaLook(p, -206, "heal")
end

local function BuildNotifications(p)
    local card = Card(p, "Notifications", 0, 0, PAGE_W, 168)
    Setting(card, "Combat", 12, -30, "nCombat", "Entering and leaving combat.")
    Setting(card, "Killing blows", COL2, -30, "nKill",
        "Only when the game lets BattleText read its combat lines (it often hides them).")
    Setting(card, "Experience", 12, -56, "nXP")
    Setting(card, "Reputation", COL2, -56, "nRep")
    Setting(card, "Honor", 12, -82, "nHonor")
    Setting(card, "Loot", COL2, -82, "nLoot")
    Setting(card, "Money", 12, -108, "nMoney")
    Setting(card, "Skill ups", COL2, -108, "nSkill")
    Setting(card, "Icons", 12, -134, "nIcons", "Show the icon beside loot and skill ups (professions like First Aid).")
    AreaLook(p, -178, "n")
end

local function BuildColors(p)
    local rows = math.ceil(#BT.COLOR_CHOICES / 2)
    local card = Card(p, "Colors", 0, 0, PAGE_W, 40 + rows * 26 + 34)
    for i, choice in ipairs(BT.COLOR_CHOICES) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        Swatch(card, choice[2], col == 0 and 12 or COL2, -30 - row * 26, choice[1])
    end
    local reset = FlatButton(card, "Reset colors", 120)
    reset:SetPoint("TOPLEFT", 12, -36 - rows * 26)
    reset:SetScript("OnClick", function()
        wipe(BT.db.colors)
        BT:ApplyColors()
        BT:RefreshConfig()
    end)
    T.Note(p, "Spells that do Holy, Fire, Nature, Frost, Shadow or Arcane damage keep their school's color.",
        0, -(40 + rows * 26 + 44), PAGE_W)
end

-- Tab icons are the game's own icon files
local TABS = {
    { key = "general",  label = "General",       icon = "Interface\\Icons\\INV_Misc_Gear_01",                build = BuildGeneral },
    { key = "text",     label = "Text",          icon = "Interface\\Icons\\INV_Misc_Note_01",                build = BuildText },
    { key = "scroll",   label = "Scrolling",     icon = "Interface\\Icons\\INV_Misc_Spyglass_03",            build = BuildScrolling },
    { key = "outgoing", label = "Outgoing",      icon = "Interface\\Icons\\INV_Sword_04",                    build = BuildOutgoing },
    { key = "incoming", label = "Incoming",      icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance", build = BuildIncoming },
    { key = "healing",  label = "Healing",       icon = "Interface\\Icons\\Spell_Holy_Heal",                 build = BuildHealing },
    { key = "notify",   label = "Notifications", icon = "Interface\\Icons\\INV_Misc_Bag_08",                 build = BuildNotifications },
    { key = "colors",   label = "Colors",       icon = "Interface\\Icons\\INV_Misc_Gem_Variety_01",         build = BuildColors },
}
BT.CONFIG_TABS = TABS

function BT:BuildConfig()
    local refs = {}
    local tabs = {}
    for _, t in ipairs(TABS) do
        tabs[#tabs + 1] = { key = t.key, label = t.label, icon = t.icon, build = function(body) t.build(body, refs) end }
    end
    local win = T.Window({
        name = "BattleTextForeverOptions",
        tabs = tabs,
        hint = "/btf to open  -  /btf test for sample text",
        version = function()
            local get = C_AddOns and C_AddOns.GetAddOnMetadata
            local v = get and get(ADDON, "Version")
            if type(v) == "string" and not v:find("@", 1, true) then return (v:gsub("^v", "")) end
        end,
        -- Closing the window is the end of moving things about: the text areas lock
        -- again (and "Move the text areas" is off the next time it opens)
        onHide = function()
            if not BT.db.locked then BT:SetLocked(true) end
        end,
    })
    for k, v in pairs(refs) do win[k] = v end
    self.config = win
end

function BT:OpenConfig()
    if not self.config then self:BuildConfig() end
    if self.config:IsShown() then
        self.config:Hide()
    else
        self:RefreshConfig()
        self.config:Show()
    end
end

---------------------------------------------------------------------------
-- /btf copy: the lines recorded by /btf debug, in a box they can be copied
-- from (chat can't be copied)
---------------------------------------------------------------------------
local COPY_W, COPY_H, COPY_HEADER = 640, 380, 40

function BT:OpenCopyWindow()
    local f = self.copyWindow
    if not f then
        f = CreateFrame("Frame", "BattleTextForeverCopy", UIParent)
        f:SetSize(COPY_W, COPY_H)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        f:Hide()
        table.insert(UISpecialFrames, "BattleTextForeverCopy")   -- Escape closes it
        T.Fill(f, C.win)
        T.Border(f, C.edge)

        local header = CreateFrame("Frame", nil, f)
        header:SetPoint("TOPLEFT", 1, -1)
        header:SetPoint("TOPRIGHT", -1, -1)
        header:SetHeight(COPY_HEADER)
        local hbg = header:CreateTexture(nil, "BACKGROUND")
        hbg:SetAllPoints()
        T.HeaderGradient(hbg)
        local logo = header:CreateTexture(nil, "ARTWORK")
        logo:SetSize(26, 26)
        logo:SetPoint("LEFT", 10, 0)
        logo:SetTexture(T.LOGO)
        local title = Text(header, "Combat lines: press Ctrl+C to copy, then paste into your report",
            "GameFontNormal", C.title)
        title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
        local close = FlatButton(header, "X", 24, 24)
        close:SetPoint("RIGHT", -8, 0)
        close:SetScript("OnClick", function() f:Hide() end)

        local box = CreateFrame("Frame", nil, f)
        box:SetPoint("TOPLEFT", 12, -(COPY_HEADER + 10))
        box:SetPoint("BOTTOMRIGHT", -12, 12)
        T.Fill(box, C.field)
        T.Border(box, C.fieldEdge)
        local scroll = T.ScrollArea(box, COPY_H - COPY_HEADER - 22)
        local edit = CreateFrame("EditBox", nil, scroll.child)
        edit:SetPoint("TOPLEFT", 6, -6)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("ChatFontNormal")
        edit:SetWidth(COPY_W - 60)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        f.edit, f.scroll = edit, scroll
        self.copyWindow = f
    end
    local text = "Nothing recorded yet. Type /btf debug, fight for a moment, then /btf copy."
    local count = 1
    if self.recorded and #self.recorded > 0 then
        -- "|" doubled, so the links show as text instead of turning into links
        text = (table.concat(self.recorded, "\n"):gsub("|", "||"))
        count = #self.recorded
    end
    f.edit:SetText(text)
    -- Long lines wrap, so leave room for about two rows each
    local height = count * 28 + 12
    f.edit:SetHeight(height)
    f.scroll:SetContent(COPY_W - 48, height)
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end
