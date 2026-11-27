-- BattleText Forever: which hits are yours, and what they were.
-- (Split from Core.lua in 1.33.0. Core.lua's shared locals come through ns.S, below.)

local ADDON, ns = ...
local S = ns.S
local BT, Parser, L, Print, MASK_COLORS, InSchool = S.BT, S.Parser, S.L, S.Print, S.MASK_COLORS, S.InSchool
local IsSecret, Num, Str, AmountText, Flag, TargetIs = S.IsSecret, S.Num, S.Str, S.AmountText, S.Flag, S.TargetIs
local TargetsYou, PetsTarget, IsEnglish, Commas, SpellAfter, MISS_TEXT = S.TargetsYou, S.PetsTarget, S.IsEnglish, S.Commas, S.SpellAfter, S.MISS_TEXT
local MissText, UnnamedHit, HEAL_CAST_TIME, SameHealSchool, CREDIT_TIME, LINE_WITH_HIT = S.MissText, S.UnnamedHit, S.HEAL_CAST_TIME, S.SameHealSchool, S.CREDIT_TIME, S.LINE_WITH_HIT
local SWING_RECENT, EXTRA_TIME, EXTRA_HITS, TICK_SLACK, TICK_CLOSE, DOT_TIME = S.SWING_RECENT, S.EXTRA_TIME, S.EXTRA_HITS, S.TICK_SLACK, S.TICK_CLOSE, S.DOT_TIME
local UNNAMED_KEEP, BEAT_LEAST, BEAT_MOST, FLAG_NOTES, STING_FLIGHT, UNSEALED_WRATH = S.UNNAMED_KEEP, S.BEAT_LEAST, S.BEAT_MOST, S.FLAG_NOTES, S.STING_FLIGHT, S.UNSEALED_WRATH
local FLIGHT_TIME, HAWK_TIME, HAWK_MOST, RANGED_SPELLS, MAIN_HAND, ATTACK_SPELL = S.FLIGHT_TIME, S.HAWK_TIME, S.HAWK_MOST, S.RANGED_SPELLS, S.MAIN_HAND, S.ATTACK_SPELL
local THROW_TIME, AREA_SLACK, VIGIL_TIME, LIFE_TAP, LIFE_TAP_TIME, LIFE_TAP_BEFORE = S.THROW_TIME, S.AREA_SLACK, S.VIGIL_TIME, S.LIFE_TAP, S.LIFE_TAP_TIME, S.LIFE_TAP_BEFORE
local LIFE_TAP_LOOK, SpellName, DEEP_WOUNDS = S.LIFE_TAP_LOOK, S.SpellName, S.DEEP_WOUNDS

-- A Holy hit that lands with your swing on the same unit, while a seal that adds
-- damage is on you, is the seal's. The swing's own hit can come up to a second after its
-- combat log line, while the seal's comes with its line: so the seal's hit can be ahead of the
-- swing's (Seal of Righteousness showing as plain numbers). A swing just before also counts
-- (SEAL_AFTER_SWING, unless frameOnly), and a hit with neither waits for one (WaitForSwing).
local SEAL_SWING_TIME = 1.2   -- how long a seal's hit waits for the swing's
local SEAL_AFTER_SWING = 0.5  -- how long after the swing's hit the seal's can come
-- How long after a blow on you your damage shields' hits can come (Tyler's log, 1.28.2: Thorns
-- and Spiked Shell Band 0.57s after the blow, shown unnamed with the seal's 0.5)
local SHIELD_AFTER_BLOW = 1.0
-- With Unsealed Wrath, a Holy hit with your swing that the seal on you doesn't explain (it
-- adds no damage, or there's none) is the talent's stored seal going off. Until 1.19.1 it was
-- taken for Retribution Aura's answer to the mob's blow, and hidden with "Damage shields" off.
function BT:SealOn(h)
    local seal = self.seal
    if not self.db.outSeals then return nil end
    if h.kind ~= "damage" then return nil end
    local mask = Num(h.school)
    if seal and seal.school and GetTime() <= seal.ends + 1 then
        if mask == seal.school then return seal end
    end
    if mask == UNSEALED_WRATH[3] and self:KnowsSpell(UNSEALED_WRATH[1]) then
        return { id = UNSEALED_WRATH[1], name = SpellName(UNSEALED_WRATH[1]) or UNSEALED_WRATH[2],
            school = UNSEALED_WRATH[3] }
    end
    return nil
end

function BT:SealFor(h, seq, first, last, at, frameOnly)
    local seal = self:SealOn(h)
    if not seal then return nil end
    for j = first, last do
        local o = seq[j]
        if j ~= at and o.hit and not o.splash and o.kind == "damage" and Num(o.school) == 1
            and ((h.key and o.key == h.key) or (not h.key and o.unit == h.unit)) then
            return { id = seal.id, name = seal.name }
        end
    end
    local struck = not frameOnly and h.key and self.struck and self.struck[h.key]
    if struck and h.time - struck >= 0 and h.time - struck <= SEAL_AFTER_SWING then
        return { id = seal.id, name = seal.name }
    end
    return nil
end

-- A damage shield of yours (Retribution Aura, Thorns) hurting a mob that's after you: its
-- amount is often hidden, so it can't be learned (KnownShield). The shield's hit comes with its
-- line, the mob's blow on you trails it like a swing: a hit of the shield's school that nothing
-- named, on a mob after you, is the shield's when a blow lands on you just before or soon after.
-- Gear that stings back counts too (Tyler, 1.25.1: Thorns and a Spiked Shell Band, both Nature,
-- both hidden; the band's 2 showed unnamed beside "Thorns 9"). ShieldsOn: every shield the hit
-- can be, buffs first (the game sends the buff's answer first: real_fight3.txt, Thorns then
-- Sporid Cape), so each one a blow answers names one hit.
function BT:ShieldsOn(h)
    if h.kind ~= "damage" then return nil end   -- (with "Damage shields" off it's still named, then hidden)
    local mask = Num(h.school)
    if not mask or mask == 1 then return nil end
    if not TargetsYou(h.unit) then return nil end
    local list = {}
    local names = {}
    for name in pairs(self.buffShields or {}) do names[#names + 1] = name end
    table.sort(names)   -- (always the same order)
    for _, name in ipairs(names) do
        local shield = self.buffShields[name]
        -- (a readable amount that isn't the one it's known to hit for is something else)
        local known = self.db.shieldAmounts[name]
        if shield.school == mask and not (h.n and known and h.n ~= known) then list[#list + 1] = shield end
    end
    for _, item in ipairs(self.itemShields or {}) do
        if item.school == mask and not (h.n and item.amount and h.n ~= item.amount) then list[#list + 1] = item end
    end
    return list[1] and list or nil
end
-- Worn gear that hurts you too with each weapon blow, of this school (readable): { item }
function BT:GearHurtsYou(school)
    local mask = Num(school)
    if not mask or mask == 1 then return nil end
    for _, item in ipairs(self.itemProcs or {}) do
        if item.every and item.melee and item.school == mask then return item end
    end
    return nil
end
-- The blows on you lately, each with the shields that have answered it: one blow is answered
-- once by each shield. A hit after every shield has answered is not one of them.
function BT:NoteBlow(at)
    local list = {}
    for _, b in ipairs(self.recentBlows or {}) do
        if at - b.at <= SHIELD_AFTER_BLOW then list[#list + 1] = b end
    end
    list[#list + 1] = { at = at, names = {} }
    self.recentBlows = list
end
function BT:ShieldOn(h)
    local list = self:ShieldsOn(h)
    return list and list[1] or nil
end
-- The first of a hit's shields that this blow hasn't had an answer from yet
local function Unanswered(shields, answered)
    for _, s in ipairs(shields or {}) do
        if not answered[s.name] then return s end
    end
    return nil
end

-- A hit that may be your seal's (waiting for your swing) or your shield's (waiting for a blow on
-- you): held up to SEAL_SWING_TIME, then shown as it is. Returns true if it's held.
function BT:WaitForSwing(h)
    local seal = h.key and self:SealOn(h)
    local shields = self:ShieldsOn(h)
    local shield = shields and shields[1]
    local every = h.key and not seal and not h.everyUnsure and self:EveryOn(h)
    -- (a blow just before: each of its shields names one hit, the oldest blow first)
    local blowNear = false
    if shield and not seal and not every then
        for _, b in ipairs(self.recentBlows or {}) do
            if h.time - b.at >= 0 and h.time - b.at <= SHIELD_AFTER_BLOW then
                blowNear = true
                local fresh = Unanswered(shields, b.names)
                if fresh then
                    b.names[fresh.name] = true
                    local why = self:ShowUnitHit(h, "shield", fresh)
                    if self.db.debug then
                        self:Record(("  %s %s: %s"):format(h.unit, AmountText(h.amount), why or ("shield of " .. fresh.name)), h.time)
                    end
                    return true
                end
            end
        end
    end
    -- Every shield you're known to wear has answered the blows just before: this hit is
    -- something else's, shown as it is. Until 1.28.4 it was named after the first shield again
    -- (GitHub #25: Sporid Cape, unknown on a Russian client, named Lightning Shield).
    if blowNear then return self:AreaInstead(h) end
    if not seal and not shield and not every then return false end
    self.sealWait = self.sealWait or {}
    local entry = { h = h, seal = seal and { id = seal.id, name = seal.name }, shield = shield, shields = shields,
        every = every or nil }
    table.insert(self.sealWait, entry)
    local function over()
        for i, e in ipairs(BT.sealWait or {}) do
            if e == entry then
                if BT:WholeShieldSet(entry) then return end
                table.remove(BT.sealWait, i)
                if BT:AreaInstead(h) then return end
                local why = BT:ShowUnitHit(h, "hit", nil)
                if BT.db.debug then
                    BT:Record(("  %s %s: %s"):format(h.unit, AmountText(h.amount), why or "nothing came for it: shown"), h.time)
                end
                return
            end
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(SEAL_SWING_TIME, over) else over() end
    return true
end

-- A hit that waited as your shield's (or your seal's) and nothing came for it, while a spell of
-- yours of its school still burns there (Consecration with Retribution Aura on): it's that
-- spell's tick, its line lost (the mob dying in that moment). Until 1.43.0 it showed with no name
-- (a player's screenshot: a bare "6" under "7 Retribution Aura"). Returns true if it named it.
function BT:AreaInstead(h)
    if h.kind ~= "damage" then return false end
    local area = self:AreaFor(h)
    if not area then return false end
    local why = self:ShowUnitHit(h, "tick", area)
    if self.db.debug then
        self:Record(("  %s %s: %s"):format(h.unit, AmountText(h.amount),
            why or ("tick of " .. tostring(area.name) .. " (nothing else came for it)")), h.time)
    end
    return true
end

-- No blow came for a shield's hit, but it came with one hit for each of your shields of its
-- school, on the same mob in the same moment (two Nature hits with Thorns and a Spiked Shell Band
-- on: Tyler's log, 1.28.2, where the blow on you came as a miss or too long before): that's
-- the shields answering, each named in turn. Returns true if it named them.
function BT:WholeShieldSet(entry)
    local shields = entry.shields
    if entry.seal or entry.every or not shields or #shields < 2 then return false end
    local h = entry.h
    local set = {}
    for _, e in ipairs(self.sealWait or {}) do
        if not e.seal and not e.every and e.shields and e.h.time == h.time and e.h.unit == h.unit
                and Num(e.h.school) == Num(h.school) then
            set[#set + 1] = e
        end
    end
    if #set ~= #shields then return false end
    for _, e in ipairs(set) do
        for i, w in ipairs(self.sealWait) do
            if w == e then table.remove(self.sealWait, i) break end
        end
    end
    for n, e in ipairs(set) do
        local why = self:ShowUnitHit(e.h, "shield", shields[n])
        if self.db.debug then
            self:Record(("  %s %s: %s"):format(e.h.unit, AmountText(e.h.amount),
                why or ("shield of " .. shields[n].name .. " (with the others)")), e.h.time)
        end
    end
    return true
end

-- Something came for the hits waiting: your swing on a unit (key, for a seal), or a blow on you
-- (no key, for a shield)
-- spellHit: it was a spell's or ability's hit, not a weapon blow (only gear that adds to every
-- hit answers to that, not a seal or gear that adds to weapon blows only)
function BT:Resolved(key, at, spellHit)
    local list = self.sealWait
    if not list then return end
    -- One blow is answered once by each damage shield on you (Thorns and Retribution Aura both
    -- answer it). Until 1.19.1 it named one hit in all, and the other shield's was shown
    -- unnamed, even with "Damage shields" off.
    local answered = {}
    local i = 1
    while list[i] do
        local e = list[i]
        local what, spell
        if at - e.h.time <= SEAL_SWING_TIME then
            if key and e.seal and e.h.key == key and not spellHit then
                what, spell = "seal", e.seal
            elseif key and e.every and e.h.key == key
                    and not (spellHit and (e.every.melee or self:SpellsOfSchool(e.every.school))) then
                what, spell = "proc", e.every   -- (gear that adds to every hit: its amount is known)
            elseif not key and e.shield and Unanswered(e.shields, answered) then
                what, spell = "shield", Unanswered(e.shields, answered)
            end
        end
        if what then
            if not key then answered[spell.name] = true end
            table.remove(list, i)
            local why = self:ShowUnitHit(e.h, what, spell)
            if self.db.debug then
                self:Record(("  %s %s: %s"):format(e.h.unit, AmountText(e.h.amount), why or (what .. " of " .. spell.name)),
                    e.h.time)
            end
        else
            i = i + 1
        end
    end
end

function BT:SwingLanded(key, at) self:Resolved(key, at) end
function BT:BlowLanded(at) self:Resolved(nil, at) end

-- (asked once a frame: a raid sends many UNIT_COMBAT events in one)
function BT:InGroup()
    local now = GetTime()
    if self.groupAt ~= now then
        self.groupAt = now
        self.grouped = Flag(IsInGroup) or Flag(IsInRaid) or Flag(UnitExists, "party1")
    end
    return self.grouped
end

-- A helpful spell of yours, just sent or cast: for HEALS_LIVE after it, a heal on a group member
-- may be yours (a heal over time, Prayer of Mending, Light's Vigil, a channel all come from one).
-- Without one, the heals landing on your group are other people's, and OnUnitHit turns them away
-- before they cost anything more.
local HEALS_LIVE = 45   -- (DOT_TIME: the longest a heal of yours is kept going)
function BT:NoteHelpfulCast(id, name)
    local helpful = false
    if id and C_Spell and C_Spell.IsSpellHelpful then
        local ok, h = pcall(C_Spell.IsSpellHelpful, id)
        helpful = ok and not IsSecret(h) and h == true
    end
    if not helpful and name then
        local periodic = self:SpellLists()
        local dot = periodic[name]
        helpful = (dot and dot.heal) or (self.areaSpells and self.areaSpells[name] ~= nil)
            or self:HealsOrHarms(name) or self:IsVigil(name) or self:IsMending(name)
    end
    if helpful then self.healsLiveAt = GetTime() end
end

function BT:HealsLive(now)
    return self.healsLiveAt ~= nil and now - self.healsLiveAt <= HEALS_LIVE and now >= self.healsLiveAt
end

-- A unit you're fighting: your target, or one that's after you or your pet
local function Fighting(unit)
    return Flag(UnitIsUnit, unit, "target") or TargetsYou(unit)
        or PetsTarget(unit) or (Flag(UnitExists, "pet") and TargetIs(unit, "pet"))
end

-- A unit your pet is fighting: the pet's target, or one that's after the pet
local function PetOn(unit)
    return Flag(UnitExists, "pet") and (PetsTarget(unit) or TargetIs(unit, "pet"))
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

-- A mob you were just hitting, now dying or dead: its killing blow often arrives after it has let
-- go of you (no target any more), and it's no longer after you nor (often) your target. Without
-- this, a killing blow on a mob that wasn't your target was dropped as "not your fight".
local FOUGHT_TIME = 4     -- seconds since a hit of yours on it was shown (a damage-over-time tick is 3s apart)
function BT:NoteFought(key, at)
    if not key then return end
    self.fought = self.fought or {}
    self.fought[key] = at
end

function BT:Finishing(unit, now)
    local key = UnitKey(unit)
    local at = key and self.fought and self.fought[key]
    if not at or now - at > FOUGHT_TIME or now < at then return false end
    if Flag(UnitIsDead, unit) then return true end
    -- No target at all (a dying mob drops it). Hidden (on addon-restricted maps): not known, so no.
    local ok, v = pcall(UnitExists, unit .. "target")
    return ok and not IsSecret(v) and not v
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

-- One of your ranged attacks (RANGED_SPELLS), by the cast's spell ID: { school, wand, auto }
function BT:RangedSpell(id)
    local e = id and RANGED_SPELLS[id]
    if not e then return nil end
    return { school = e[2], wand = e[2] == nil, auto = true }
end

-- A readable line's spell that's one of your ranged attacks (in English or the game's language)
function BT:IsRangedName(name)
    if not name then return false end
    if not self.rangedNames then
        self.rangedNames = {}
        for id, e in pairs(RANGED_SPELLS) do
            self.rangedNames[e[1]] = true
            local own = SpellName(id)
            if own then self.rangedNames[own] = true end
        end
    end
    return self.rangedNames[name] == true
end

-- A spell on its way (or a ranged attack) and a hit's school: a wand's is any but physical
local function FlightSchool(f, mask)
    if mask == nil then return false end
    if f.wand then return mask ~= 1 end
    return InSchool(mask, f.school)
end

-- A spell of yours on its way to this unit, of the hit's school: the unit is in your fight even
-- before it has turned on you (a nuke cast to open the pull) and once it's dead or has dropped its
-- target (the overkill of a big nuke: the mob dies from it). Without this, both were "not your
-- fight" and the hit never showed (CurseForge, 1.24.4: Arcane Wrath).
function BT:FlightOn(unit, now, school)
    local list = self.flying
    if not list or #list == 0 then return false end
    local key, mask = UnitKey(unit), Num(school)
    if not key then return false end
    for _, f in ipairs(list) do
        if f.key == key and now >= f.at and now - f.at <= FLIGHT_TIME and FlightSchool(f, mask) then return true end
    end
    return false
end

-- Forms that fight with claws, not the weapon: their own icon goes on your swings
local CLAW_FORMS = { [5487] = "Bear Form", [9634] = "Dire Bear Form", [768] = "Cat Form" }
function BT:ClawFormIcon()
    if not (GetShapeshiftForm and GetShapeshiftFormInfo) then return nil end
    local ok, index = pcall(GetShapeshiftForm)
    index = ok and Num(index) or nil
    if not index or index == 0 then return nil end
    -- (the texture this gives for the form you're in is the stance bar's "on" star, not the
    -- form's: the icon comes from the form's spell instead)
    local ok2, _, _, _, spellId = pcall(GetShapeshiftFormInfo, index)
    spellId = ok2 and Num(spellId) or nil
    if not spellId then return nil end
    local name = SpellName(spellId)
    local claws = CLAW_FORMS[spellId] ~= nil
    for _, formName in pairs(CLAW_FORMS) do if name == formName then claws = true end end
    if not claws then return nil end
    return self:IconText(spellId)
end

-- The icon for a swing of yours, as text: a druid's form in Bear or Cat Form, else the weapon in
-- the hand that swung (hand: 0 main, 1 off, from PLAYER_SWING via SwingHand), else your main hand
-- weapon's, else the game's Attack
local OFF_HAND = 17
function BT:SwingIcon(hand)
    local claws = self:ClawFormIcon()
    if claws and claws ~= "" then return claws end
    local slot = MAIN_HAND
    if hand == 1 then
        slot = OFF_HAND
    elseif hand ~= 0 then
        -- Hand not known: with two weapons, neither weapon's icon. Two weapons is an off-hand
        -- swing seen (issue #15: UnitAttackSpeed is secret where unit stats are restricted, so
        -- its off hand speed alone missed it), or the off hand's speed (there only with a weapon)
        if self.dualWield then return self:IconText(ATTACK_SPELL) end
        local okSpeed, _, offSpeed = pcall(UnitAttackSpeed or function() end, "player")
        offSpeed = okSpeed and Num(offSpeed) or nil
        if offSpeed and offSpeed > 0 then return self:IconText(ATTACK_SPELL) end
    end
    local ok, tex = pcall(GetInventoryItemTexture or function() end, "player", slot)
    tex = ok and (Num(tex) or Str(tex)) or nil
    if tex then return self:IconTag(tex) end
    return self:IconText(ATTACK_SPELL)
end

-- Which hand a swing of yours on your target came from: PLAYER_SWING's swingType for the oldest
-- melee swing not yet matched, at or before the hit and within CREDIT_TIME (a swing's hit comes
-- with its animation, in the order swung). nil when there's none (then SwingIcon falls back).
function BT:SwingHand(h)
    local hands = self.hands
    if not hands or not hands[1] or not h or not h.time then return nil end
    if not (Flag(UnitIsUnit, h.unit, "target") or (h.key and h.key == UnitKey("target"))) then return nil end
    while hands[1] and h.time - hands[1].at > CREDIT_TIME do table.remove(hands, 1) end
    if hands[1] and hands[1].at <= h.time then return table.remove(hands, 1).hand end
    return nil
end

-- An unnamed physical hit on your target that no swing of yours matches, while the game's swing
-- timer is known to work and you haven't swung in melee lately (a hunter at range): not your
-- weapon's. Tinter on CurseForge: a hunter's pet (and anything else physical) showed the melee
-- weapon's icon. Returns "pet" when your pet is on that mob, else true; nil when it may be yours.
function BT:NotYourSwing(h)
    if not self.swungAt or not h or not h.time then return nil end
    if self.meleeAt and h.time - self.meleeAt <= SWING_RECENT then return nil end
    if PetOn(h.unit) then return "pet" end
    -- (no pet on it: only while you're shooting, a ranged swing lately and no melee one)
    if h.time - self.swungAt <= SWING_RECENT then return true end
    return nil
end

-- Your Summon Hawk sent a hawk at this unit (key: UnitKey). The oldest goes when a third comes.
function BT:SendHawk(key)
    self.hawks = self.hawks or {}
    while #self.hawks >= HAWK_MOST do table.remove(self.hawks, 1) end
    self.hawks[#self.hawks + 1] = { key = key, at = GetTime() }
end

-- A hawk of yours is attacking this hit's unit
function BT:HawkOn(h)
    if not self.hawks or not h or not h.key or not h.time then return false end
    for i = #self.hawks, 1, -1 do
        local hawk = self.hawks[i]
        if h.time - hawk.at > HAWK_TIME then
            table.remove(self.hawks, i)
        elseif hawk.key == h.key and h.time > hawk.at then
            return true
        end
    end
    return false
end

-- Who an unnamed physical hit (or plain miss) that isn't your swing came from, as the mark in
-- front of it: your pet's name, or "(Hawk) " on a mob your hawk is on and your pet isn't (with
-- both on it the game doesn't say which hit was whose: it's taken for your pet's).
-- nil: yours. notYours: the Attack icon, as it isn't your weapon's.
function BT:SwingOwner(h, hand)
    if hand ~= nil then return nil end
    if self:HawkOn(h) then
        if PetOn(h.unit) then return self:PetLabel() end
        return L["(Hawk)"] .. " "
    end
    local whose = self:NotYourSwing(h)
    if whose == "pet" then return self:PetLabel() end
    if whose then return nil, true end
    return nil
end

-- In a group, a hit on a mob could be anyone's. The combat log lines can't be
-- read, but with the "My actions" filter each one is something you did. So a
-- hit is taken for yours only if a line came with it or shortly before it,
-- and each line vouches for one hit. (credits: when those lines arrived.)
function BT:NoteHiddenLine(now)
    self.hiddenSeen, self.hiddenAt = true, now
    self.dryActs, self.dryFrom = 0, nil
    local credits = self.credits or {}
    self.credits = credits
    while credits[1] and (now - credits[1] > CREDIT_TIME or #credits >= 20) do table.remove(credits, 1) end
    credits[#credits + 1] = now
    self:Queue({ line = true })
end

-- The lines can stop after they've started (another addon turns them off, the Combat Log's filter
-- changed). Then in a group nothing but your casts' own hits and your swings is vouched for: ticks,
-- spells landing later, procs went missing without a word. In a fight, LINES_DRY_ACTS casts and
-- swings of yours over LINES_DRY_TIME seconds with no line at all means they've stopped: BattleText
-- goes back to how it works before the first line, turns them on again, and the Start button shows
-- after the fight. The next line puts everything back.
local LINES_DRY_ACTS = 8
local LINES_DRY_TIME = 20
function BT:NoteAction(now)
    if not self.hiddenSeen or not Flag(InCombatLockdown) then return end
    self.dryFrom = self.dryFrom or now
    self.dryActs = (self.dryActs or 0) + 1
    if self.dryActs < LINES_DRY_ACTS or now - self.dryFrom < LINES_DRY_TIME then return end
    if self.db.debug then self:Record("LINES STOPPED: no line for " .. self.dryActs .. " casts and swings") end
    self.hiddenSeen, self.dryActs, self.dryFrom = nil, 0, nil
    self.started = nil
    self.actedInFight = true   -- (the button shows when this fight ends: CheckAutoStart)
    self:KeepLogFlowing()
end

-- Your auto attacks. PLAYER_SWING (Forever's swing timer: { swingDuration, swingType }, plain
-- values) fires for each swing of yours, landed or not. The "My actions" lines don't come for
-- every swing (issues #15, #16: white hits and the mob's dodges in a group went unshown with
-- "no line of yours with it"), so in a group each swing vouches for one physical hit or miss on
-- your target (auto attacks only ever go at your target) within CREDIT_TIME.
function BT:OnSwing(duration, swingType)
    local now = GetTime()
    if self.db.debug then self:Record("SWING " .. tostring(Num(swingType))) end
    local swings = self.swings or {}
    self.swings = swings
    while swings[1] and (now - swings[1] > CREDIT_TIME or #swings >= 6) do table.remove(swings, 1) end
    swings[#swings + 1] = now
    self.swungAt = now
    self.actedInFight = true
    self:NoteAction(now)
    -- Which hand (issue #15: off hand swings showed the main hand's icon). Ranged swings aren't kept,
    -- nor a swing that comes with a ranged attack's cast (a wand's Shoot, Auto Shot) whatever hand
    -- it says (GitHub #40: wanding, your melee weapon's icon showed up)
    local hand = Num(swingType)
    if self.rangedCastAt == now then hand = 2 end
    if hand == 0 or hand == 1 then
        local hands = self.hands or {}
        self.hands = hands
        while hands[1] and (now - hands[1].at > CREDIT_TIME or #hands >= 6) do table.remove(hands, 1) end
        hands[#hands + 1] = { at = now, hand = hand }
        if self.meleeAt ~= now then self.meleeBefore = self.meleeAt end
        self.meleeAt = now
        if hand == 1 then self.dualWield = true end
    end
end

-- A ranged attack of yours was cast (Shoot, Auto Shot): a swing in the same moment is that shot,
-- not a melee swing, even if the game said it was (OnSwing). One that came just before is undone.
function BT:RangedCast()
    local now = GetTime()
    self.rangedCastAt = now
    local hands = self.hands
    if hands and hands[#hands] and hands[#hands].at == now then
        table.remove(hands)
        if self.meleeAt == now then self.meleeAt = self.meleeBefore end
    end
end

-- Extra attacks (Windfury Weapon, GitHub #27): a blow of yours that lands can give you more swings
-- right away. They don't fire PLAYER_SWING and their hits come without a line in their own frame,
-- so with the lines on they went unshown ("no line of yours with it"), even alone. A physical hit or
-- miss on the unit you just struck, within EXTRA_TIME, is one (EXTRA_HITS a blow). Alone, nobody
-- else is on your mob. In a group it also takes a spare line of yours from the blow's own frame
-- (the proc's lines come with it), so a party member's white hit after your blow isn't yours.
function BT:OpenExtra(h)
    if not h.key or h.extra then return end
    self.extra = { key = h.key, at = h.time, left = EXTRA_HITS }
end

function BT:ClaimExtra(h)
    local e = self.extra
    if not (e and e.left > 0 and h.key == e.key) then return false end
    if h.kind ~= "damage" and h.kind ~= "miss" then return false end
    local mask = Num(h.school)
    if mask ~= nil and mask ~= 1 then return false end
    local since = h.time - e.at
    if since <= 0 or since > EXTRA_TIME then return false end
    if not h.solo then
        local credits, found = self.credits, nil
        for i = 1, #(credits or {}) do
            if credits[i] == e.at then found = i break end
        end
        if not found then return false end
        table.remove(credits, found)
    end
    e.left = e.left - 1
    h.extra = true
    return true
end

function BT:ClaimSwing(h)
    local swings = self.swings
    if not swings or not swings[1] then return false end
    local mask = Num(h.school)
    if h.kind ~= "damage" and h.kind ~= "miss" then return false end
    if mask ~= nil and mask ~= 1 then return false end
    if not (Flag(UnitIsUnit, h.unit, "target") or (h.key and h.key == UnitKey("target"))) then return false end
    while swings[1] and h.time - swings[1] > CREDIT_TIME do table.remove(swings, 1) end
    if swings[1] and swings[1] <= h.time then
        table.remove(swings, 1)
        return true
    end
    return false
end

-- A line of yours vouches for a hit in its own frame (a spell's hit, a tick, a proc, a heal: they
-- come with their line). Only a swing's line comes ahead of its hit (the hit lands with the
-- animation, up to CREDIT_TIME later), so only a physical hit or a miss may take an earlier line
-- , and not on your target while PLAYER_SWING is vouching for your swings there, unless
-- your pet is on it (its swings' lines come ahead too). Issue #16: a party member's wand and white
-- hits took the lines of your Sunder Armor, Shield Block and swings (each swing was vouched twice,
-- by PLAYER_SWING and by its line) and showed as yours.
function BT:WideClaim(h)
    if not h or not h.unit then return false end
    if h.kind ~= "damage" and h.kind ~= "miss" then return false end
    local mask = Num(h.school)
    if mask ~= nil and mask ~= 1 then return false end
    if not (self.swungAt and h.time - self.swungAt <= SWING_RECENT) then return true end
    if not (Flag(UnitIsUnit, h.unit, "target") or (h.key and h.key == UnitKey("target"))) then return true end
    return PetOn(h.unit) and true or false
end

-- A hit that your ranged attack on its way to that mob explains (a wand's Shoot, Auto Shot) is
-- yours when the shot's own line came with your cast: that line vouches for it. Since 1.21.4
-- only a line in the hit's own frame did, and a wand hit whose line came a frame later was
-- dropped (CurseForge, 1.21.5: wand damage not showing consistently). Spells keep needing a
-- line with their hit (someone else's Fire hit while your Fireball flies isn't yours).
function BT:ClaimFlight(h)
    if h.kind ~= "damage" and h.kind ~= "miss" then return false end
    local f = self:FlightFor(h)
    if not (f and f.auto) then return false end
    local credits = self.credits
    for i = 1, #(credits or {}) do
        if credits[i] >= f.at and credits[i] <= h.time then
            table.remove(credits, i)
            return true
        end
    end
    return false
end

function BT:ClaimHit(now, h)
    local credits = self.credits
    while credits and credits[1] and now - credits[1] > CREDIT_TIME do table.remove(credits, 1) end
    if not credits then return false end
    for i = 1, #credits do
        if credits[i] <= now and now - credits[i] <= LINE_WITH_HIT then
            table.remove(credits, i)
            return true
        end
    end
    if credits[1] and credits[1] <= now and self:WideClaim(h) then
        table.remove(credits, 1)
        return true
    end
    return false
end

-- Your mana as it is, and the most you can have (nil when hidden)
local function ManaNow()
    local kind = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
    local okN, n = pcall(UnitPower, "player", kind)
    local okM, most = pcall(UnitPowerMax, "player", kind)
    return okN and Num(n) or nil, okM and Num(most) or nil
end

function BT:IsLifeTap(id, name)
    for _, tapId in ipairs(LIFE_TAP) do
        if id == tapId then return true end
    end
    if not name then return false end
    return name == LIFE_TAP.name or name == SpellName(LIFE_TAP[1])
end

-- The health and mana Life Tap's description names ("Converts 200 health into 200 mana."): its
-- first two numbers (one number: both). Used when the mana bar can't say: it was full, or the
-- game hides it (issue #26, 1.27.1's debug: "LIFE TAP mana hidden" on every cast).
local function LifeTapAmounts(id)
    if not (id and C_Spell and C_Spell.GetSpellDescription) then return nil end
    local ok, text = pcall(C_Spell.GetSpellDescription, id)
    text = ok and Str(text) or nil
    if not text then return nil end
    text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    local found = {}
    for digits in text:gmatch("%d[%d,%.]*") do
        found[#found + 1] = tonumber((digits:gsub("[,%.]", "")))
        if #found == 2 then break end
    end
    return found[1], found[2] or found[1]
end

-- Your mana went up or down (UNIT_POWER_UPDATE, UNIT_POWER_FREQUENT). A rise is Life Tap's when it
-- comes up to LIFE_TAP_BEFORE before the cast's event or LIFE_TAP_TIME after it.
-- (1.27.0 took only a rise in the cast's frame or 0.5s after: in game the mana never showed.)
function BT:OnMana()
    local n, most = ManaNow()
    local was = self.manaSeen
    self.manaSeen = n
    if not n or not was or n == was then return end
    local at = GetTime()
    local tap = self.lifeTap
    if self.db.debug and tap and at - tap.at <= LIFE_TAP_TIME + 0.5 then
        self:Record("MANA " .. was .. " -> " .. n)
    end
    if n < was then return end
    local full = most ~= nil and n >= most
    if tap and not tap.done and at - tap.at <= LIFE_TAP_TIME then
        self:ShowLifeTap(tap, n - was, full, "mana event")
    else
        self.manaRise = { at = at, amount = n - was, full = full }
    end
end

function BT:LifeTapCast(id, name)
    local at = GetTime()
    local now, most = ManaNow()
    local tap = { id = id, name = name, at = at, before = now }
    self.lifeTap = tap
    local rise = self.manaRise
    self.manaRise = nil
    if self.db.debug then
        self:Record("LIFE TAP mana " .. (now and (now .. "/" .. tostring(most)) or "hidden")
            .. (rise and (" (rose " .. rise.amount .. " " .. ("%.2f"):format(at - rise.at) .. "s before)") or ""))
    end
    if rise and at - rise.at <= LIFE_TAP_BEFORE then return self:ShowLifeTap(tap, rise.amount, rise.full, "before") end
    -- The game hides your mana: the description says what it gives
    if not now then
        tap.hidden = true
        return self:ShowLifeTap(tap, nil, false, "hidden")
    end
    if not (C_Timer and C_Timer.After) then return end
    -- The mana events may not come (or not for this): the bar itself is looked at too
    local waited = 0
    local function look()
        if tap.done then return end
        waited = waited + LIFE_TAP_LOOK
        local n, top = ManaNow()
        if n and tap.before and n > tap.before then
            BT.manaSeen = n
            return BT:ShowLifeTap(tap, n - tap.before, top ~= nil and n >= top, "mana bar")
        end
        -- No mana came in (it was full already, or it's hidden): the health still went
        if waited >= LIFE_TAP_TIME - 1e-6 then return BT:ShowLifeTap(tap, nil, true, "no mana") end
        C_Timer.After(LIFE_TAP_LOOK, look)
    end
    C_Timer.After(LIFE_TAP_LOOK, look)
end

-- A line from the game for the mana (if it ever sends one) shows it instead
function BT:LifeTapLogged()
    local tap = self.lifeTap
    if tap and not tap.done and GetTime() - tap.at <= LIFE_TAP_TIME then tap.logged = true end
end

-- "-200 Life Tap" on the incoming side and "+200 Mana Life Tap" as a power gain. Your health is
-- hidden on Forever, so what it cost is taken to be the mana it gave (1:1). With your mana full,
-- the gain is cut short (or nothing), so the description's number is used if it's more.
function BT:ShowLifeTap(tap, gain, full, how)
    tap.done = true
    if self.lifeTap == tap then self.lifeTap = nil end
    if self.db.debug then
        self:Record("LIFE TAP " .. tostring(how) .. ": mana " .. tostring(gain) .. (full and " (full)" or "")
            .. (tap.logged and " (game sent its own)" or ""))
    end
    local db, C = self.db, self.TEXT_COLORS
    local rule = self:SpellRule(tap.name)
    if rule and rule.hide then return end
    local cost, gives = LifeTapAmounts(tap.id)
    if tap.hidden and not gain then gain = gives end
    local hurt = gain
    if full or not hurt then
        if cost and cost > (hurt or 0) then hurt = cost end
    end
    local icon, name = self:SpellParts("in", self:IconText(tap.id), tap.name)
    local after = SpellAfter(icon, name)
    if hurt and hurt > 0 and db.inDamage then
        self:Emit(self:Area("InDamage"), "-" .. Commas(hurt) .. after, (rule and rule.color) or C.inDamage,
            { amount = hurt })
    end
    if gain and gain > 0 and db.inPower and not tap.logged then
        local mana = Str(_G.MANA) or "Mana"
        self:Emit(self:Area("InPower"), "+" .. Commas(gain) .. " " .. mana .. after, C.power)
    end
end

-- Your own casts. A hit in the very frame a cast finishes is that spell (an
-- instant attack, a spell with no travel time). A cast of a damage-over-time
-- spell is remembered against your target, to name its ticks later.
function BT:OnSpellcast(spellId)
    local id = Num(spellId)
    local name = id and SpellName(id) or nil
    if self.db.debug then self:Record("CAST " .. tostring(id) .. " " .. tostring(Str(name))) end
    self:CastTo(id, name)
    self:NoteHelpfulCast(id, name)
    self:NoteStrangerHeal(id, name)
    self:Queue({ cast = true, id = id, name = name })
    self.actedInFight = true
    self:NoteAction(GetTime())
    if self:IsLifeTap(id, name) then self:LifeTapCast(id, name) end
    if not name then return end
    local periodic, shields = self:SpellLists()
    -- A spell that flies is on its way to your target: its hit comes later (FlightFor)
    local flight = self.flights[name] or self:RangedSpell(id)
    if self:RangedSpell(id) then self:RangedCast() end
    local flightKey = flight and UnitKey("target")
    if flightKey then
        self:ForgetOldFlights()
        self.flying = self.flying or {}
        while #self.flying >= 10 do table.remove(self.flying, 1) end
        self.flying[#self.flying + 1] = { id = id, name = name, at = GetTime(), key = flightKey,
            school = flight.school, period = flight.period, wand = flight.wand, auto = flight.auto }
        if flight.hawk then self:SendHawk(flightKey) end
    end
    -- A spell that keeps hitting for a while (AreaFor)
    if self.areaSpells[name] then self:StartArea(name, id) end
    -- Something thrown goes off where it lands, on whatever is there (ThrownFor)
    local thrown = self.thrownItems[name]
    if thrown then
        self:ForgetOldThrows()
        self.thrown = self.thrown or {}
        while #self.thrown >= 10 do table.remove(self.thrown, 1) end
        self.thrown[#self.thrown + 1] = { id = id, name = name, at = GetTime(), school = thrown.school }
    end
    local dot = periodic[name]
    -- A heal over time with no friend targeted lands on you: its ticks come as heals on you
    -- with no name (SelfHotFor)
    if dot and dot.heal and not self:HealGoesToTarget() then
        self.selfHots = self.selfHots or {}
        self.selfHots[name] = { id = id, name = name, at = GetTime(), period = dot.period, school = dot.school }
        dot = nil
    end
    local key = dot and (dot.heal and self:HelpedKey() or UnitKey("target"))   -- (a heal: on the friend it went to)
    if key then
        self.dots = self.dots or {}
        self.dots[key] = self.dots[key] or {}
        self.dots[key][name] = { id = id, name = name, at = GetTime(), period = dot.period, school = dot.school,
            heal = dot.heal, wrack = dot.wrack, flies = dot.flies, noLine = dot.noLine, lineUnsure = dot.lineUnsure }
    end
    if shields[name] then
        self.buffShields = self.buffShields or {}
        self.buffShields[name] = { name = name, id = id, school = shields[name].school }
    end
    self.lastCast = { name = name, at = GetTime(), onFriend = self:HealGoesToTarget() }
    self:NoteVigilCast(id, name)
    self:NoteFriendCast(id, name)
    self:NoteMendingCast(id, name)
    self:NoteHealCast(id, name)
    if self:IsDispelSpell(id, name) then self:DispelCast(id, name) end
    local seals = self:SealLists()
    -- In a fight your buffs are hidden: a buff you put on yourself shows as you cast it
    if not seals[name] and InCombatLockdown() and self:IsSelfBuffCast(id, name) then
        self.fightBuffs = self.fightBuffs or {}
        self.fightBuffs[name] = { name = name, id = id }
        if self.db.nBuffs then
            local icon = self.db.nIcons and self:IconText(id) or ""
            self:Notify(icon .. "+" .. name, self.TEXT_COLORS.buff)
        end
    end
    if seals[name] then
        self:SetSeal({ id = id, name = seals[name].name, school = seals[name].school })
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
            local ends, duration = Num(a.expirationTime), Num(a.duration)
            seal = { id = Num(a.spellId) or seals[name].id, name = seals[name].name, school = seals[name].school,
                duration = duration, ends = (ends and ends > 0) and ends or nil }
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
-- Weapon enchants that hurt the mob you hit, by the line they add to the weapon's tooltip
local ENCHANT_PROCS = { ["Fiery Weapon"] = 4, ["Icy Chill"] = 16, ["Lifestealing"] = 32, ["Unholy Weapon"] = 32 }
-- A rogue's poisons on a weapon, by the line the poison adds to its tooltip: its name, its
-- rank and the time left ("Instant Poison III (30 min)"). Each is named after a spell of its
-- (for the icon). dot: its damage comes as ticks after the blow that put it on the mob.
local POISONS = {
    ["Instant Poison"] = { id = 8680, school = 8 },
    ["Wound Poison"] = { id = 13218, school = 8 },
    ["Deadly Poison"] = { id = 2818, school = 8, dot = true },
}
local POISON_SPELLS = { { 8680, "Instant Poison" }, { 13218, "Wound Poison" }, { 2818, "Deadly Poison" } }
-- A temporary enchant's line without what follows its name: "(30 min)", "(59 sec)", "(1 hour)",
-- charges, and the rank ("III")
local function EnchantBase(text)
    local base = text
    repeat
        local before = base
        base = base:gsub("%s*%b()%s*$", "")
    until base == before
    return (base:gsub("%s+[IVXL]+$", ""))
end
-- A "Chance on hit" line's damage: "for 75 Fire damage", "150 to 250 Nature damage"; the most it does
local function ProcDamage(text)
    local low, high, word = text:match("(%d+) to (%d+) (%a+) damage")
    if not word then low, word = text:match("(%d+) (%a+) damage") end
    local school = word and SCHOOL_WORDS[word:lower()]
    if not school or school == 1 then return nil end
    return school, tonumber(high or low)
end
-- Putting a poison on a weapon (or it wearing off) fires UNIT_INVENTORY_CHANGED, not
-- PLAYER_EQUIPMENT_CHANGED (CurseForge, TheFarbod, 1.24.1), and the tooltips can't be read in a
-- fight (PLAYER_REGEN_DISABLED comes too late for it). The event fires for every bag change too,
-- so the gear is read once, a moment after the last of a burst.
-- The event also comes a moment before the tooltip has the new poison's line (TheFarbod's
-- tests): the read waits GEAR_SCAN_WAIT after the latest one.
local GEAR_SCAN_WAIT = 0.3
-- What you wear, in a few cheap calls: each slot's item link (its enchant is in it) and each
-- weapon's temporary enchant (a poison, an oil). Looting fires UNIT_INVENTORY_CHANGED too, and
-- every loot read every piece of gear's tooltip again: a small hitch with each item looted (a
-- player's report, 1.43.0). Now the tooltips are read only when this changed.
local function WeaponEnchantPrint(slot)
    if not (C_Item and C_Item.GetWeaponEnchantInfo) then return "" end
    local ok, enchants = pcall(C_Item.GetWeaponEnchantInfo, slot)
    if not ok or IsSecret(enchants) or type(enchants) ~= "table" then return "?" end
    local parts = {}
    for _, e in pairs(enchants) do
        if type(e) == "table" and not IsSecret(e) then
            -- (not its time or charges left: those change on their own, the tooltip's effect doesn't)
            for k, v in pairs(e) do
                if type(k) == "string" and not k:find("xpir") and not k:find("harge") and not k:find("ime")
                        and not IsSecret(v) and (type(v) == "number" or type(v) == "boolean" or type(v) == "string") then
                    parts[#parts + 1] = k .. "=" .. tostring(v)
                end
            end
        end
    end
    table.sort(parts)
    return table.concat(parts, ",")
end
function BT:GearPrint()
    local parts = {}
    for slot = 1, 19 do
        local ok, link = pcall(GetInventoryItemLink or function() end, "player", slot)
        parts[slot] = ok and Str(link) or (ok and link == nil and "" or "?")
    end
    parts[20], parts[21] = WeaponEnchantPrint(0), WeaponEnchantPrint(1)
    return table.concat(parts, "\n")
end

function BT:RescanGearSoon()
    self.gearScanAt = GetTime() + GEAR_SCAN_WAIT
    if self.gearScanPending then return end
    if not (C_Timer and C_Timer.After) then self:ScanItemShields() return end
    self.gearScanPending = true
    local function check()
        local left = (self.gearScanAt or 0) - GetTime()
        if left > 0.01 then C_Timer.After(left, check) return end
        self.gearScanPending = nil
        -- (nothing you wear changed: a looted item, a potion drunk. A print it couldn't read in
        -- full, "?", always reads the gear)
        local gearNow = self:GearPrint()
        if gearNow == self.gearPrint and not gearNow:find("?", 1, true) then return end
        self:ScanItemShields()
    end
    C_Timer.After(GEAR_SCAN_WAIT, check)
end

-- The icon the game shows for the poison on a weapon (its buff by the minimap), for when the
-- poison's spell gives none: C_Item.GetWeaponEnchantInfo (Enum.WeaponSlot: 0 main hand, 1 off hand)
local function PoisonIcon(slot)
    if not (C_Item and C_Item.GetWeaponEnchantInfo) then return nil end
    local ok, enchants = pcall(C_Item.GetWeaponEnchantInfo, slot - 16)
    if not ok or IsSecret(enchants) or type(enchants) ~= "table" then return nil end
    for _, e in pairs(enchants) do
        if type(e) == "table" and e.hasEnchant == true and Num(e.enchantIconID) and e.enchantIconID > 0 then
            return e.enchantIconID
        end
    end
    return nil
end
-- Gear that adds a set amount to every hit, known by its item ID: the tooltip is read in English
-- only, so on any other client (GitHub #25, 1.27.1: a Russian client) the Eye was never known
-- and its 2 always showed. The tooltip's first line still gives the name in the game's language.
local EVERY_ITEMS = {
    [273840] = { name = "Cursed Murloc Eye", school = 32, amount = 2, times = 4, versus = "Murloc" },
    [274159] = { name = "Thorncursed Grips", school = 8, amount = 2, melee = true },
}

-- Reading gear in any language (1.29.0). The game marks an item's effect lines itself: by the
-- line's type (Enum.TooltipDataLineType) or by its label, which the game translates
-- (ITEM_SPELL_TRIGGER_ONEQUIP "Equip:", ITEM_SPELL_TRIGGER_ONPROC "Chance on hit:"). Numbers
-- are the same in every language. What's left to know is the school, and for gear that hits
-- back, that it hurts the attacker: a word for each, per language, as the tooltips write them.
local LINE_ON_EQUIP, LINE_ON_PROC = 45, 46   -- (ItemSpellTriggerOnEquip, ItemSpellTriggerOnProc)
local LOCAL_SCHOOLS = {
    deDE = { { "Heilig", 2 }, { "Feuer", 4 }, { "Natur", 8 }, { "Frost", 16 }, { "Schatten", 32 }, { "Arkan", 64 } },
    frFR = { { "Sacré", 2 }, { "Feu", 4 }, { "Nature", 8 }, { "Givre", 16 }, { "Ombre", 32 }, { "Arcane", 64 } },
    esES = { { "Sagrado", 2 }, { "Fuego", 4 }, { "Naturaleza", 8 }, { "Escarcha", 16 }, { "Sombra", 32 }, { "Arcano", 64 } },
    ptBR = { { "Sagrado", 2 }, { "Fogo", 4 }, { "Natureza", 8 }, { "Gélido", 16 }, { "Gelo", 16 }, { "Sombra", 32 },
        { "Arcano", 64 } },
    itIT = { { "Sacro", 2 }, { "Fuoco", 4 }, { "Natura", 8 }, { "Gelo", 16 }, { "Ombra", 32 }, { "Arcano", 64 } },
    ruRU = { { "светл", 2 }, { "огн", 4 }, { "природ", 8 }, { "льд", 16 }, { "темн", 32 }, { "тайн", 64 } },
    koKR = { { "신성", 2 }, { "화염", 4 }, { "자연", 8 }, { "냉기", 16 }, { "암흑", 32 }, { "비전", 64 } },
    zhCN = { { "神圣", 2 }, { "火焰", 4 }, { "自然", 8 }, { "冰霜", 16 }, { "暗影", 32 }, { "奥术", 64 } },
    zhTW = { { "神聖", 2 }, { "火焰", 4 }, { "自然", 8 }, { "冰霜", 16 }, { "暗影", 32 }, { "秘法", 64 } },
}
LOCAL_SCHOOLS.esMX = LOCAL_SCHOOLS.esES
local LOCAL_ATTACKER = {
    deDE = { "Angreifer" }, frFR = { "attaquant" }, esES = { "atacante", "agresor" }, ptBR = { "atacante", "agressor" },
    itIT = { "attaccante", "aggressore" }, ruRU = { "атакующ", "нападающ" }, koKR = { "공격자" },
    zhCN = { "攻击者" }, zhTW = { "攻擊者" },
}
LOCAL_ATTACKER.esMX = LOCAL_ATTACKER.esES
local function Locale() return GetLocale and Str(GetLocale()) or "enUS" end
local function Has(text, word)
    return text:find(word, 1, true) ~= nil or text:lower():find(word:lower(), 1, true) ~= nil
end
-- The one school a line names in the game's language (none, or two: nil)
local function LocalSchool(text)
    local found
    for _, e in ipairs(LOCAL_SCHOOLS[Locale()] or {}) do
        if Has(text, e[1]) then
            if found and found ~= e[2] then return nil end
            found = e[2]
        end
    end
    return found
end
local function Numbers(text)
    local out = {}
    for digits in text:gmatch("%d+") do out[#out + 1] = tonumber(digits) end
    return out
end
-- What kind of effect line this is ("equip", "proc"), and its text after the label
local function GearLine(row, text)
    local kind = type(row) == "table" and Num(row.type)
    local types = Enum and Enum.TooltipDataLineType
    if kind and kind == ((types and types.ItemSpellTriggerOnEquip) or LINE_ON_EQUIP) then kind = "equip"
    elseif kind and kind == ((types and types.ItemSpellTriggerOnProc) or LINE_ON_PROC) then kind = "proc"
    else kind = nil end
    for _, e in ipairs({ { Str(ITEM_SPELL_TRIGGER_ONPROC), "proc" }, { Str(ITEM_SPELL_TRIGGER_ONEQUIP), "equip" },
            { "Chance on hit:", "proc" }, { "Equip:", "equip" } }) do
        local label = e[1]
        if label and text:sub(1, #label) == label then
            return kind or e[2], (text:sub(#label + 1):gsub("^%s+", ""))
        end
    end
    return kind, text
end
-- A poison by the name its line shows, in any language: the poison's own spell names it
local function PoisonNamed(base)
    if POISONS[base] then return POISONS[base], base end
    for english, poison in pairs(POISONS) do
        if SpellName(poison.id) == base then return poison, english end
    end
    return nil
end

local SCHOOL_NAMES = { [2] = "Holy", [4] = "Fire", [8] = "Nature", [16] = "Frost", [32] = "Shadow", [64] = "Arcane" }
-- report: a list to fill with what each item's lines were taken for (/btf gear)
function BT:ScanItemShields(report)
    if not (C_TooltipInfo and C_TooltipInfo.GetInventoryItem) then return end
    if InCombatLockdown() then return end
    local english = IsEnglish()
    local found, procs = {}, {}
    local complete = true
    local function note(text) if report then report[#report + 1] = "    " .. text end end
    for slot = 1, 19 do
        local ok, data = pcall(C_TooltipInfo.GetInventoryItem, "player", slot)
        local rows = ok and not IsSecret(data) and type(data) == "table" and data.lines
        local name, everyRead
        local okId, itemID = pcall(GetInventoryItemID or function() end, "player", slot)
        itemID = okId and Num(itemID) or nil
        if type(rows) == "table" then
            for _, row in ipairs(rows) do
                local text = type(row) == "table" and Str(row.leftText) or nil
                if not text and type(row) == "table" and type(row.args) == "table" then
                    -- (an older shape of the same data: the text is among the line's "args")
                    for _, arg in ipairs(row.args) do
                        if type(arg) == "table" and arg.field == "leftText" then text = Str(arg.stringVal) end
                    end
                end
                -- (without color codes: the game colors a weapon's poison line, "|cff00ff00Instant
                -- Poison III (30 min)|r", CurseForge 1.24.1)
                if text then text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
                if text then
                    if not name then
                        name = text   -- the first line is the item's name
                        if report then
                            report[#report + 1] = ("slot %d: %s (item %s)"):format(slot, text, tostring(itemID))
                            local getSpell = C_Item and C_Item.GetFirstTriggeredSpellForItem
                            local okQ, quality = pcall(C_Item and C_Item.GetItemQualityByID or function() end, itemID)
                            if getSpell and itemID and okQ and Num(quality) then
                                local okS, spellID = pcall(getSpell, itemID, quality)
                                if okS and Num(spellID) then
                                    note(("its spell: %d %s"):format(spellID, tostring(SpellName(spellID))))
                                end
                            end
                        end
                    end
                    local kind, body = GearLine(row, text)
                    local took
                    local amount, school = text:match("[Ii]nflicts (%d+) (%a+) damage to the attacker")
                    school = school and SCHOOL_WORDS[school:lower()]
                    -- (in another language: an Equip line naming the attacker, a school and one number)
                    if not school and not english and kind == "equip" then
                        local nums = Numbers(body)
                        local hurtsAttacker = false
                        for _, word in ipairs(LOCAL_ATTACKER[Locale()] or {}) do
                            if Has(body, word) then hurtsAttacker = true end
                        end
                        if hurtsAttacker and #nums == 1 then school, amount = LocalSchool(body), nums[1] end
                    end
                    local okIcon, icon = pcall(GetInventoryItemTexture, "player", slot)
                    icon = okIcon and (Num(icon) or Str(icon)) or nil
                    if school then
                        found[#found + 1] = { name = name, amount = tonumber(amount), school = school, icon = icon }
                        took = ("hits back: %s %s"):format(tostring(amount), SCHOOL_NAMES[school] or school)
                    end
                    -- What it does to the mob you hit: named after the item (or the enchant)
                    local proc = text:match("^Chance on hit: (.+)") or text:match("^Equip: Chance on hit: (.+)")
                    local procSchool, most
                    if proc then procSchool, most = ProcDamage(proc) end
                    if not procSchool and not english and kind == "proc" then
                        -- (in another language: the school's word, and the most it does from its numbers)
                        local nums = Numbers(body)
                        procSchool = nums[1] and LocalSchool(body)
                        if procSchool then most = math.max(nums[1], nums[2] or 0) end
                    end
                    local poison, poisonName
                    if (slot == 16 or slot == 17) then poison, poisonName = PoisonNamed(EnchantBase(text)) end
                    if procSchool then
                        procs[#procs + 1] = { name = name, school = procSchool, most = most, icon = icon }
                        took = ("chance on hit: %s, up to %s"):format(SCHOOL_NAMES[procSchool] or procSchool, tostring(most))
                    elseif ENCHANT_PROCS[text] then
                        procs[#procs + 1] = { name = text, school = ENCHANT_PROCS[text], icon = icon }
                        took = "weapon enchant"
                    elseif poison then
                        local base = EnchantBase(text)
                        procs[#procs + 1] = { name = base, id = poison.id, school = poison.school,
                            poison = true, dot = poison.dot, slot = slot, icon = PoisonIcon(slot) }
                        took = "poison: " .. poisonName
                    end
                    -- Gear that adds a set amount to every hit (Cursed Murloc Eye: "Equip: Spells and
                    -- attacks deal 2 Shadow damage. Deals 4 times as much damage to Murlocs.")
                    -- Or only to your weapon blows (Thorncursed Grips: "Equip: Your melee weapon attacks
                    -- deal 2 Nature damage to both you and your target.")
                    local each, word = text:match("[Ss]pells and attacks deal (%d+) (%a+) damage")
                    local melee = false
                    if not word then
                        each, word = text:match("[Mm]elee weapon attacks deal (%d+) (%a+) damage")
                        melee = word ~= nil
                    end
                    local eachSchool = word and SCHOOL_WORDS[word:lower()]
                    if eachSchool and eachSchool ~= 1 then
                        local times, versus = text:match("(%d+) times as much damage to (%a+)")
                        procs[#procs + 1] = { name = name, school = eachSchool, icon = icon, every = true,
                            melee = melee or nil, amount = tonumber(each), times = tonumber(times),
                            versus = versus and versus:gsub("s$", "") }
                        everyRead = true
                        took = "every hit"
                    end
                    if report and (kind or took) and text ~= name then
                        note(("%s%s -> %s"):format(kind and (kind .. ": ") or "", text, took or "not understood"))
                    end
                end
            end
        end
        if itemID and not name then complete = false end
        -- (not read from the tooltip: known by its ID, in any language)
        local known = itemID and EVERY_ITEMS[itemID]
        if known and not everyRead then
            local okIcon, icon = pcall(GetInventoryItemTexture, "player", slot)
            procs[#procs + 1] = { name = name or known.name, school = known.school, every = true,
                icon = okIcon and (Num(icon) or Str(icon)) or nil, melee = known.melee,
                amount = known.amount, times = known.times, versus = known.versus }
            note("every hit (known by its item ID)")
        end
    end
    self.itemShields = found
    self.itemProcs = procs
    -- What was read, so a loot that changes none of it doesn't read it all again (RescanGearSoon).
    -- Not when an item's tooltip was still empty (its data not loaded yet): the next change reads it.
    self.gearPrint = complete and self:GearPrint() or nil
end

-- /btf gear: what BattleText read from each item you wear, for a player to paste in a bug report
function BT:ReportGear()
    if InCombatLockdown() then Print(L["gear can't be read in a fight. Try again after it."]) return end
    local report = { "game language " .. Locale() }
    self:ScanItemShields(report)
    self.recorded = {}
    for _, text in ipairs(report) do self:Record(text) end
    Print(L["gear read. Type /btf copy to copy what was found."])
    return report
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

-- Damage-over-time spells long since ticked out, on mobs that may be long gone
function BT:ForgetOldDots()
    local now = GetTime()
    for key, list in pairs(self.dots or {}) do
        for name, dot in pairs(list) do
            if now - dot.at > DOT_TIME then list[name] = nil end
        end
        if next(list) == nil then self.dots[key] = nil end
    end
    -- The units you struck: only the last few seconds matter (a seal or a proc right after)
    for key, at in pairs(self.struck or {}) do
        if now - at > 10 then self.struck[key] = nil end
    end
    for key, at in pairs(self.fought or {}) do
        if now - at > FOUGHT_TIME then self.fought[key] = nil end
    end
    for id, list in pairs(self.unnamed or {}) do
        if now - list[#list] > UNNAMED_KEEP then self.unnamed[id] = nil end
    end
    self:ForgetOldFlights()
    self:ForgetOldThrows()
end

-- The damage-over-time spell of yours whose tick this hit is: one you cast on
-- that unit, on its beat now (so many periods after the cast, or after its last tick), of
-- the hit's school. It ticks once a beat: a hit just after its tick isn't another one
-- (issue #20: a Shadow Bolt landing 0.1s after Bane of Agony ticked). close: against a
-- spell of yours landing, a dot that has ticked must be closer to its beat (TICK_CLOSE).
function BT:TickFor(h, close, noLineOnly)
    local dots = h.key and self.dots and self.dots[h.key]
    if not dots or (h.kind ~= "damage" and h.kind ~= "heal") then return nil end
    local mask = Num(h.school)
    local best, bestOff
    local wracking = self:Wracking(h.key, h.time)
    for name, dot in pairs(dots) do
        if h.time - dot.at > DOT_TIME then
            dots[name] = nil
        elseif noLineOnly and not dot.noLine then
            -- (only the ones the game sends no line for: SilentTick)
        else
            -- (under Wrack, twice as fast)
            local period = (dot.wrack and wracking) and dot.period / 2 or dot.period
            local since = h.time - (dot.last or dot.at)
            local beats = math.floor(since / period + 0.5)
            local off = math.abs(since - beats * period)
            local slack = (close and dot.last) and TICK_CLOSE or TICK_SLACK
            -- (before its first tick, one that flies ticks late by however long it took to land)
            if dot.flies and not dot.last and since >= period then
                local late = since - math.floor(since / period) * period
                if late <= STING_FLIGHT + slack then beats, off = math.floor(since / period), 0 end
            end
            if beats >= 1 and off <= slack and (h.kind == "heal") == dot.heal
                    and (dot.heal and SameHealSchool(mask, dot.school) or not mask or InSchool(mask, dot.school))
                    and (not best or off < bestOff) then
                best, bestOff = dot, off
            end
        end
    end
    return best
end

-- A tick of a damage over time the game sends no line for (NO_LINE_DOTS: Rip), on its beat: a
-- physical hit, plain or critical (a glance or a block is a swing), while the spell lasts, no more
-- ticks than it has. Its beat goes first, before a swing of yours can take the hit (GitHub #30,
-- after 1.32.2: a Rip tick landing between a swing and the swing's own hit was taken for the swing),
-- and whatever other damage over time is on its beat too (a Rake tick in the same frame).
function BT:SilentTick(h)
    if h.kind ~= "damage" or not (h.flag == nil or h.flag == "" or h.flag == "CRITICAL") then return nil end
    local mask = Num(h.school)
    if mask ~= nil and mask ~= 1 then return nil end
    local dot = self:TickFor(h, true, true)
    if not dot or h.time - dot.at > dot.noLine + TICK_SLACK then return nil end
    -- (its ticks came with their lines on this game: a hit on its beat without one isn't a tick)
    if dot.lineUnsure then
        if self.tickLines and (self.tickLines[dot.name] or 0) >= 2 then return nil end
        -- (and only right on its beat, its first tick too: a swing 0.22s ahead of a Rake tick with
        -- its line was taken for the tick, real_fight2.txt)
        local since = h.time - (dot.last or dot.at)
        if math.abs(since - math.floor(since / dot.period + 0.5) * dot.period) > TICK_CLOSE then return nil end
    end
    if (dot.silent or 0) >= math.floor(dot.noLine / dot.period + 0.5) then return nil end
    if dot.sameTicks and dot.tick and h.n and h.n ~= dot.tick then return nil end
    return dot
end

-- A line in this frame that something else in it accounts for: a damage shield or gear of yours
-- answering a blow (Thorns, the Spiked Shell Band: their Nature hits come in the line's frame) or a
-- heal on you (Thrill of Adventure). It isn't a tick's own line. Tyler's druid log (1.47.2,
-- tests/real_fight11.txt): such lines landing in the frame of a hit on Rake's beat were counted as
-- Rake's ticks coming with their lines (BT.tickLines); after two, its beat stopped naming its ticks
-- for the rest of the session, and every tick showed as a plain white hit.
local function LineAccounted(seq, first, last, i)
    for j = first, last do
        local o = seq[j]
        if j ~= i and o.hit then
            local mask = Num(o.school)
            if o.kind == "heal" or (o.kind == "damage" and mask ~= nil and mask ~= 1) then return true end
        end
    end
    return false
end
-- Right on a damage over time's beat (TICK_CLOSE), counted from its last tick or its cast
local function OnStrictBeat(h, dot)
    local since = h.time - (dot.last or dot.at)
    local beats = math.floor(since / dot.period + 0.5)
    return beats >= 1 and math.abs(since - beats * dot.period) <= TICK_CLOSE
end

-- A melee crit of yours (a swing, or a physical blow you cast; not a shot) with the Deep Wounds
-- talent: the mob bleeds for DEEP_WOUNDS' time, starting over on each crit. Its ticks are named
-- like any bleed of yours: by the line behind them, or by their beat when they have none (as Rake,
-- switched off once two ticks came with their lines). After its first tick, a hit for another
-- amount isn't one (its ticks are all alike): a swing that lands on its beat stays a swing.
function BT:NoteDeepWound(h, swing, spell)
    if h.kind ~= "damage" or not h.crit or not h.key then return end
    local mask = Num(h.school)
    if mask ~= nil and mask ~= 1 then return end
    if not swing and not (spell and not spell.auto and not self:IsRangedName(spell.name)) then return end
    if not self:KnowsSpell(DEEP_WOUNDS[1]) then return end
    local name = SpellName(DEEP_WOUNDS[2]) or DEEP_WOUNDS[3]
    self.dots = self.dots or {}
    self.dots[h.key] = self.dots[h.key] or {}
    self.dots[h.key][name] = { id = DEEP_WOUNDS[2], name = name, at = h.time, period = DEEP_WOUNDS[4], school = 1, heal = false,
        noLine = DEEP_WOUNDS[5], lineUnsure = true, sameTicks = true }
end

-- Ways a spell can fail to hurt that a swing can't (so a miss of that kind is a spell's)
local SPELL_MISSES = { RESIST = true, IMMUNE = true, REFLECT = true }

-- A plain hit: no crit, and nothing taken off it (blocked, resisted, absorbed)
local function PlainHit(h)
    return not h.crit and (h.flag == nil or h.flag == "")
end

-- What a spell that flies has hit for, at the least (by rank: self.flightLeast[id]), from
-- its plain hits. A plain hit for much less is something else landing meanwhile (a mage's
-- Ignite, a shaman's Lightning Shield answering a blow).
local FLIGHT_SHORT = 0.6
function BT:NoteFlightHit(id, h)
    if not id or h.kind ~= "damage" or not h.n or not PlainHit(h) then return end
    self.flightLeast = self.flightLeast or {}
    local least = self.flightLeast[id]
    if not least or h.n < least then self.flightLeast[id] = h.n end
end

-- Hits of yours that nothing named, by unit and school: a damage over time BattleText has no
-- name for (a talent's, like a warlock's Demonic Brand) shows up as such hits on a steady beat.
-- Issue #21: one ticked 0.1s after Bane of Agony while a Shadow Bolt was on its way, was taken
-- for the bolt, and the bolt itself landed with no name.
function BT:NoteUnnamed(h)
    if h.kind ~= "damage" or not h.key then return end
    -- (your pet's and hawks' blows aren't: with them on the mob, physical hits came so thick that
    -- every shot seemed on such a beat and none was named, GitHub #41)
    if h.petSwing then return end
    self.unnamed = self.unnamed or {}
    local id = h.key .. ":" .. tostring(Num(h.school))
    local list = self.unnamed[id] or {}
    self.unnamed[id] = list
    list[#list + 1] = h.time
    while list[1] and h.time - list[1] > UNNAMED_KEEP do table.remove(list, 1) end
end

-- Whether this hit is on the beat of earlier unnamed hits of its school on its unit: two of them
-- a period apart (BEAT_LEAST to BEAT_MOST), and this one a period or two after the later one,
-- within TICK_CLOSE. Then it's that unknown tick again, not a spell of yours landing.
function BT:OnUnnamedBeat(h)
    local list = self.unnamed and h.key and self.unnamed[h.key .. ":" .. tostring(Num(h.school))]
    if not list then return false end
    for j = #list, 2, -1 do
        local later = list[j]
        local since = h.time - later
        if since > 0 and since <= 2 * BEAT_MOST + TICK_CLOSE then
            for i = j - 1, 1, -1 do
                local period = later - list[i]
                if period >= BEAT_LEAST and period <= BEAT_MOST then
                    local beats = math.floor(since / period + 0.5)
                    if beats >= 1 and beats <= 2 and math.abs(since - beats * period) <= TICK_CLOSE then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- The spell of yours on its way to this hit's unit that this hit is: the oldest one cast
-- at it in the last FLIGHT_TIME seconds, before this frame, of the hit's school. A miss
-- is one only if it's of the spell's school or a way only spells miss (resisted, immune).
-- Returns the flight and where it is in self.flying.
-- A line of yours just ahead of this moment (or with it)
function BT:LineJustBefore(at)
    for _, c in ipairs(self.credits or {}) do
        if c <= at and at - c <= LINE_WITH_HIT then return true end
    end
    return false
end

function BT:FlightFor(h)
    local list = self.flying
    if not list or not h.key or (h.kind ~= "damage" and h.kind ~= "miss") then return nil end
    local mask = Num(h.school)
    local how = h.action == "WOUND" and h.flag or h.action
    -- A physical shot (Auto Shot, Aimed Shot, a hawk's dive) at a mob your pet is on: the pet's
    -- blows are physical too, and the first one after your shot took the shot's name (GitHub #41,
    -- a hunter's log: the pet's dodge named Auto Shot, its parry Aimed Shot, and the shot itself
    -- landed after as the pet's). Once the lines are arriving, your shot's hit comes with its
    -- line and the pet's don't: only a hit with a line of yours just ahead of it is the shot's.
    local petsToo = self.hiddenSeen and PetOn(h.unit)
    -- (only a melee auto attack glances: your pet's or a hawk's blow, never a shot or a spell)
    if how == "GLANCING" then return nil end
    for i, f in ipairs(list) do
        if f.key == h.key and h.time > f.at and h.time - f.at <= FLIGHT_TIME
                and not (petsToo and not f.wand and f.school == 1 and not self:LineJustBefore(h.time)) then
            if h.kind == "damage" then
                -- (what a damage shield of yours does is the shield's)
                local least = self.flightLeast and self.flightLeast[f.id]
                local short = least and h.n and PlainHit(h) and h.n < least * FLIGHT_SHORT
                if FlightSchool(f, mask) and not short and not self:KnownShield(h) then return f, i end
            elseif FlightSchool(f, mask) or SPELL_MISSES[how or ""] then
                return f, i
            end
        end
    end
    return nil
end

-- A spell on its way named a hit: it's landed. One that leaves something burning
-- (Fireball, Pyroblast) ticks from now on.
function BT:Landed(f, at, h)
    table.remove(self.flying, at)
    if f.period and h.kind == "damage" and h.key then
        self.dots = self.dots or {}
        self.dots[h.key] = self.dots[h.key] or {}
        self.dots[h.key][f.name] = { id = f.id, name = f.name, at = h.time, period = f.period, school = f.school,
            heal = false }
    end
end

-- A spell that flies named a hit in its cast's own frame: that one needed no time to get there,
-- or it was the one before it landing. Either way the oldest still on its way there has landed.
function BT:TakeFlight(name, key)
    for i, f in ipairs(self.flying or {}) do
        if f.name == name and f.key == key then
            table.remove(self.flying, i)
            return
        end
    end
end

-- Spells that never landed (the mob died, or you were out of sight)
function BT:ForgetOldFlights()
    local list, now = self.flying, GetTime()
    if not list then return end
    for i = #list, 1, -1 do
        if now - list[i].at > FLIGHT_TIME then table.remove(list, i) end
    end
end

-- Something you threw that this hit is: the oldest one thrown in the last THROW_TIME
-- seconds, before this frame, of the hit's school, on any unit (it hits all those where
-- it goes off). Once it has hit something, it's good for the rest of that frame only.
-- A miss is one only if it's of its school or a way only spells miss.
function BT:ThrownFor(h)
    local list = self.thrown
    if not list or (h.kind ~= "damage" and h.kind ~= "miss") then return nil end
    local mask = Num(h.school)
    local how = h.action == "WOUND" and h.flag or h.action
    for i = #list, 1, -1 do   -- gone off in an earlier frame: done
        if list[i].landed and list[i].landed ~= h.time then table.remove(list, i) end
    end
    for _, t in ipairs(list) do
        if h.time > t.at and h.time - t.at <= THROW_TIME then
            local fits
            if h.kind == "damage" then
                fits = mask ~= nil and mask == t.school and not self:KnownShield(h)
            else
                fits = (mask ~= nil and mask == t.school) or SPELL_MISSES[how or ""] == true
            end
            if fits then return t end
        end
    end
    return nil
end

-- A spell that keeps hitting (AREA_SPELLS) started: from your cast, or from a channel starting.
-- One of each at a time (cast again, it starts again). A channel's end comes from the game
-- when it can be read (UnitChannelInfo), else the longest it lasts; StopArea ends it early.
function BT:StartArea(name, id)
    local spell = self.areaSpells[name]
    if not spell then return end
    local now = GetTime()
    local ends = now + spell.time
    local old = self.areaOn and self.areaOn[name]
    if old and now - old.at < 0.5 then return end   -- the channel's start and its cast: one
    if spell.how and UnitChannelInfo then
        local ok, _, _, _, _, endMs = pcall(UnitChannelInfo, "player")
        endMs = ok and Num(endMs) or nil
        if endMs and endMs / 1000 > now then ends = math.min(ends, endMs / 1000) end
    end
    local key, heal, single, onSelf = nil, spell.how == "heal", spell.how == "single", nil
    if single then key = UnitKey("target") end
    if spell.how == "either" then
        single = true
        if self:HealGoesToTarget() then
            key, heal = self:HelpedKey(), true
        elseif Flag(UnitCanAttack, "player", "target") then
            key, heal = UnitKey("target"), false
        else
            key, heal, onSelf = UnitKey("player") or "player", true, true
        end
    end
    self.areaOn = self.areaOn or {}
    self.areaOn[name] = { id = id or spell.id, name = name, school = spell.school, at = now, ends = ends + AREA_SLACK,
        key = key, heal = heal, single = single, onSelf = onSelf, speeds = spell.speeds }
end

-- Whether you're channeling Wrack at this unit (its own end, not the slack after it)
function BT:Wracking(key, at)
    for _, a in pairs(self.areaOn or {}) do
        if a.speeds and a.key == key and at >= a.at and at <= a.ends - AREA_SLACK then return true end
    end
    return false
end

-- Your channel stopped (finished, or you moved): what's already on its way still lands
function BT:StopArea(id)
    local name = id and SpellName(id)
    local on = name and self.areaOn and self.areaOn[name]
    if on and on.ends > GetTime() + AREA_SLACK then on.ends = GetTime() + AREA_SLACK end
end

-- A heal of yours ticking on a group member (a heal over time on its beat, a channel's heal) that
-- came with no line: its line can come a frame or two late (issue #29: a Renew tick showed as "no
-- line of yours with it", the next one was named). It waits LATE_LINE for one; a line that comes
-- in that time vouches for it, else it's dropped as before.
local LATE_LINE = 0.25
function BT:WaitForLine(h)
    local dot = self:TickFor(h)
    local spell = dot or self:AreaFor(h)
    if not spell then return false end
    local function over()
        local credits, found = BT.credits, nil
        for i = 1, #(credits or {}) do
            if credits[i] > h.time and credits[i] - h.time <= LATE_LINE then found = i break end
        end
        local why
        if found then
            table.remove(credits, found)
            if dot then
                dot.tick = h.n or dot.tick
                dot.last = h.time
            end
            why = BT:ShowUnitHit(h, "tick", spell)
        else
            why = "no line of yours with it"
        end
        if BT.db.debug then
            BT:Record(("  %s %s: %s"):format(h.unit, h.secret and "(hidden amount)" or AmountText(h.amount),
                why or ("tick of " .. tostring(spell.name) .. ", its line late")), h.time)
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(LATE_LINE, over) else over() end
    return true
end

-- A channel of yours healing you (Penance with no friend or enemy targeted): a heal on you while it lasts
function BT:SelfAreaFor(at, school)
    for _, a in pairs(self.areaOn or {}) do
        if a.onSelf and at >= a.at and at <= a.ends and SameHealSchool(school, a.school) then return a end
    end
    return nil
end

-- The spell of yours still hitting that this hit is: of its school, while it lasts, on any
-- unit (on the one you channel at, for Arcane Missiles and the like). A heal for a heal.
-- splash: a mob that isn't after you (only an area spell reaches those).
function BT:AreaFor(h, splash)
    local list = self.areaOn
    if not list or (h.kind ~= "damage" and h.kind ~= "miss" and h.kind ~= "heal") then return nil end
    local mask = Num(h.school)
    local how = h.action == "WOUND" and h.flag or h.action
    local best
    for name, a in pairs(list) do
        if h.time > a.ends then
            list[name] = nil
        elseif h.time >= a.at and (h.kind == "heal") == a.heal and not (a.single and (splash or a.key ~= h.key)) then
            local fits
            if h.kind == "miss" then
                fits = (mask ~= nil and mask == a.school) or SPELL_MISSES[how or ""] == true
            else
                fits = mask ~= nil and mask == a.school and not (h.kind == "damage" and self:KnownShield(h))
                -- (a heal on someone may come with no school or Physical: see SameHealSchool)
                if h.kind == "heal" then fits = SameHealSchool(mask, a.school) end
            end
            if fits and (not best or a.at > best.at) then best = a end
        end
    end
    return best
end

-- Your weapons' and gear's "Chance on hit" (self.itemProcs, read from the tooltips with the
-- damage shields): a hit of its school, not too big for it, on a unit you struck with a
-- weapon in this frame or just before (a bolt it sends can take a moment to land).
-- Poisons (CurseForge, 1.24.0: a rogue's poison damage showed as plain numbers): Instant and
-- Wound Poison hit like a proc; Deadly Poison ticks every 3s for 12s after the blow that put it
-- on, so its hits come long after any swing. With both on (Instant in one hand, Deadly in the
-- other, both Nature), a hit beside your blow in this frame is Instant's; any other is a Deadly tick.
local PROC_TIME = 1.5
local POISON_LASTS = 12.5   -- Deadly Poison's ticks come up to this long after your last blow on the mob
function BT:ProcFor(h, seq, first, last, at)
    local procs = self.itemProcs
    if not procs or #procs == 0 or h.kind ~= "damage" then return nil end
    local mask = Num(h.school)
    if not mask or mask == 1 then return nil end
    local struck = h.key and self.struck and self.struck[h.key]
    local since = struck and h.time - struck
    local inFrame = false
    for j = first, last do
        local o = seq[j]
        if j ~= at and o.hit and not o.splash and o.kind == "damage" and Num(o.school) == 1
                and ((h.key and o.key == h.key) or (not h.key and o.unit == h.unit)) then
            inFrame = true
            break
        end
    end
    local near = inFrame or (since and since >= 0 and since <= PROC_TIME)
    local onHit, dot
    for _, p in ipairs(procs) do
        if not p.every and p.school == mask and not (p.most and h.n and h.n > p.most * (h.crit and 1.6 or 1.05)) then
            if p.dot then
                dot = dot or p
            elseif not onHit or (p.poison and not onHit.poison) then
                onHit = p   -- (a poison before a weapon's own Nature proc: it goes off far more often)
            end
        end
    end
    local dotNear = dot and (inFrame or (since and since >= 0 and since <= POISON_LASTS))
    local pick
    -- With Deadly Poison on too, only a hit in your blow's own frame is the on-hit one: Deadly's
    -- first tick has no beat to go by yet, and can land within PROC_TIME of a blow (TheFarbod's tests)
    if onHit and near and (inFrame or not dotNear) then
        pick = onHit
    elseif dotNear then
        pick = dot
    end
    return pick
end

-- Gear that adds a set amount of a magic school to each of your hits (self.itemProcs with
-- every: Cursed Murloc Eye's 2 Shadow). Its hit comes beside one of yours on the same mob, in
-- the same frame or just after your swing. Its amount is known even when the game hides it, so
-- "Hide hits below" can catch it (CurseForge, 1.21.5: the Eye's 2 showed with it set to 5). Two
-- hidden hits of its school beside each other can't be told apart, so then neither is it.
-- The gear (self.itemProcs with every) a hit can be, by its school and (when readable) its
-- amount, whatever is beside it: { name, icon, school, fixed, melee }
function BT:EveryOn(h)
    local procs = self.itemProcs
    if not procs or h.kind ~= "damage" then return nil end
    local mask = Num(h.school)
    if not mask or mask == 1 then return nil end
    for _, item in ipairs(procs) do
        if item.every and item.school == mask then
            -- How much it does to this mob: more to some kinds ("4 times as much damage to Murlocs")
            local fixed = item.amount
            if item.times and item.versus and UnitCreatureType then
                local ok, kind = pcall(UnitCreatureType, h.unit)
                if ok and Str(kind) == item.versus then fixed = item.amount * item.times end
            end
            if not h.n or h.n == fixed or (item.times and h.n == item.amount * item.times) then
                return { name = item.name, icon = item.icon, school = item.school, fixed = h.n or fixed,
                    melee = item.melee }
            end
        end
    end
    return nil
end

-- Its hit beside one of yours (in the frame, or just after your swing). While the combat lines
-- are on, the gear's hit comes with its line, up to a second AHEAD of the swing's own hit (as a
-- seal's does): that one waits for the swing (WaitForSwing) instead (GitHub #25, 1.24.3: the
-- Eye's 2 still showed with "Hide hits below" at 5).
-- The magic schools each class's own spells hit with (unknown class: every school). Two hidden
-- hits of the gear's school together are only in doubt if one may be a spell of yours: a shaman
-- has no Shadow, so with the Eye on, a Stormstrike and its swing give two hidden Shadow hits that
-- are both the Eye's (GitHub #25, 1.27.1).
local CLASS_SCHOOLS = {
    WARRIOR = {}, ROGUE = { [8] = true }, HUNTER = { [4] = true, [8] = true, [64] = true },
    MAGE = { [4] = true, [16] = true, [64] = true }, PRIEST = { [2] = true, [32] = true },
    WARLOCK = { [4] = true, [32] = true }, DRUID = { [8] = true, [64] = true },
    SHAMAN = { [4] = true, [8] = true, [16] = true }, PALADIN = { [2] = true },
}
function BT:SpellsOfSchool(mask)
    local ok, _, class = false, nil, nil
    if UnitClass then ok, _, class = pcall(UnitClass, "player") end
    local schools = ok and Str(class) and CLASS_SCHOOLS[class]
    if not schools then return true end
    for bit, yes in pairs(schools) do
        if yes and mask % (bit * 2) >= bit then return true end
    end
    -- (Touch of the Grave, the Undead racial, drains with Shadow)
    if mask % 64 >= 32 and UnitRace then
        local okRace, _, race = pcall(UnitRace, "player")
        if okRace and Str(race) == "Scourge" then return true end
    end
    return false
end

function BT:EveryHitFor(h, seq, first, last, at)
    local item = self:EveryOn(h)
    if not item then return nil end
    local mask = Num(h.school)
    -- Gear that hurts you too (Thorncursed Grips): its hit on you in this moment is proof, one
    -- for each (GitHub #25, 1.28.3: Windfury's swings gave three hidden Nature hits together, and
    -- with Nature spells of a shaman's own they were in doubt)
    local g = self.gearSelf
    if item.melee and g and g.at == h.time and g.school == Num(h.school) and g.used < g.n then
        g.used = g.used + 1
        return item
    end
    local struck = h.key and self.struck and self.struck[h.key]
    local near = struck and h.time - struck >= 0 and h.time - struck <= PROC_TIME
    -- (or just after a spell's or ability's hit: gear that adds to every hit, not weapon blows only)
    local cast = not item.melee and h.key and self.spellStruck and self.spellStruck[h.key]
    -- (unless your own spells hit with its school: a warlock's unnamed Shadow hit after an Immolate
    -- may be a Shadow spell of theirs, and a big one must never be hidden as the gear's)
    if cast and h.time - cast >= 0 and h.time - cast <= PROC_TIME and not self:SpellsOfSchool(mask) then
        near = true
    end
    for j = first, last do
        local o = seq[j]
        if j ~= at and o.hit and not o.splash and o.kind == "damage"
                and ((h.key and o.key == h.key) or (not h.key and o.unit == h.unit)) then
            if Num(o.school) == mask and h.secret and o.secret then
                if self:SpellsOfSchool(mask) then
                    h.everyUnsure = true   -- (nor does it wait for a swing: WaitForSwing)
                    return nil
                end
            -- (gear that adds to melee weapon attacks only goes off beside a weapon blow; another
            -- of the gear's own hits isn't a hit for it to go with)
            elseif not item.melee or Num(o.school) == 1 then
                near = true
            end
        end
    end
    if not near then return nil end
    return item
end

-- Touch of the Grave, the Undead racial on Forever (1.60.x): your attacks and damaging spells
-- can drain the target, up to 5% of your health, and heal you for as much. It has no cast and
-- (with the lines hidden) no line, so its hit was shown unnamed and its heal as someone else's.
-- Its two halves land together: a hit of yours of a magic school that nothing else names, with
-- a heal on you within GRAVE_TIME either way, is it. One ID for warriors, paladins and rogues,
-- one for mages, priests and warlocks (their chance is higher).
local TOUCH_OF_THE_GRAVE = { 1260189, 1260201, name = "Touch of the Grave" }
local GRAVE_TIME = 0.3   -- seconds between its hit on the mob and its heal on you

-- The racial, if you have it: { id, name }
function BT:GraveSpell()
    for _, id in ipairs(TOUCH_OF_THE_GRAVE) do
        if self:KnowsSpell(id) then return { id = id, name = SpellName(id) or TOUCH_OF_THE_GRAVE.name } end
    end
    -- (an Undead character, if the game won't say it knows the passive)
    if UnitRace then
        local ok, _, race = pcall(UnitRace, "player")
        if ok and Str(race) == "Scourge" then
            local id = TOUCH_OF_THE_GRAVE[1]
            return { id = id, name = SpellName(id) or TOUCH_OF_THE_GRAVE.name }
        end
    end
    return nil
end

-- Whether this hit could be the racial's: damage of a magic school, and you have it
function BT:GraveOn(h)
    if h.kind ~= "damage" then return nil end
    local mask = Num(h.school)
    if not mask or mask == 1 then return nil end
    return self:GraveSpell()
end

-- The racial's hit, when its heal on you has already come (in this frame or just before)
function BT:GraveFor(h)
    local heal = self.graveHeal
    if not heal or heal.used or math.abs(h.time - heal.at) > GRAVE_TIME then return nil end
    local grave = self:GraveOn(h)
    if not grave then return nil end
    heal.used = true
    self.graveHit = { at = h.time, spell = grave }
    return grave
end

-- A hit that may be the racial's, with no heal on you yet: held up to GRAVE_TIME for it, then
-- shown as it is. Returns true if it's held.
function BT:WaitForGrave(h)
    if not self:GraveOn(h) then return false end
    self.graveWait = self.graveWait or {}
    local entry = { h = h }
    table.insert(self.graveWait, entry)
    local function over()
        for i, e in ipairs(BT.graveWait or {}) do
            if e == entry then
                table.remove(BT.graveWait, i)
                local why = BT:ShowUnitHit(h, "hit", nil)
                if not why then
                    BT:NoteUnnamed(h)
                    BT:NoteFought(h.key, h.time)
                end
                if BT.db.debug then
                    BT:Record(("  %s %s: %s"):format(h.unit, AmountText(h.amount), why or "no heal came for it: shown"), h.time)
                end
                return
            end
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(GRAVE_TIME, over) else over() end
    return true
end

-- A heal on you landed (UNIT_COMBAT player HEAL): it names a hit waiting for it (WaitForGrave),
-- or one still to be worked out in this frame (GraveFor). Not a heal you cast just then, nor a
-- tick of your heal over time.
function BT:GraveHealLanded(at, school)
    if self.healCast and math.abs(self.healCast.at - at) <= HEAL_CAST_TIME then return end
    if self.vigilHeal and math.abs(self.vigilHeal.at - at) <= VIGIL_TIME then return end
    if self:SelfHotFor(at, school) then return end
    local list = self.graveWait
    local e = list and list[1]
    if e and at - e.h.time <= GRAVE_TIME then
        table.remove(list, 1)
        local grave = self:GraveOn(e.h)
        if grave then
            self.graveHit = { at = at, spell = grave }
            local why = self:ShowUnitHit(e.h, "proc", grave)
            if not why then self:NoteFought(e.h.key, e.h.time) end
            if self.db.debug then
                self:Record(("  %s %s: %s"):format(e.h.unit, AmountText(e.h.amount), why or ("proc of " .. grave.name)),
                    e.h.time)
            end
            return
        end
    end
    self.graveHeal = { at = at }
end

-- The racial's heal on you: the heal that came with its hit
function BT:GraveHealFor(at)
    local hit = self.graveHit
    if hit and math.abs(hit.at - at) <= GRAVE_TIME then
        self.graveHit = nil
        return hit.spell
    end
    return nil
end

-- A throw named a hit in its own frame (it went off at once): it's done after this frame
function BT:ThrowLanded(name, at)
    for _, t in ipairs(self.thrown or {}) do
        if t.name == name and not t.landed then
            t.landed = at
            return
        end
    end
end

-- Throws that never hit anything
function BT:ForgetOldThrows()
    local list, now = self.thrown, GetTime()
    if not list then return end
    for i = #list, 1, -1 do
        if now - list[i].at > THROW_TIME or (list[i].landed and list[i].landed ~= now) then table.remove(list, i) end
    end
end

-- One frame's events, in the order they came: seq[first..last]
-- An attack on your next swing (Heroic Strike) comes as two physical hits on the mob: a part for
-- nothing first, then the attack. Mostly both are in the cast's frame (see emptyPart in
-- ResolveFrame), but the attack can come a frame later (Tyler's /btf debug: cast and the first
-- part at 832.59, the attack 0.15s later with its lines; it showed as a swing and the empty part as
-- "Heroic Strike 0"). So the cast's only hit on a mob waits PART_WAIT: a physical hit on the same
-- mob in that time is the attack, and the held one was the empty part. Nothing comes: it was the attack.
local PART_WAIT = 0.3
function BT:HoldFirstPart(h, spell, seq, first, last, i)
    if not (spell and self:NextSwing(spell.name)) or h.kind ~= "damage" or not h.key then return false end
    if Num(h.school) ~= 1 then return false end
    for j = first, last do
        local o = seq[j]
        if j ~= i and o.hit and o.key == h.key and o.kind == "damage" then return false end
    end
    local held = { h = h, spell = spell, key = h.key, at = h.time }
    self.partHeld = held
    local function over()
        if held.taken then return end
        if BT.partHeld == held then BT.partHeld = nil end
        local why = BT:ShowUnitHit(h, "cast", spell)
        if not why then
            h.mine = { what = "cast", spell = spell }
            BT:NoteFought(h.key, h.time)
            BT.struck = BT.struck or {}
            BT.struck[h.key] = h.time
            BT:SwingLanded(h.key, h.time)
            BT:OpenExtra(h)
        end
        if BT.db.debug then
            BT:Record(("  %s %s: %s"):format(h.unit, h.secret and "(hidden amount)" or AmountText(h.amount),
                why or ("cast of " .. tostring(spell.name) .. ", no second part")), h.time)
        end
    end
    if C_Timer and C_Timer.After then C_Timer.After(PART_WAIT, over) else over() end
    return true
end

-- The attack that follows a held first part (above): its spell, and the held part is dropped
function BT:SecondPart(h)
    local held = self.partHeld
    if not held or held.taken or not h.hit or h.splash or h.kind ~= "damage" or h.key ~= held.key then return nil end
    if Num(h.school) ~= 1 or h.time - held.at > PART_WAIT or h.time < held.at then return nil end
    held.taken, self.partHeld = true, nil
    if self.db.debug then
        self:Record(("  %s for nothing: the first part of %s, which lands now"):format(held.h.unit,
            tostring(held.spell.name)), h.time)
    end
    return held.spell
end

function BT:ResolveFrame(seq, first, last)
    local periodic = self:SpellLists()
    local cast, castAt, casts = nil, nil, 0
    for i = first, last do
        local c = seq[i]
        -- (a spell whose effect the server casts as a second spell of the same name, Holy Shock on
        -- Forever, sends two casts in one frame: that's one cast, the first)
        if c.cast and not (cast and c.name and cast.name == c.name) then cast, castAt, casts = c, i, casts + 1 end
    end
    if casts ~= 1 or not cast.id then cast = nil end   -- two casts in a frame: no telling which did what
    local castSchool   -- the school of the hits this frame's cast has been given
    local otherSchool  -- or of a hit turned away only because of the school learned for the cast
    local castStruck = {}   -- and the units they were on
    -- A spell that flies: its school is known, and a miss is its own only if a spell's
    local castFlight = cast and (self.flights[cast.name or ""] or self.thrownItems[cast.name or ""]
        or self:RangedSpell(cast.id))
    local function schoolOf(c)
        local f = self.flights[c.name or ""] or self.thrownItems[c.name or ""] or self:RangedSpell(c.id)
        return (f and f.school) or (self.spellSchool and self.spellSchool[c.id])
    end
    local function flightMiss(h)
        local mask, how = Num(h.school), h.action == "WOUND" and h.flag or h.action
        return FlightSchool(castFlight, mask) or SPELL_MISSES[how or ""] == true
    end
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
        local taken, school, struck = {}, nil, {}
        for i = first, last do
            local h = seq[i]
            if h.hit and not h.splash then
                local mask = Num(h.school)
                local can = not (castFlight and h.kind == "miss" and not flightMiss(h))
                if h.kind == "damage" then
                    local expect = school or schoolOf(cast)
                    can = not (info and not info.direct) and not (expect and mask and expect ~= mask)
                        and not (expect ~= mask and self:KnownShield(h))
                        and not (h.key and struck[h.key] and self:FlightFor(h))
                        and not (castFlight and self:OnUnnamedBeat(h))
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
                    if h.kind == "damage" then
                        school = school or mask
                        if h.key then struck[h.key] = true end
                    end
                elseif self:TickFor(h) then
                    for j = i + 1, last do   -- the tick's own line, which the loop below gives it
                        if seq[j].line and not taken[j] then taken[j] = true break end
                    end
                end
            end
        end
    end
    -- No line to go by and no hit after the cast: the cast's hit is the one just ahead of it (Tyler's
    -- log, 1.40.4: Ravage from Prowl, its one hit ahead of its CAST with no line, showed as a white
    -- hit with the swing icon). Of the spell's school (Physical when not known), not a tick.
    local castBefore
    if cast and castAt and not byLine then
        local after = false
        for i = castAt + 1, last do
            if seq[i].hit and not seq[i].splash then after = true break end
        end
        local info = periodic[cast.name or ""]
        if not after and not (info and not info.direct) and not castFlight then
            local expect = schoolOf(cast) or 1
            for i = castAt - 1, first, -1 do
                local h = seq[i]
                if h.hit and not h.splash and (h.kind == "damage" or h.kind == "miss") then
                    local mask = Num(h.school)
                    if (h.kind == "miss" or mask == nil or mask == expect) and not self:TickFor(h) then
                        castBefore = i
                    end
                    break
                end
            end
        end
    end
    -- An attack on your next swing (Maul, Heroic Strike...) replaces the swing, yet the game can
    -- send two physical hits on the mob with it: the attack, and a part for nothing whose amount
    -- it hides (and draws as "0"). On each mob, every such hit but the attack's is that part.
    local emptyPart = {}
    if cast and self:NextSwing(cast.name) then
        local onUnit = {}
        for i = first, last do
            local h = seq[i]
            local mask = Num(h.school)
            if h.hit and not h.splash and h.key and h.kind == "damage" and h.secret and (mask == nil or mask == 1) then
                onUnit[h.key] = onUnit[h.key] or {}
                table.insert(onUnit[h.key], i)
            end
        end
        for _, list in pairs(onUnit) do
            if #list > 1 then
                local keep = list[#list]   -- the attack: the one its line vouches for, else the last
                for _, i in ipairs(list) do if byLine and byLine[i] then keep = i end end
                for _, i in ipairs(list) do if i ~= keep then emptyPart[i] = true end end
            end
        end
    end
    -- A heal of yours ticking on a group member (a heal over time on its beat, a channel's heal)
    -- takes its line before the other hits in the frame do. Any hit in the frame can take a line,
    -- so a party member's hit landing with your tick took the tick's line (issue #29: a Renew tick
    -- showed as "no line of yours with it", the next one was named).
    for i = first, last do
        local h = seq[i]
        if h.hit and not h.splash and h.grouped and h.kind == "heal" and not (cast and castAt and i > castAt)
                and (self:TickFor(h) or self:AreaFor(h)) and self:ClaimHit(h.time, h) then
            h.lineFirst = true
        end
    end
    for i = first, last do
        local h = seq[i]
        if h.nothing and not blowInFrame then
            self:Emit(self:Area("InMisses"), MissText("MISS"), self.TEXT_COLORS.inAvoid)   -- a hit on you for nothing
        end
        -- Some attacks land in two parts, one of them for nothing (Maul: "WOUND 0" and
        -- "WOUND 37" on the mob in one frame). That's one blow, not a miss and a blow.
        local otherPart = false
        if h.hit and h.kind == "miss" and h.action == "WOUND" and not (h.flag and MISS_TEXT[h.flag]) and h.key then
            for j = first, last do
                local o = seq[j]
                if j ~= i and o.hit and o.kind == "damage" and o.key == h.key then otherPart = true break end
            end
        end
        if otherPart or emptyPart[i] then
            if self.db.debug then
                self:Record(("  %s for nothing: the other part of a blow that landed"):format(h.unit), h.time)
            end
        elseif h.hit and not h.splash then
            local mask = Num(h.school)
            local what, spell = "hit", nil
            -- Light's Vigil's heals on the party, set off by your Holy Shock in this frame or just before
            local vigil = self:VigilFor(h)
            local second = not vigil and self:SecondPart(h)
            if vigil then
                what, spell = "cast", vigil
            elseif second then
                what, spell = "cast", second
            -- Without a line to go by, the cast's hit comes after the cast (a hit ahead of it in
            -- the frame is something else)
            elseif cast and ((byLine and byLine[i]) or (not byLine and (i > castAt or i == castBefore))) then
                local info = periodic[cast.name or ""]
                if h.kind ~= "damage" then
                    if not (castFlight and h.kind == "miss" and not flightMiss(h)) then spell = cast end
                    -- The cast missed: nothing was put on the unit to tick
                    if spell and h.kind == "miss" and info and h.key and self.dots and self.dots[h.key] then
                        self.dots[h.key][cast.name] = nil
                    end
                elseif not (info and not info.direct) then
                    local expect = castSchool or schoolOf(cast)
                    -- Not a hit of another school than the spell's; and a hit that's just what a
                    -- damage shield of yours does is the shield's, unless the spell is of that school too.
                    -- A second hit on the same unit is a spell of yours that was on its way, when there is one.
                    -- A spell that flies doesn't take a hit on the beat of an unknown tick of yours
                    -- (issue #24: Demonic Brand ticking in a Shadow Bolt's cast frame took the bolt's name).
                    if not (expect and mask and expect ~= mask) and not (expect ~= mask and self:KnownShield(h))
                            and not (h.key and castStruck[h.key] and self:FlightFor(h))
                            and not (castFlight and self:OnUnnamedBeat(h)) then
                        spell, castSchool = cast, castSchool or mask
                        if h.key then castStruck[h.key] = true end
                    elseif not castSchool and not otherSchool and mask and not self:KnownShield(h)
                            and self.spellSchool and self.spellSchool[cast.id] == expect then
                        otherSchool = mask   -- turned away only by the school learned for it: maybe learned wrong
                    end
                end
                if spell then
                    what = "cast"
                    if castFlight and h.key then
                        self:TakeFlight(cast.name, h.key)
                        self:NoteFlightHit(cast.id, h)
                    end
                    if self.thrownItems[cast.name or ""] then self:ThrowLanded(cast.name, h.time) end
                    if h.kind == "heal" then self:FriendHealFor(h) end   -- (its heal has landed)
                end
            end
            -- Your heal on a friend landing a frame after its cast (Holy Shock)
            if not spell and h.kind == "heal" then
                local f = self:FriendHealFor(h)
                if f then what, spell = "cast", f end
            end
            -- In a group, a hit is yours only with a line of yours (see ClaimHit), a swing of yours
            -- (ClaimSwing), or as your cast's in its own frame (a miss of it has no line: "My actions"
            -- leaves misses out unless they're ticked)
            -- A heal on a group member is yours only if it's a heal you have going there (your cast,
            -- a heal over time of yours, Tranquility). Anyone's heals land on the group all the time:
            -- without this they took your lines' credits, showed as your heals, and left your own
            -- hits with none.
            local healOfYours = true
            if h.kind == "heal" and what ~= "cast" and h.grouped and not Flag(UnitIsUnit, h.unit, "pet") then
                healOfYours = self:TickFor(h) ~= nil or self:AreaFor(h) ~= nil or self:MendingFor(h, true) ~= nil
            end
            local claimed = not h.grouped or h.lineFirst == true
            if not claimed and what == "cast" then
                self:ClaimHit(h.time, h)   -- (its line, if it has one, is used up)
                claimed = true
            end
            -- A tick of yours the game sends no line for (Rip), right on its beat, before a swing can
            -- take it. Not when a line comes right behind the hit: that's a tick with its line. Nor
            -- with a line just ahead of it in the frame (a swing landing with its line first).
            if not spell and linesFlow and h.kind == "damage" then
                local lineBehind = false
                local accounted = LineAccounted(seq, first, last, i)   -- (a shield's line isn't the hit's)
                for j = first, last do
                    if j ~= i and seq[j].line and not seq[j].used and not accounted
                            and (j > i or seq[j].time == h.time) then
                        lineBehind = true
                        break
                    end
                end
                local silent = not lineBehind and self:SilentTick(h)
                if silent then
                    what, spell, claimed = "tick", silent, true
                    silent.silent = (silent.silent or 0) + 1
                    silent.tick = h.n or silent.tick
                    silent.last = h.time
                    -- (a tick on its beat with no line behind it: this game sends none for its ticks,
                    -- whatever lines were counted for it before)
                    if silent.lineUnsure and self.tickLines then self.tickLines[silent.name] = nil end
                end
            end
            local swung = false   -- (vouched for by a swing of yours: a white hit)
            if not claimed and healOfYours then
                swung = self:ClaimSwing(h)
                claimed = swung or self:ClaimHit(h.time, h) or self:ClaimFlight(h)
                    or self:ClaimExtra(h)
            end
            -- A spell of yours that was on its way to the unit. A tick of yours on its beat
            -- comes first, unless its amount isn't what that spell's ticks have been.
            if not spell and claimed then
                local f, at = self:FlightFor(h)
                local dot = f and self:TickFor(h, true)
                if dot and not (dot.tick and h.n and h.n ~= dot.tick) then f = nil end
                -- (a Holy hit with your swing is your seal's, not a Hammer of Wrath on its way)
                if f and self:SealFor(h, seq, first, last, i, true) then f = nil end
                -- (nor a tick of something unnamed, on its beat: issue #21)
                if f and self:OnUnnamedBeat(h) then f = nil end
                if f then
                    what, spell = "cast", f
                    self:Landed(f, at, h)
                    self:NoteFlightHit(f.id, h)
                end
            end
            -- Something you threw going off. As above, a tick of yours on its beat comes first.
            if not spell and claimed then
                local t = self:ThrownFor(h)
                local dot = t and self:TickFor(h, true)
                if dot and not (dot.tick and h.n and h.n ~= dot.tick) then t = nil end
                if t and self:OnUnnamedBeat(h) then t = nil end
                if t then
                    what, spell = "cast", t
                    t.landed = h.time
                end
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
                        -- (a tick the game sends no line for is named above, before the claims: SilentTick)
                    else
                        -- without the lines, a bleed's tick looks just like a swing; a heal can't be a swing
                        vouched = (mask ~= nil and mask ~= 1) or h.kind == "heal"
                    end
                    if vouched then
                        what, spell = "tick", dot
                        -- (only a line nothing else in the frame accounts for, behind a hit right on
                        -- the beat, says this game sends its ticks' lines)
                        if linesFlow and dot.lineUnsure and OnStrictBeat(h, dot)
                                and not LineAccounted(seq, first, last, i) then
                            -- (SilentTick: this game sends its ticks' lines)
                            self.tickLines = self.tickLines or {}
                            self.tickLines[dot.name] = (self.tickLines[dot.name] or 0) + 1
                        end
                        dot.tick = h.n or dot.tick   -- what its ticks hit for (see the spells on their way, above)
                        dot.last = h.time   -- its beat from now on (and it won't tick again on this one)
                    end
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
            if not spell and claimed then
                local area = self:AreaFor(h)
                if area then what, spell = "tick", area end
            end
            if not spell and claimed and h.kind == "heal" then
                local mending = self:MendingFor(h)
                if mending then what, spell = "proc", mending end
            end
            if not spell and claimed then
                local proc = self:ProcFor(h, seq, first, last, i)
                -- (Deadly Poison's hits are ticks: "DoT ticks" off hides them, and the tick window adds them up)
                if proc then what, spell = proc.dot and "tick" or "proc", proc end
            end
            if not spell and claimed then
                local each = self:EveryHitFor(h, seq, first, last, i)
                if each then what, spell = "proc", each end
            end
            if not spell and claimed then
                local grave = self:GraveFor(h)
                if grave then what, spell = "proc", grave end
            end
            local why
            -- (alone, your damage shield's hit stands on its own: "My actions" has no line for it.
            -- So does one that may be your shield's, still to be told by a blow on you: WaitForSwing.)
            if not claimed and h.solo and (what == "shield" or (not spell and self:ShieldOn(h))) then
                claimed = true
            end
            if not claimed and healOfYours and h.kind == "heal" and self:WaitForLine(h) then
                why = "waiting: its line may come late"
            elseif not claimed then
                why = healOfYours and "no line of yours with it" or "no heal of yours with it"
            elseif h.kind == "heal" and not spell and not h.grouped and not Flag(UnitIsUnit, h.unit, "pet") then
                -- A heal on someone else that isn't your cast or your heal-over-time: anyone's (a
                -- player regenerating, someone else's heal). In a group, a line of yours vouches for it.
                why = "no heal of yours with it"
            elseif not spell and self:WaitForSwing(h) then
                why = "waiting: your seal's, your shield's or your gear's?"
            elseif not spell and self:WaitForGrave(h) then
                why = "waiting: Touch of the Grave?"
                h.mine = { what = "hit" }   -- (a splash of its school beside it is still yours)
            elseif what == "cast" and not second and self:HoldFirstPart(h, spell, seq, first, last, i) then
                why = "waiting: the part for nothing, with the attack still to come?"
            else
                why = self:ShowUnitHit(h, what, spell)
                if not why and h.kind == "damage" then
                    h.mine = { what = what, spell = spell }
                    if not spell then self:NoteUnnamed(h) end
                    self:NoteFought(h.key, h.time)
                end
                -- A weapon blow of yours: its "Chance on hit" may follow (ProcFor), and your
                -- seal's hit may be waiting for it (WaitForSwing)
                if h.kind == "damage" and mask == 1 and h.key then
                    self.struck = self.struck or {}
                    self.struck[h.key] = h.time
                    self:SwingLanded(h.key, h.time)
                    if what == "hit" or (what == "cast" and spell) then self:OpenExtra(h) end
                elseif h.kind == "damage" and h.key and what ~= "proc" and what ~= "shield" and not self:EveryOn(h) then
                    -- A spell or ability of yours that isn't a weapon blow: the gear that adds to
                    -- every hit (Cursed Murloc Eye) goes off with it too, a moment before or after
                    self.spellStruck = self.spellStruck or {}
                    self.spellStruck[h.key] = h.time
                    self:Resolved(h.key, h.time, true)
                end
            end
            -- Your target dodged you (a warrior's Overpower)
            if claimed and h.kind == "miss" and (h.action == "DODGE" or (h.action == "WOUND" and h.flag == "DODGE")) then
                self:React("dodged")
            end
            if self.db.debug then
                self:Record(("  %s %s: %s"):format(h.unit, h.secret and "(hidden amount)" or AmountText(h.amount),
                    why or (spell and (what .. " of " .. tostring(spell.name)) or "shown")), h.time)
            end
        end
    end
    -- Damage on mobs that aren't after you: yours if a hit of yours of the same school
    -- landed in this frame on one that is. It's named as that hit was.
    for i = first, last do
        local h = seq[i]
        if h.hit and h.splash then
            local mask, mine = Num(h.school), nil
            for j = first, last do
                local o = seq[j]
                if o.mine and mask ~= nil and Num(o.school) == mask then mine = o.mine break end
            end
            local why
            -- (or a spell of yours hitting everything in its area)
            if not mine then
                local area = self:AreaFor(h, true)
                if area then mine = { what = "tick", spell = area } end
            end
            if not mine then
                why = "not your fight"
            elseif h.grouped and not self:ClaimHit(h.time, h) then
                why = "no line of yours with it"
            else
                why = self:ShowUnitHit(h, mine.what, mine.spell, true)
                if not why then self:NoteFought(h.key, h.time) end
            end
            if self.db.debug then
                self:Record(("  %s %s: %s"):format(h.unit, h.secret and "(hidden amount)" or AmountText(h.amount),
                    why or ("with your hit" .. (mine.spell and (" of " .. tostring(mine.spell.name)) or ""))), h.time)
            end
        end
    end
    -- What this frame's cast turned out to be: the school, if every hit it was given agrees
    if cast and (castSchool or otherSchool) then self:NoteSchool(cast.id, castSchool or otherSchool) end
end

-- A spell's school is learned once two frames in a row agree on it. One unlucky frame (a damage
-- shield's answer landing right behind the cast) used to set it for the session, and every real
-- hit of the spell after that went unnamed. A learned school is replaced the same way: by two
-- frames in a row with the spell's hits of another school.
function BT:NoteSchool(id, school)
    self.schoolSeen = self.schoolSeen or {}
    local seen = self.schoolSeen[id]
    if seen and seen.school == school then
        seen.n = seen.n + 1
    else
        seen = { school = school, n = 1 }
        self.schoolSeen[id] = seen
    end
    if seen.n >= 2 then
        self.spellSchool = self.spellSchool or {}
        self.spellSchool[id] = school
    end
end

-- Puts a hit on screen. what: "cast", "tick", "shield", "seal" or "hit"; spell: { id, name } when it's known;
-- area: one of the hits of an area spell. Returns why not, if a setting hides it.
function BT:ShowUnitHit(h, what, spell, area)
    local db, C = self.db, self.TEXT_COLORS
    local spellName = spell and spell.name
    local icon = ""
    if spell and spell.id then
        icon = self:IconText(spell.id)
    end
    if icon == "" and spell and spell.icon then
        icon = self:IconTag(spell.icon)   -- an item's (or, for a poison, the one its weapon buff shows)
    end
    if icon == "" and spell and spell.poison then icon = self:IconText(spell.name) end
    -- Nothing to name it by: a swing (a physical hit, or a plain miss)
    -- (a miss of a magic school isn't a swing either: a wand's bolt that missed or was resisted
    -- showed your melee weapon's icon, GitHub #40)
    local mask = Num(h.school)
    local swing = what == "hit" and not spell
        and ((h.kind == "miss" and (mask == nil or mask == 1)) or (h.kind == "damage" and mask == 1))
    local petSwing, notYourSwing
    if swing then
        local hand = self:SwingHand(h)
        local owner, notYours = self:SwingOwner(h, hand)
        notYourSwing = notYours
        if owner then
            petSwing, icon = owner, ""
            h.petSwing = true   -- (not an unknown tick of yours: NoteUnnamed)
        elseif notYours then
            icon = self:IconText(ATTACK_SPELL)
        else
            icon = self:SwingIcon(hand)
        end
    end
    if not petSwing and (swing or what == "cast") then
        self:NoteDeepWound(h, swing and not notYourSwing, what == "cast" and spell)
    end
    -- (an icon of your own for it, from the Spells tab: the fight summary shows it too)
    local own = spellName and self:RuleIcon(spellName)
    if own then icon = own end
    if h.kind == "damage" or h.kind == "heal" then
        self:CountFight(h.kind, h.n)
        self:CountSpell((petSwing or "")
            .. (spellName or (h.kind == "heal" and L["Unnamed heal"]) or UnnamedHit(Num(h.school))), h.n, h.crit,
            h.kind == "heal", icon)
    end
    if petSwing and not db.outPet then return "your pet's hits are turned off" end
    if ((swing and not petSwing) or (spell and spell.auto)) and not db.outSwings then
        return "auto attacks are turned off"
    end
    if what == "tick" and h.kind ~= "heal" and not db.outTicks then
        return "DoT and area spell ticks are turned off"
    end
    local rule = self:SpellRule(spellName)
    -- (named: one blow's two Nature hits are Thorns and Spiked Shell Band, and the log has to
    -- say which of the two was hidden)
    if rule and rule.hide then return "hidden on the Spells tab (" .. rule.name .. ")" end
    local name
    icon, name = self:SpellParts(h.kind == "heal" and "heal" or "out", icon, spellName)
    -- The text before the number and after it, in the order you set (Line order)
    local pre, post = self:LineParts(h.kind == "heal" and "healFormat" or "outFormat", icon, name, petSwing)
    if h.kind == "damage" then
        if what == "shield" and not db.outShields then return "damage shields are turned off" end
        if not db.outDamage then return "damage is turned off" end
        -- (a hidden amount the spell always does, like Cursed Murloc Eye's 2, is still known)
        local n = h.n or (spell and spell.fixed)
        if n and n < db.minDamage then return "below \"Hide hits below\"" end
        local mask = Num(h.school)
        local color = (rule and rule.color) or MASK_COLORS[mask or 1]
            or ((spellName or (mask and mask ~= 1)) and C.spell) or C.melee
        local note = FLAG_NOTES[h.flag or ""]
        note = note and (" |cffb0b0b0(" .. self:HitNote(note) .. ")|r") or ""
        if self:BigCrit(h.crit, h.n) and db.soundCrit then self:PlayAlert("crit") end
        local key = spell and (what .. ":" .. tostring(spell.id or spellName)) or nil
        local window = (what == "tick" or area) and db.tickMerge or nil
        if h.secret then
            -- Hidden amounts can't be added up, but hits of one spell together still share a line
            self:Emit(self:Area("OutDamage"), pre, color, { crit = h.crit, secret = h.amount, after = post .. note,
                key = key, window = window, unit = h.unit })
        else
            self:Emit(self:Area("OutDamage"), pre .. Commas(h.n) .. post .. note, color, {
                crit = h.crit,
                key = key,
                amount = h.n,
                window = window,
                unit = h.unit,
                format = function(total, count)
                    return pre .. Commas(total) .. post .. " |cffb0b0b0(x" .. count .. ")|r"
                end,
            })
        end
    elseif h.kind == "heal" then
        if not db.outHeals then return "heals are turned off" end
        local who = self:HealedName(h.unit)
        local healColor = rule and rule.color or C.heal
        if h.secret then
            self:Emit(self:HealArea("outgoing"), pre .. "+", healColor, { crit = h.crit, secret = h.amount, after = post .. who })
        else
            if not self:HealShown(h.n) then return "below \"Hide heals below\"" end
            self:Emit(self:HealArea("outgoing"), pre .. "+" .. Commas(h.n) .. post .. who, healColor, { crit = h.crit, amount = h.n })
        end
    else
        if not db.outMisses then return "misses are turned off" end
        -- A wound for nothing says how in its flag; a plain miss has none
        local how = h.action
        if how == "WOUND" then how = (h.flag and MISS_TEXT[h.flag]) and h.flag or "MISS" end
        self:Emit(self:Area("OutMisses"), pre .. MissText(how) .. post, C.miss, { unit = h.unit })
    end
    return nil
end

-- UNIT_COMBAT for a unit that isn't you
function BT:OnUnitHit(unit, action, flag, amount, school)
    -- You go by other names too (a mob's target, a raid member): "player" has
    -- its own event. Of what happens to your pet, only its heals are shown.
    if Flag(UnitIsUnit, unit, "player") then return end
    action, flag = Str(action), Str(flag)
    if action == "HEAL" and self.strangerHeal then self:StrangerHealHeard(unit) end
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
    -- The cheap answers first: most of a raid's events stop here, before any more questions to the game
    local why
    if not kind then
        why = "not a hit"
    elseif self:ReadLineHas(unit, now) then
        why = "the combat log line has it"
    end
    if why then
        if self.db.debug then self:RecordUnitHit(unit, action, flag, amount, secret, school, why) end
        return
    end
    local healing = kind == "heal"
    local enemy = Flag(UnitCanAttack, "player", unit)
    -- Once the combat log lines are arriving, they say which hits are yours: in a group, and
    -- alone too (a player outside your group hitting your target showed as your numbers). Alone,
    -- a unit your pet is on is the exception: "My actions" has no lines for the pet, and its hits
    -- can't be told from yours, so they show as before.
    local inGroup = self.hiddenSeen and self:InGroup()
    local grouped = self.hiddenSeen and (inGroup or not PetOn(unit))
    local solo = grouped and not inGroup
    -- A mob someone else tagged, and that isn't after you or your pet: its hits are theirs.
    -- Once the combat log lines are arriving, one of yours with a hit still makes it yours
    -- (helping someone out); without them, none are.
    local othersMob = enemy and not healing and Flag(UnitIsTapDenied, unit) and not TargetsYou(unit)
        and not (Flag(UnitExists, "pet") and TargetIs(unit, "pet"))
    if othersMob and self.hiddenSeen then grouped = true end

    local splash
    if healing and enemy then
        why = "a heal on an enemy"
    elseif not healing and not enemy then
        why = "not an enemy"
    elseif othersMob and not grouped then
        why = "someone else's mob"
    elseif healing and not grouped and not myPet and not Flag(UnitIsUnit, unit, "target") then
        why = "not your target"
    elseif healing and grouped and not myPet and not self:HealsLive(now) then
        -- In a group everyone's heals land on everyone: one is yours only if a heal of yours can be
        -- going (ResolveFrame's healOfYours), and none can without a helpful cast of yours lately
        why = "no heal of yours going"
    elseif not self:FirstSight(unit, now) then
        -- (before the questions below: the copies under other names cost nothing more)
        why = "same hit, under another name"
    elseif not healing then
        -- (Fighting asks the game up to six questions: asked once)
        local fighting = Fighting(unit)
        if fighting then
            -- yours to work out
        elseif self:FlightOn(unit, now, school) then
            -- a spell of yours on its way there
        elseif kind ~= "damage" then
            why = "not your fight"
        elseif not self:Finishing(unit, now) then
            -- Damage on a mob that isn't after you or your pet: yours only if it lands with a
            -- hit of yours on one that is, of the same school (an area spell hits them all at once)
            splash = true
        end
    end
    if self.db.debug then
        self:RecordUnitHit(unit, action, flag, amount, secret, school,
            why or (splash and "not your fight, unless a hit of yours lands with it" or nil))
    end
    if why then return end
    self:Queue({ hit = true, unit = unit, key = UnitKey(unit), kind = kind, action = action, flag = flag,
        amount = amount, secret = secret, n = n, school = school, crit = flag == "CRITICAL", grouped = grouped,
        solo = solo, splash = splash })
end

-- A readable line of yours names the unit it happened to (its link's GUID): only that unit's hits
-- are left to the line. Some lines can be read while others are hidden, so one readable line mustn't
-- drop every unit's hits. With no GUID to go by (on the line or the unit), any unit's are.
function BT:NoteReadLine(guid, now)
    guid = Str(guid)
    if not guid or guid == "" then
        self.readAt = now
        return
    end
    local on = self.readOn or {}
    self.readOn = on
    for g, at in pairs(on) do
        if now - at >= CREDIT_TIME then on[g] = nil end
    end
    on[guid] = now
    self.readAnyAt = now
end

function BT:ReadLineHas(unit, now)
    if self.readAt and now - self.readAt < CREDIT_TIME then return true end
    if not (self.readAnyAt and now - self.readAnyAt < CREDIT_TIME) then return false end
    local ok, guid = pcall(UnitGUID, unit)
    guid = ok and Str(guid) or nil
    if not guid then return true end
    local at = self.readOn[guid]
    return at ~= nil and now - at < CREDIT_TIME
end

function BT:RecordUnitHit(unit, action, flag, amount, secret, school, why)
    self:Record(("UNIT_COMBAT %s %s %s %s school %s%s"):format(unit, tostring(action), tostring(flag),
        secret and "(hidden amount)" or tostring(amount), IsSecret(school) and "(hidden)" or tostring(school),
        why and (": " .. why) or ""))
end

-- A heal of yours on a player outside your group (GitHub #29: mouseover Penance on a stranger in the
-- open world). The game sends UNIT_COMBAT only for units it has a name for: you, your target and
-- focus, your group, nameplates. A stranger under the mouse is none of those once the cast is
-- sent (UNIT_COMBAT never comes for "mouseover"), so with friendly nameplates off each tick gave
-- nothing but its combat log line, and nothing showed. The line is a |K string: it can be shown
-- but not read (COMBAT_LOG_MESSAGE: "A preformatted combat log message protected by a |K string
-- wrapper"). So when a heal that lands as it's cast (HealsOnCast) goes to such a player, the first
-- line of yours just after it is shown as it is ("Your Penance heals Bob for 312."), unless the
-- game's heal on them comes after all (a nameplate, or they're your target): then that shows, named,
-- as before. BattleText turns on friendly players' names (ApplyFriendPlates) so that's the usual case.
local STRANGER_LINE_TIME = 0.5   -- a heal's line comes this soon after its cast (Penance's ticks: 0.12 to 0.24s)
local STRANGER_WAIT = 0.3        -- the game's heal on them, if any, comes by this long after the line (same frame, in the log)
function BT:NoteStrangerHeal(id, name)
    local d, now = self.dest, GetTime()
    local s = d and d.at == now and d.sent
    if not (s and s.help and not s.me and s.unit == "mouseover" and s.guid and self:HealsOnCast(name)) then return end
    self.strangerHeal = { at = now, guid = s.guid, id = id, name = name }
end

-- The game's own heal on a unit: if it's the player that heal went to, it shows from it
function BT:StrangerHealHeard(unit)
    local w = self.strangerHeal
    if not w or w.heard or GetTime() - w.at > STRANGER_LINE_TIME + STRANGER_WAIT then return end
    local ok, guid = pcall(UnitGUID, unit)
    guid = ok and Str(guid) or nil
    if guid and guid == w.guid then w.heard = true end
end

function BT:StrangerLine(message, now)
    local w = self.strangerHeal
    if not w or w.line or now < w.at or now - w.at > STRANGER_LINE_TIME then return end
    if IsSecret(message) or type(message) ~= "string" then return end
    w.line = message
    local function show()
        if w.heard then
            if self.db.debug then self:Record("STRANGER heal " .. tostring(w.name) .. ": the game's heal came, shown from it") end
            return
        end
        if self.db.debug then self:Record("STRANGER heal " .. tostring(w.name) .. ": no heal event for them, the line shown") end
        self:ShowStrangerLine(w)
    end
    if C_Timer and C_Timer.After then C_Timer.After(STRANGER_WAIT, show) else show() end
end

function BT:ShowStrangerLine(w)
    local db = self.db
    if not db.outHeals then return end
    local icon = (db.healIcons and w.id) and self:IconText(w.id) or ""
    local rule = self:SpellRule(w.name)
    if rule and rule.hide then return end
    self:Emit(self:HealArea("outgoing"), icon .. w.line, (rule and rule.color) or self.TEXT_COLORS.heal)
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
        self:StrangerLine(message, GetTime())
        return
    end
    local info = Parser:Parse(message)
    -- A line of yours that can be read is shown from the line; the same hit from
    -- UNIT_COMBAT is then left out
    if info and (info.fromMe or self:IsPetLine(info)) then self:NoteReadLine(info.destGUID, GetTime()) end
    local shown = info ~= nil and self:ShowCombat(info)
    if self.db.debug then self:Record((shown and "read    " or "skipped ") .. message) end
end

-- Debug (/btf debug, then /btf copy): what the game sent, exactly, with the time
-- it arrived. Kept only while debug is on, and only the last RECORD_MOST: enough for a whole play
-- session, so /btf report can sum it up (until 1.41.0 it kept 300, about one fight).
-- A hidden value in the text would make the whole line secret, and /btf copy couldn't
-- show it, so such a line is kept as a note instead.
local RECORD_MOST = 5000
function BT:Record(text, time)
    self.recorded = self.recorded or {}
    local list = self.recorded
    text = Str(text) or "(a line with a hidden value)"
    list[#list + 1] = ("%7.2f  %s"):format((Num(time) or GetTime()) % 1000, text)
    -- (trimmed 500 at a time: one at a time would move 5000 lines for each new one)
    if #list > RECORD_MOST + 500 then
        local kept = {}
        for i = #list - RECORD_MOST + 1, #list do kept[#kept + 1] = list[i] end
        self.recorded = kept
    end
end

-- Shared with the files loaded after this one
S.POISON_SPELLS, S.TOUCH_OF_THE_GRAVE, S.ManaNow = POISON_SPELLS, TOUCH_OF_THE_GRAVE, ManaNow
