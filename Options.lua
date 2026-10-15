-- BattleText Forever: options window (/btf), in the shared look (Theme.lua).
-- Tabs down the left: General, then how the text looks (Text, Motion), then
-- one tab per text area (Outgoing, Incoming, Healing, Notifications), then Colors.
--
-- Layout rules: two columns (12 and COL2); rows 26 apart; a dropdown after a
-- row label starts at DROP_X; a note explaining a card is its last line, full
-- width. A control that does nothing with the other settings as they are is
-- greyed out (enabledIf), and its tooltip still shows.

local ADDON, ns = ...
local BT = ns.BT
local T = ns.Theme
local C, Text, FlatButton, Card = T.C, T.Text, T.FlatButton, T.Card

local PAGE_W = T.WINDOW.PAGE_W
local COL2 = 270     -- the second column of a card
local DROP_X = 110   -- where a dropdown starts, after its row label

local refreshers = {}
local function AddRefresher(fn) table.insert(refreshers, fn) end

local function Print(msg) BT.Print(msg) end

-- Greys a control out while enabledIf() says it does nothing
local function DependsOn(widget, enabledIf)
    if enabledIf then AddRefresher(function() widget:SetDisabled(not enabledIf()) end) end
end

-- A note at the bottom of a card, full width
local function CardNote(card, text, y)
    return T.Note(card, text, 12, y, PAGE_W - 24)
end

-- A switch bound to a setting. "locked" reads as "Move the text areas", so it's turned round.
local function Setting(parent, text, x, y, key, tip, enabledIf)
    local sw = T.LabeledSwitch(parent, text, x, y)
    sw.key = key
    sw:SetScript("OnClick", function(self)
        if self.disabled then return end
        self:SetOn(not self:IsOn())
        if key == "locked" then
            BT:SetLocked(not self:IsOn())
        else
            BT.db[key] = self:IsOn()
            BT:ApplySettings()
            if key == "hideBlizzard" and InCombatLockdown() then
                Print("the game's own numbers change when this fight ends.")
            end
        end
        BT:RefreshConfig()   -- (other controls may depend on it)
    end)
    if tip then T.Tooltip(sw, text, tip) end
    AddRefresher(function()
        local v = BT.db[key]
        if key == "locked" then v = not v end
        sw:SetOn(v and true or false)
    end)
    DependsOn(sw, enabledIf)
    return sw
end

-- A slider bound to a number setting, over its range in BT.RANGES.
--   o.suffix, o.step, o.fmt  how the value reads   o.zero  what 0 reads as ("Off")
--   o.tip  tooltip   o.enabledIf  greyed out unless it says yes
local function Slider(parent, text, x, y, key, o)
    o = o or {}
    local range = BT.RANGES[key]
    local s = T.Slider(parent, text, x, y, 244,
        function() return BT.db[key] end,
        function(v) BT.db[key] = v BT:ApplyAreas() end,   -- (the areas' sizes; the rest is read as lines come)
        range[1], range[2], o.suffix, o.step, o.fmt, o.zero)
    s.label, s.key = text, key
    if o.tip then T.Tooltip(s, text, o.tip) end
    AddRefresher(s.Refresh)
    DependsOn(s, o.enabledIf)
    return s
end

local function Dropdown(parent, x, y, width, keys, labels, key, choose, tip, enabledIf)
    local d = T.Dropdown(parent, width, keys, labels, function() return BT.db[key] end, function(k)
        choose(k)
        BT:RefreshConfig()
    end)
    d:SetPoint("TOPLEFT", x, y)
    d.key = key
    if tip then T.Tooltip(d, nil, tip) end
    AddRefresher(d.Refresh)
    DependsOn(d, enabledIf)
    return d
end

local function Either(...)
    local keys = { ... }
    return function()
        for _, k in ipairs(keys) do if BT.db[k] then return true end end
        return false
    end
end

-- The two switches the combat tabs share
local function IconsAndNames(card, y, section, what, enabledIf)
    Setting(card, "Icons", 12, y, section .. "Icons", "Shows the spell's icon beside " .. what .. ".", enabledIf)
    Setting(card, "Names", COL2, y, section .. "Names", "Shows the spell's name beside " .. what .. ".", enabledIf)
end

-- Each area's own text size, opacity and movement. curved: the side areas, whose
-- lines can bow outward. enabledIf/offNote: when the area isn't in use, and why.
local function AreaLook(p, y, prefix, curved, enabledIf, offNote)
    local card = Card(p, "Appearance", 0, y, PAGE_W, curved and 142 or 116)
    Slider(card, "Size", 12, -30, prefix .. "Size", { suffix = "%", step = 5, enabledIf = enabledIf,
        tip = "This area's text, as a percent of the text size on the Text tab." })
    Slider(card, "Opacity", COL2, -30, prefix .. "Alpha", { suffix = "%", step = 5, enabledIf = enabledIf,
        tip = "How see-through this area's text is. 100% is solid." })
    local keys = {}
    for _, st in ipairs(BT.STYLES) do keys[#keys + 1] = st.key end
    T.RowLabel(card, "Movement", 12, -82)
    local style = prefix .. "Style"
    local d = Dropdown(card, DROP_X, -82, 150, keys, function(k) return BT:StyleName(k) end, style,
        function(k) BT.db[style] = k end,
        "Scroll: lines move up or down the area, one after another. Pop: each one jumps out somewhere in the area "
        .. "and fades. Fountain: thrown up and falling to the side. Horizontal: they slide sideways, away from the "
        .. "middle. Crits that stay in place (Motion tab) stay put whatever this is.", enabledIf)
    local function scrolling()
        return (not enabledIf or enabledIf()) and BT:AreaStyle({ def = { prefix = prefix } }) == "scroll"
    end
    Setting(card, "Scroll upward", COL2, -84, prefix .. "ScrollUp",
        "Lines start at the bottom and move up. Off: they scroll down. Only with Scroll movement.", scrolling)
    if curved then
        Setting(card, "Curved scrolling", COL2, -110, prefix .. "Curved",
            "Lines bow outward as they scroll. Off: straight lines. Only with Scroll movement.", scrolling)
    end
    if offNote then
        local note = T.Note(card, offNote, 0, 0)
        note:ClearAllPoints()
        note:SetPoint("TOPRIGHT", -12, -10)
        AddRefresher(function() note:SetShown(not enabledIf()) end)
    end
    return d
end

-- A color square that opens the game's color picker (its label works the same)
local function Swatch(parent, text, x, y, key)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(30, 16)
    b:SetPoint("TOPLEFT", x, y)
    b.fill = T.Fill(b, { 1, 1, 1, 1 }, "ARTWORK")
    T.Border(b, C.edge)
    b.label = Text(parent, text, "GameFontHighlight")
    b.label:SetPoint("TOPLEFT", b, "TOPRIGHT", 8, 1)
    T.ClickableLabel(b, b.label)
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
-- "Are you sure?": a small window in the same look, over the options
---------------------------------------------------------------------------
function BT:Confirm(text, yesLabel, onYes)
    local f = self.confirmWindow
    if not f then
        f = CreateFrame("Frame", "BattleTextForeverConfirm", UIParent)
        f:SetSize(380, 130)
        f:SetPoint("CENTER", 0, 80)
        f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true)
        f:EnableMouse(true)
        f:Hide()
        table.insert(UISpecialFrames, "BattleTextForeverConfirm")   -- Escape is Cancel
        T.Fill(f, C.win)
        T.Border(f, C.edge)
        f.text = Text(f, "", "GameFontHighlight")
        f.text:SetPoint("TOPLEFT", 16, -16)
        f.text:SetWidth(348)
        f.text:SetWordWrap(true)
        f.text:SetJustifyH("LEFT")
        f.no = FlatButton(f, "Cancel", 100)
        f.no:SetPoint("BOTTOMRIGHT", -16, 14)
        f.no:SetScript("OnClick", function() f:Hide() end)
        f.yes = FlatButton(f, "", 120)
        f.yes:SetPoint("RIGHT", f.no, "LEFT", -8, 0)
        self.confirmWindow = f
    end
    f.text:SetText(text)
    f.yes:SetText(yesLabel)
    f.yes:SetScript("OnClick", function()
        f:Hide()
        onYes()
    end)
    f:Show()
    return f
end

---------------------------------------------------------------------------
-- The pages. refs collects the widgets the window keeps a name for.
---------------------------------------------------------------------------
local function BuildGeneral(p, refs)
    local card = Card(p, "Basics", 0, 0, PAGE_W, 150)
    Setting(card, "Show BattleText", 12, -30, "enabled",
        "Turns all of BattleText's text on or off (also /btf on and /btf off).")
    Setting(card, "Move the text areas", COL2, -30, "locked",
        "Shows a box for each text area. Drag the boxes where you want them, then turn this off. "
        .. "Closing the options locks them again.")
    Setting(card, "Hide the game's own numbers", 12, -56, "hideBlizzard",
        "Turns off the game's floating combat text so numbers aren't shown twice. Turn it off to bring them back. "
        .. "During a fight, the change waits until the fight ends.")
    Setting(card, "Minimap button", COL2, -56, "minimap",
        "The BattleText button on the minimap: left-click opens the options, right-click shows sample text.")
    Setting(card, "Remind me to click Start", 12, -82, "startReminder",
        "Ten seconds after you log in, a line in chat reminds you to click Start BattleText if you haven't yet.")
    local own = T.LabeledSwitch(card, "Settings for this character only", COL2, -82)
    own:SetScript("OnClick", function(self)
        self:SetOn(not self:IsOn())
        BT:SetOwnSettings(self:IsOn())
    end)
    T.Tooltip(own, "Settings for this character only",
        "On: this character has its own settings. The first time, they start as a copy of the shared ones. "
        .. "Off: it uses the settings every character shares, and keeps its own for when you turn this back on.")
    AddRefresher(function() own:SetOn(BT:OwnSettings()) end)
    refs.ownSwitch = own
    local sample = FlatButton(card, "Show sample text", 140)
    sample:SetPoint("TOPLEFT", 12, -114)
    sample:SetScript("OnClick", function() BT:Test() end)
    T.Tooltip(sample, nil, "A few sample lines in every area, to see the look and where the areas are.")
    local reset = FlatButton(card, "Reset positions", 120)
    reset:SetPoint("LEFT", sample, "RIGHT", 8, 0)
    reset:SetScript("OnClick", function()
        BT:Confirm("Move all four text areas back to where they started?", "Reset positions",
            function() BT:ResetPositions() end)
    end)
    refs.sampleButton, refs.resetButton = sample, reset

    local know = Card(p, "Good to know", 0, -160, PAGE_W, 130)
    local text = Text(know, "Your hits are read from the unit you hit: your target, and the mobs attacking you or your "
        .. "pet. Turn on enemy nameplates for the ones you aren't targeting.\n\n"
        .. "The game doesn't say whose hit it was: alone, your pet's hits show as yours.\n\n"
        .. "Click \"Start BattleText\" once after you log in. It lets BattleText name the ticks of your bleeds, "
        .. "and in a group it leaves other people's hits out.", "GameFontHighlightSmall", C.muted)
    text:SetPoint("TOPLEFT", 12, -34)
    text:SetWidth(PAGE_W - 24)
    text:SetWordWrap(true)
    text:SetJustifyH("LEFT")

    local share = Card(p, "Share settings", 0, -300, PAGE_W, 90)
    local export = FlatButton(share, "Export", 90)
    export:SetPoint("TOPLEFT", 12, -28)
    export:SetScript("OnClick", function() BT:OpenShareWindow("export") end)
    local import = FlatButton(share, "Import", 90)
    import:SetPoint("LEFT", export, "RIGHT", 8, 0)
    import:SetScript("OnClick", function() BT:OpenShareWindow("import") end)
    CardNote(share, "Export: your settings as a line of text to copy. Import: paste someone else's to use them "
        .. "(your text areas stay where they are unless you choose).", -58)
    refs.exportButton, refs.importButton = export, import
end

local function BuildText(p, refs)
    local card = Card(p, "Font and outline", 0, 0, PAGE_W, 124)
    local fontKeys, outlineKeys, outlineNames = {}, {}, {}
    for _, f in ipairs(BT.FONTS) do fontKeys[#fontKeys + 1] = f.name end
    for _, o in ipairs(BT.OUTLINES) do
        outlineKeys[#outlineKeys + 1] = o.flags
        outlineNames[o.flags] = o.name
    end
    local function outlineName(flags) return outlineNames[flags] or outlineNames.OUTLINE end
    local outlineTip = "None, a thin or thick dark edge round the letters, or a drop shadow instead. "
        .. "Picking one shows a sample line."

    T.RowLabel(card, "Font", 12, -30)
    refs.fontDropdown = Dropdown(card, DROP_X, -30, 220, fontKeys, function(k) return k end, "font",
        function(name) BT:SetFont(name) end, "The letters of every line. Picking one shows a sample line in it.")
    refs.fontDropdown.menuScroll = 20 * 12   -- twelve rows, then it scrolls
    T.RowLabel(card, "Outline", 12, -60)
    refs.outlineDropdown = Dropdown(card, DROP_X, -60, 220, outlineKeys, outlineName, "outline",
        function(flags) BT:SetOutline("outline", flags) end, "Normal lines: " .. outlineTip)
    T.RowLabel(card, "Crit outline", 12, -90)
    refs.critOutlineDropdown = Dropdown(card, DROP_X, -90, 220, outlineKeys, outlineName, "critOutline",
        function(flags) BT:SetOutline("critOutline", flags) end, "Crits: " .. outlineTip)

    local size = Card(p, "Size", 0, -134, PAGE_W, 112)
    Slider(size, "Text size", 12, -30, "fontSize",
        { tip = "The size of normal lines. Each area can make its own bigger or smaller (Appearance, on its tab)." })
    Slider(size, "Crit size", COL2, -30, "critScale", { suffix = "%", step = 10,
        tip = "Crits, as a percent of the text size." })
    Setting(size, "Short numbers", 12, -82, "shortNumbers",
        "Big numbers in short: 12,345 shows as 12.3k, 1,234,567 as 1.2m. Below 10,000 they stay as they are.")
    Setting(size, "Size by hit", COL2, -82, "sizeByHit",
        "Each area compares a number with its recent ones: a bigger hit or heal shows bigger (up to 1.5 times), "
        .. "a smaller one smaller (down to three quarters). A number the game hides keeps the usual size.")
end

local function BuildMotion(p)
    local card = Card(p, "Motion", 0, 0, PAGE_W, 196)
    Setting(card, "Crits stay in place", 12, -30, "sticky",
        "Critical hits jump out and stay in place for a moment instead of moving with the rest, "
        .. "whatever the area's movement.")
    Setting(card, "Add up rapid hits", COL2, -30, "merge",
        "Hits from the same spell that land together are shown as one total, like \"Swipe 150 (x3)\".")
    Slider(card, "Time on screen", 12, -64, "scrollTime", { suffix = " sec", step = 0.5, fmt = "%.1f",
        tip = "How long a line takes to cross its area. Notifications move a little faster, and Pop lines "
            .. "stay a little over half as long." })
    Slider(card, "Area height", COL2, -64, "height", { suffix = " px", step = 10,
        tip = "How tall the Outgoing and Incoming areas are: how far their lines travel. The Healing area is "
            .. "60% of it and Notifications 45%." })
    Slider(card, "Ticks and area hits add up for", 12, -116, "tickMerge", { suffix = " sec", step = 0.5,
        fmt = "%.1f", zero = "Off", enabledIf = function() return BT.db.merge end,
        tip = "Ticks of your bleeds and DoTs, and the hits of an area spell, keep adding up on one line for this "
            .. "long. Off: as quickly as other hits. Needs Add up rapid hits." })
    CardNote(card, "How each area's lines move (Scroll, Pop, Fountain or Horizontal), which way, and whether they "
        .. "curve, is under Appearance on that area's own tab.", -156)
end

local function BuildOutgoing(p)
    local card = Card(p, "What you do", 0, 0, PAGE_W, 196)
    local damage = function() return BT.db.outDamage end
    Setting(card, "Damage", 12, -30, "outDamage", "Your hits on mobs: spells, abilities and swings.")
    Setting(card, "Misses", COL2, -30, "outMisses",
        "Your attacks that miss, or are dodged, parried, fully blocked or resisted.")
    Setting(card, "Auto attacks", 12, -56, "outSwings",
        "Your white swings and their misses. Off: only your spells and abilities. Without the game's combat "
        .. "lines, a physical hit BattleText can't name counts as a swing.", Either("outDamage", "outMisses"))
    Setting(card, "Pet", COL2, -56, "outPet",
        "Your pet's hits and heals, marked (Pet). This only works when the game lets BattleText read its combat "
        .. "lines; when it doesn't, your pet's hits can't be told from yours and show with them.")
    Setting(card, "Damage shields", 12, -82, "outShields",
        "What your damage shields do to whoever hits you: buffs like Thorns, Lightning Shield and Retribution Aura "
        .. "(learned from their first two hits), and gear that stings back. Off: hidden.", damage)
    Setting(card, "Name seal hits", COL2, -82, "outSeals",
        "Paladins: the Holy hit of Seal of Righteousness or Seal of Command that lands with your swing shows the "
        .. "seal's name and icon. Off: it shows as a plain number.", damage)
    IconsAndNames(card, -108, "out", "your hits and misses", Either("outDamage", "outMisses"))
    Slider(card, "Hide hits below", 12, -142, "minDamage", { step = 5, zero = "Off", enabledIf = damage,
        tip = "Your hits (and your pet's) for less than this aren't shown. A hit whose number the game hides "
            .. "always shows." })
    AreaLook(p, -206, "out", true)
end

local function BuildIncoming(p)
    local card = Card(p, "What happens to you", 0, 0, PAGE_W, 116)
    Setting(card, "Damage", 12, -30, "inDamage", "The damage you take.")
    Setting(card, "Avoids", COL2, -30, "inMisses", "Attacks you dodge, parry, block or resist, and ones that miss you.")
    Setting(card, "Power gains", 12, -56, "inPower", "Mana, rage and energy you gain.")
    IconsAndNames(card, -82, "in", "what hits you or what you avoid (only when the game says which spell)",
        Either("inDamage", "inMisses"))
    AreaLook(p, -126, "in", true)
end

local function BuildHealing(p)
    local card = Card(p, "Heals", 0, 0, PAGE_W, 196)
    local anyHeals = Either("inHeals", "outHeals")
    Setting(card, "Own area for heals", 12, -30, "healArea",
        "Heals scroll in their own area, under your character. Off: they show with damage, heals you get in the "
        .. "Incoming area and heals you do in the Outgoing one.")
    Setting(card, "Show overhealing", COL2, -30, "healOver",
        "The grey \"(40 over)\" after a heal. Only when the game lets BattleText read its combat lines.", anyHeals)
    Setting(card, "Heals you get", 12, -56, "inHeals", "Heals on you, yours and other people's.")
    Setting(card, "Heals you do", COL2, -56, "outHeals", "Your heals on others (and your pet's).")
    IconsAndNames(card, -82, "heal", "heals", anyHeals)
    Setting(card, "Show who you healed", 12, -108, "healWho",
        "The name of the player you healed, after the number. Only when the game lets BattleText read it.",
        function() return BT.db.outHeals end)
    Slider(card, "Hide heals below", 12, -142, "minHeal", { step = 5, zero = "Off", enabledIf = anyHeals,
        tip = "Heals for less than this aren't shown. A heal whose number the game hides always shows." })
    AreaLook(p, -206, "heal", false, function() return BT.db.healArea end,
        "Off: heals use the Incoming and Outgoing areas")
end

local function BuildNotifications(p, refs)
    local card = Card(p, "Show", 0, 0, PAGE_W, 186)
    Setting(card, "Combat", 12, -30, "nCombat", "+Combat and -Combat as you enter and leave a fight.")
    Setting(card, "Killing blows", COL2, -30, "nKill",
        "\"Killing blow!\" when your hit kills. Only when the game lets BattleText read its combat lines "
        .. "(it often hides them).")
    Setting(card, "Experience", 12, -56, "nXP", "The experience you gain, like \"+103 XP\".")
    Setting(card, "Reputation", COL2, -56, "nRep", "Reputation you gain or lose with a faction.")
    Setting(card, "Honor", 12, -82, "nHonor", "Honor you gain.")
    Setting(card, "Loot", COL2, -82, "nLoot", "Items you loot, with how many.")
    Setting(card, "Money", 12, -108, "nMoney", "Money you loot or get.")
    Setting(card, "Skill ups", COL2, -108, "nSkill", "A skill going up, like First Aid or a weapon skill.")
    Setting(card, "Seals", 12, -134, "nSeals",
        "Paladins: a line when a seal goes on or comes off. In a fight the game hides your buffs, so a seal "
        .. "coming off is worked out: Judgement uses it up, a new seal replaces it, or its 30 seconds run out.")
    Setting(card, "Buffs", COL2, -134, "nBuffs",
        "A line when a buff goes on or comes off. The game hides your buffs during a fight: there, a buff you put on "
        .. "yourself (Slice and Dice, Evasion...) shows as you cast it, and the rest of what changed shows when the fight "
        .. "ends. Not shown: food and drink, and buffs with no time limit (mounts, auras, stances).")
    Setting(card, "Ability alerts", 12, -160, "nAlerts",
        "A line when an ability you can use only just then opens up: \"Overpower!\" when your target dodges you, "
        .. "\"Revenge!\" when you dodge, parry or block (warriors), \"Riposte!\" or \"Counterattack!\" when you "
        .. "parry (rogues and hunters with the talent).")

    local extras = Card(p, "Extras", 0, -196, PAGE_W, 86)
    Setting(extras, "Fight summary", 12, -30, "nSummary",
        "When a fight ends: your damage, damage per second and healing, like \"4,820 damage (127 DPS) in 38s\". "
        .. "Only counts numbers the game lets BattleText read.")
    Setting(extras, "Icons", COL2, -30, "nIcons",
        "Shows the icon beside loot, skill ups, seals, buffs and ability alerts.",
        Either("nLoot", "nSkill", "nSeals", "nBuffs", "nAlerts"))
    local soundKeys = {}
    for _, s in ipairs(BT.SOUNDS) do soundKeys[#soundKeys + 1] = s.key end
    local function soundName(k) return BT:SoundName(k) end
    local pickTip = "Picking a sound plays it. If this game doesn't have it, chat says so."
    Setting(extras, "Crit sound", 12, -56, "soundCrit", "A sound when you crit. Pick it in the list beside it.")
    refs.critSoundDropdown = Dropdown(extras, 130, -54, 126, soundKeys, soundName, "critSound",
        function(k) BT:SetAlertSound("crit", k) end, pickTip)
    Setting(extras, "Kill sound", COL2, -56, "soundKill",
        "A sound on your killing blows (only when the game lets BattleText read its combat lines). "
        .. "Pick it in the list beside it.")
    refs.killSoundDropdown = Dropdown(extras, COL2 + 118, -54, 126, soundKeys, soundName, "killSound",
        function(k) BT:SetAlertSound("kill", k) end, pickTip)
    refs.critSoundDropdown.menuScroll, refs.killSoundDropdown.menuScroll = 20 * 12, 20 * 12
    AreaLook(p, -292, "n")
end

local function BuildColors(p)
    local rows = math.ceil(#BT.COLOR_CHOICES / 2)
    local card = Card(p, "Colors", 0, 0, PAGE_W, 40 + rows * 26 + 66)
    for i, choice in ipairs(BT.COLOR_CHOICES) do
        local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
        Swatch(card, choice[2], col == 0 and 12 or COL2, -30 - row * 26, choice[1])
    end
    local reset = FlatButton(card, "Reset colors", 120)
    reset:SetPoint("TOPLEFT", 12, -36 - rows * 26)
    reset:SetScript("OnClick", function()
        BT:Confirm("Put every text color back to how it started?", "Reset colors", function()
            wipe(BT.db.colors)
            BT:ApplyColors()
            BT:RefreshConfig()
        end)
    end)
    CardNote(card, "Spells that do Holy, Fire, Nature, Frost, Shadow or Arcane damage keep their school's color.",
        -72 - rows * 26)
end

-- Tab icons are the game's own icon files
local TABS = {
    { key = "general",  label = "General",       icon = "Interface\\Icons\\INV_Misc_Gear_01",                build = BuildGeneral },
    { key = "text",     label = "Text",          icon = "Interface\\Icons\\INV_Misc_Note_01",                build = BuildText },
    { key = "scroll",   label = "Motion",        icon = "Interface\\Icons\\INV_Misc_Spyglass_03",            build = BuildMotion },
    { key = "outgoing", label = "Outgoing",      icon = "Interface\\Icons\\INV_Sword_04",                    build = BuildOutgoing },
    { key = "incoming", label = "Incoming",      icon = "Interface\\Icons\\Ability_Warrior_DefensiveStance", build = BuildIncoming },
    { key = "healing",  label = "Healing",       icon = "Interface\\Icons\\Spell_Holy_Heal",                 build = BuildHealing },
    { key = "notify",   label = "Notifications", icon = "Interface\\Icons\\INV_Misc_Bag_08",                 build = BuildNotifications },
    { key = "colors",   label = "Colors",        icon = "Interface\\Icons\\INV_Misc_Gem_Variety_01",         build = BuildColors },
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
-- A window with a box of text: /btf copy (the lines recorded by /btf debug,
-- since chat can't be copied) and Share settings
---------------------------------------------------------------------------
local COPY_W, COPY_H, COPY_HEADER = 640, 380, 40

local function TextWindow()
    local f = CreateFrame("Frame", "BattleTextForeverCopy", UIParent)
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
    f.title = Text(header, "", "GameFontNormal", C.title)
    f.title:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    local close = FlatButton(header, "X", 24, 24)
    close:SetPoint("RIGHT", -8, 0)
    close:SetScript("OnClick", function() f:Hide() end)
    -- Share settings' Import: takes what's in the box, and whether to take their area positions too
    f.action = FlatButton(header, "Import", 80, 24)
    f.action:SetPoint("RIGHT", close, "LEFT", -8, 0)
    f.action:Hide()
    f.positions = T.LabeledSwitch(header, "Positions too", 0, 0)
    f.positions:ClearAllPoints()
    f.positions:SetPoint("RIGHT", f.action, "LEFT", -112, 0)
    f.positions:SetScript("OnClick", function(self) self:SetOn(not self:IsOn()) end)
    T.Tooltip(f.positions, "Positions too",
        "Also move your text areas to where they were on their screen. Off: yours stay where they are.")
    f.positions:Hide()
    f.positions.label:Hide()

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
    edit:SetMaxLetters(0)   -- (no limit: a pasted settings line is a few thousand letters)
    edit:SetWidth(COPY_W - 60)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    f.edit, f.scroll = edit, scroll
    return f
end

-- Shows the window with this title and text (rows: about how many lines it takes)
function BT:ShowTextWindow(title, text, rows, action)
    local f = self.copyWindow or TextWindow()
    self.copyWindow = f
    f.title:SetText(title)
    f.edit:SetText(text)
    local height = math.max(rows, 4) * 28 + 12
    f.edit:SetHeight(height)
    f.scroll:SetContent(COPY_W - 48, height)
    f.action:SetShown(action ~= nil)
    f.action:SetScript("OnClick", action)
    f.positions:SetShown(action ~= nil)
    f.positions.label:SetShown(action ~= nil)
    f.positions:SetOn(false)
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
    return f
end

function BT:OpenCopyWindow()
    local text = "Nothing recorded yet. Type /btf debug, fight for a moment, then /btf copy."
    local count = 1
    if self.recorded and #self.recorded > 0 then
        -- "|" doubled, so the links show as text instead of turning into links
        text = (table.concat(self.recorded, "\n"):gsub("|", "||"))
        count = #self.recorded
    end
    -- Long lines wrap, so leave room for about two rows each
    self:ShowTextWindow("Combat lines: press Ctrl+C to copy, then paste into your report", text, count)
end

-- mode: "export" (your settings, to copy) or "import" (paste, then click Import)
function BT:OpenShareWindow(mode)
    if mode == "export" then
        self:ShowTextWindow("Your settings: press Ctrl+C to copy, then share them", self:ExportSettings(), 8)
        return
    end
    local f
    f = self:ShowTextWindow("Paste settings with Ctrl+V, then click Import", "", 8, function()
        local t, count = BT:ReadSettings(f.edit:GetText())
        if not t then
            BT.Print("couldn't import: " .. count .. ".")
            return
        end
        local whose = BT:OwnSettings() and "this character's own settings" or "the settings every character shares"
        local positions = f.positions:IsOn()
        BT:Confirm(("Replace %s with these (%d settings)?%s"):format(whose, count,
            positions and " Your text areas move to their places too." or ""), "Import", function()
            BT:TakeSettings(t, positions)
            BT.Print("settings imported.")
            f:Hide()
        end)
    end)
end
