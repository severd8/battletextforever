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
    if s.SetBackdrop and BACKDROP_SLIDER_8_8 then
        s:SetBackdrop(BACKDROP_SLIDER_8_8)   -- the game's own slider track
    else
        local track = s:CreateTexture(nil, "BACKGROUND")
        local n = BT.COLORS.navy
        track:SetColorTexture(n[1], n[2], n[3], 1)
        track:SetHeight(6)
        track:SetPoint("LEFT")
        track:SetPoint("RIGHT")
    end
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
    f:SetSize(560, 606)
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
    -- Closing the window is the end of moving things about: the text areas lock
    -- again (and "Move the text areas" is unticked the next time it opens)
    f:SetScript("OnHide", function()
        if not BT.db.locked then BT:SetLocked(true) end
    end)

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
    -- The list of fonts, for the game's menus: one to pick, ticked
    local plainButton   -- set on a client without the game's dropdown
    local function fontMenu(_, root)
        if root.SetScrollMode then root:SetScrollMode(20 * 12) end   -- twelve rows, then it scrolls
        for _, font in ipairs(BT.FONTS) do
            root:CreateRadio(font.name, function() return BT.db.font == font.name end, function()
                BT:SetFont(font.name)
                if plainButton then plainButton:SetText(font.name) end
            end)
        end
    end
    local made, dropdown = pcall(CreateFrame, "DropdownButton", nil, f, "WowStyle1DropdownTemplate")
    if made and dropdown and dropdown.SetupMenu then
        -- The game's own dropdown: it shows the font that's ticked
        dropdown:SetPoint("TOPLEFT", x + 50, y + 6)
        dropdown:SetWidth(175)
        dropdown:SetupMenu(fontMenu)
        AddRefresher(function() dropdown:GenerateMenu() end)
    else
        -- A client without it: a button that opens the same list, or steps through the fonts
        dropdown = Button(f, "", 175, x + 50, y + 4, function(self)
            if MenuUtil and MenuUtil.CreateContextMenu then
                MenuUtil.CreateContextMenu(self, fontMenu)
                return
            end
            local nextIndex = 1
            for i, font in ipairs(BT.FONTS) do
                if font.name == BT.db.font then nextIndex = (i % #BT.FONTS) + 1 break end
            end
            BT:SetFont(BT.FONTS[nextIndex].name)
            self:SetText(BT.db.font)
        end)
        plainButton = dropdown
        AddRefresher(function() dropdown:SetText(BT.db.font) end)
    end
    f.fontDropdown = dropdown
    y = y - 32
    Slider(f, "Text size", x + 4, y, "fontSize", 10, 40)
    y = y - 44
    Slider(f, "Crit size", x + 4, y, "critScale", 100, 250, "%", 10)
    y = y - 44
    Slider(f, "Scroll time", x + 4, y, "scrollTime", 1, 6, " sec")
    y = y - 44
    Slider(f, "Scroll distance", x + 4, y, "height", 100, 500, "", 10)

    Button(f, "Show sample text", 130, x, -568, function() BT:Test() end)
    Button(f, "Reset positions", 110, x + 136, -568, function() BT:ResetPositions() end)

    -- Right column: what gets shown
    x, y = 300, -48
    Heading(f, "What you do", x, y, W)
    y = y - 24
    Check(f, "Damage", x, y, "outDamage")
    Check(f, "Heals", x + 120, y, "outHeals")
    y = y - 24
    Check(f, "Misses", x, y, "outMisses", "Your attacks that miss or are dodged, parried, blocked or resisted.")
    Check(f, "Pet", x + 120, y, "outPet",
        "Your pet's hits, marked (Pet). This only works when the game lets BattleText read its combat lines; "
        .. "when it doesn't, your pet's hits can't be told from yours and show with them.")
    y = y - 24
    Check(f, "Damage shields", x, y, "outShields",
        "What your damage shields do to whoever hits you: buffs like Thorns, Lightning Shield and Retribution Aura "
        .. "(learned from their first two hits), and gear that stings back.")
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
    Check(f, "Killing blows", x + 120, y, "nKill",
        "Only when the game lets BattleText read its combat lines (it often hides them).")
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
    note:SetText("Your hits are read from the unit you hit: your target, and the mobs attacking you or your pet. "
        .. "Turn on enemy nameplates for the ones you aren't targeting.\n\n"
        .. "The game doesn't say whose hit it was: alone, your pet's hits show as yours.\n\n"
        .. "Click \"Start BattleText\" once after you log in. It lets BattleText name the ticks of your bleeds, "
        .. "and in a group it leaves other people's hits out.")

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

---------------------------------------------------------------------------
-- /btf copy: the lines recorded by /btf debug, in a box they can be copied
-- from (chat can't be copied)
---------------------------------------------------------------------------
function BT:OpenCopyWindow()
    local f = self.copyWindow
    if not f then
        f = CreateFrame("Frame", "BattleTextForeverCopy", UIParent)
        f:SetSize(640, 380)
        f:SetPoint("CENTER")
        self:SkinFrame(f, self.COLORS.dark, self.COLORS.goldDark, 0.97, 2)
        f:SetFrameStrata("DIALOG")
        f:EnableMouse(true)
        f:Hide()
        table.insert(UISpecialFrames, "BattleTextForeverCopy")   -- Escape closes it

        local banner = CreateFrame("Frame", nil, f)
        banner:SetPoint("TOPLEFT", 2, -2)
        banner:SetPoint("TOPRIGHT", -2, -2)
        banner:SetHeight(28)
        self:SkinFrame(banner, self.COLORS.crimson, self.COLORS.goldDark, 1, 1)
        local title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("CENTER")
        title:SetText("Combat lines: press Ctrl+C to copy, then paste into your report")
        title:SetTextColor(unpack(self.COLORS.gold))
        local close = CreateFrame("Button", nil, banner, "UIPanelCloseButton")
        close:SetPoint("RIGHT", 2, 0)
        close:SetScript("OnClick", function() f:Hide() end)

        local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -40)
        scroll:SetPoint("BOTTOMRIGHT", -32, 12)
        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject("ChatFontNormal")
        edit:SetWidth(590)
        edit:SetScript("OnEscapePressed", function() f:Hide() end)
        scroll:SetScrollChild(edit)
        f.edit = edit
        self.copyWindow = f
    end
    local text = "Nothing recorded yet. Type /btf debug, fight for a moment, then /btf copy."
    if self.recorded and #self.recorded > 0 then
        -- "|" doubled, so the links show as text instead of turning into links
        text = (table.concat(self.recorded, "\n"):gsub("|", "||"))
    end
    f.edit:SetText(text)
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end
