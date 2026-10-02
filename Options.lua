-- BattleText Forever: options window.
-- Left: how the text looks. Right: what gets shown.

local _, ns = ...
local BT = ns.BT

local refreshers = {}
local function AddRefresher(fn) table.insert(refreshers, fn) end

local function Label(parent, text, x, y, template)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    return fs
end

-- Section heading in gold, with a line under it
local function Heading(parent, text, x, y, width)
    local fs = Label(parent, text, x, y, "GameFontNormal")
    fs:SetTextColor(unpack(BT.COLORS.gold))
    local line = parent:CreateTexture(nil, "ARTWORK")
    local g = BT.COLORS.goldDark
    line:SetColorTexture(g[1], g[2], g[3], 0.6)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", x, y - 16)
    line:SetWidth(width)
    return fs
end

local function Check(parent, text, x, y, key, tip)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    fs:SetText(text)
    cb.label = fs
    cb:SetScript("OnClick", function(self)
        local v = self:GetChecked() and true or false
        if key == "locked" then
            BT:SetLocked(not v)   -- the box reads "Move the text areas"
        else
            BT.db[key] = v
            BT:ApplySettings()
        end
    end)
    if tip then
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(text)
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    AddRefresher(function()
        local v = BT.db[key]
        if key == "locked" then v = not v end
        cb:SetChecked(v and true or false)
    end)
    return cb
end

local function Slider(parent, text, x, y, key, min, max, suffix, step)
    suffix = suffix or ""
    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", x, y)
    local s = CreateFrame("Slider", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    s:SetOrientation("HORIZONTAL")
    s:SetSize(190, 17)
    s:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -3)
    s:SetHitRectInsets(0, 0, -8, -8)
    local track = s:CreateTexture(nil, "BACKGROUND")
    local n = BT.COLORS.navy
    track:SetColorTexture(n[1], n[2], n[3], 1)
    track:SetHeight(6)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step or 1)
    s.label = text
    local function show(v) title:SetText(text .. ": |cff" .. BT.GOLD_HEX .. v .. suffix .. "|r") end
    s:SetScript("OnValueChanged", function(_, v)
        step = step or 1
        v = math.floor(v / step + 0.5) * step
        show(v)
        if BT.db[key] ~= v then
            BT.db[key] = v
            BT:ApplySettings()
        end
    end)
    AddRefresher(function()
        s:SetValue(BT.db[key])
        show(BT.db[key])
    end)
    return s
end

local function Button(parent, text, width, x, y, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width, 22)
    b:SetPoint("TOPLEFT", x, y)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

function BT:RefreshConfig()
    if not self.config then return end
    for _, fn in ipairs(refreshers) do fn() end
end

function BT:BuildConfig()
    local f = CreateFrame("Frame", "BattleTextForeverOptions", UIParent)
    f:SetSize(560, 590)
    f:SetPoint("CENTER")
    self:SkinFrame(f, self.COLORS.dark, self.COLORS.goldDark, 0.97, 2)
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()
    table.insert(UISpecialFrames, "BattleTextForeverOptions")   -- Escape closes it

    local banner = CreateFrame("Frame", nil, f)
    banner:SetPoint("TOPLEFT", 2, -2)
    banner:SetPoint("TOPRIGHT", -2, -2)
    banner:SetHeight(28)
    self:SkinFrame(banner, self.COLORS.crimson, self.COLORS.goldDark, 1, 1)
    local title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("CENTER")
    title:SetText("BattleText Forever")
    title:SetTextColor(unpack(self.COLORS.gold))
    local close = CreateFrame("Button", nil, banner, "UIPanelCloseButton")
    close:SetPoint("RIGHT", 2, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    local logoFrame = CreateFrame("Frame", nil, f)
    logoFrame:SetAllPoints(f)
    logoFrame:SetFrameLevel(banner:GetFrameLevel() + 5)
    local logo = logoFrame:CreateTexture(nil, "OVERLAY")
    logo:SetSize(60, 60)
    logo:SetPoint("TOPLEFT", -18, 18)
    logo:SetTexture(self.ICON)
    f.logo = logo

    -- Left column: how the text looks
    local x, y = 20, -48
    local W = 240
    Heading(f, "Text", x, y, W)
    y = y - 24
    Check(f, "Show BattleText", x, y, "enabled")
    y = y - 24
    Check(f, "Move the text areas", x, y, "locked",
        "Shows a box for each text area. Drag the boxes where you want them, then untick this.")
    y = y - 24
    Check(f, "Spell names", x, y, "spellNames", "Show the spell's name beside the number.")
    y = y - 24
    Check(f, "Spell icons", x, y, "icons", "Show the spell's icon beside your own spells.")
    y = y - 24
    Check(f, "Crits pop and hold", x, y, "sticky",
        "Critical hits jump out and stay in place for a moment instead of scrolling.")
    y = y - 24
    Check(f, "Curved scrolling", x, y, "curved", "Lines bow outward as they scroll. Untick for straight lines.")
    y = y - 24
    Check(f, "Add up rapid hits", x, y, "merge",
        "Hits from the same spell that land together are shown as one total, like \"Swipe 150 (x3)\".")
    y = y - 24
    Check(f, "Hide the game's own numbers", x, y, "hideBlizzard",
        "Turns off the game's floating combat text so numbers aren't shown twice. Untick to turn it back on.")
    y = y - 24
    Check(f, "Minimap button", x, y, "minimap")
    y = y - 34

    Label(f, "Font", x + 4, y)
    local fontButton = Button(f, "", 150, x + 50, y + 4, function(self)
        local nextIndex = 1
        for i, font in ipairs(BT.FONTS) do
            if font.name == BT.db.font then nextIndex = (i % #BT.FONTS) + 1 break end
        end
        BT.db.font = BT.FONTS[nextIndex].name
        self:SetText(BT.db.font)
    end)
    AddRefresher(function() fontButton:SetText(BT.db.font) end)
    y = y - 32
    Slider(f, "Text size", x + 4, y, "fontSize", 10, 40)
    y = y - 44
    Slider(f, "Crit size", x + 4, y, "critScale", 100, 250, "%", 10)
    y = y - 44
    Slider(f, "Scroll time", x + 4, y, "scrollTime", 1, 6, " sec")
    y = y - 44
    Slider(f, "Scroll distance", x + 4, y, "height", 100, 500, "", 10)

    Button(f, "Show sample text", 130, x, -552, function() BT:Test() end)
    Button(f, "Reset positions", 110, x + 136, -552, function() BT:ResetPositions() end)

    -- Right column: what gets shown
    x, y = 300, -48
    Heading(f, "What you do", x, y, W)
    y = y - 24
    Check(f, "Damage", x, y, "outDamage")
    Check(f, "Heals", x + 120, y, "outHeals")
    y = y - 24
    Check(f, "Misses", x, y, "outMisses",
        "Your attacks that miss or are dodged, parried, blocked or resisted. "
        .. "The Combat Log leaves these out until you tick them in its settings (see Good to know).")
    Check(f, "Pet", x + 120, y, "outPet",
        "Your pet's hits. The Combat Log leaves your pet out until you tick it in its settings (see Good to know).")
    y = y - 32
    Slider(f, "Hide hits below", x + 4, y, "minDamage", 0, 500, "", 5)
    y = y - 50

    Heading(f, "What happens to you", x, y, W)
    y = y - 24
    Check(f, "Damage", x, y, "inDamage")
    Check(f, "Heals", x + 120, y, "inHeals")
    y = y - 24
    Check(f, "Avoids", x, y, "inMisses", "Attacks you dodge, parry, block or resist.")
    Check(f, "Power gains", x + 120, y, "inPower", "Mana, rage and energy you gain.")
    y = y - 36

    Heading(f, "Notifications", x, y, W)
    y = y - 24
    Check(f, "Combat", x, y, "nCombat", "Entering and leaving combat.")
    Check(f, "Killing blows", x + 120, y, "nKill")
    y = y - 24
    Check(f, "Experience", x, y, "nXP")
    Check(f, "Reputation", x + 120, y, "nRep")
    y = y - 24
    Check(f, "Honor", x, y, "nHonor")
    Check(f, "Loot", x + 120, y, "nLoot")
    y = y - 24
    Check(f, "Money", x, y, "nMoney")
    Check(f, "Skill ups", x + 120, y, "nSkill")
    y = y - 40

    Heading(f, "Good to know", x, y, W)
    y = y - 24
    local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", x, y)
    note:SetWidth(W)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText("Click \"Start BattleText\" once after you log in (or open the Combat Log tab). "
        .. "The game only writes its combat lines after that.\n\n"
        .. "Your hits and heals follow the filter chosen on the Combat Log tab. \"My actions\" is the one to use.\n\n"
        .. "For your misses and your pet too: right-click that tab, choose Settings, and in \"My actions\" tick "
        .. "Misses (Message Types) and Pet (Message Sources).")

    self.config = f
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
